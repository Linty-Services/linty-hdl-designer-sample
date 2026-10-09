---------------------------------------------------------------------
-- TITLE: AXI4-Lite slave
-- FILENAME: axi.vhd
-- DESCRIPTION:
--    Single-outstanding AXI4-Lite slave for a word-oriented register bank.
--    Write address and write data are accepted in either order, or together.
--    Each channel keeps VALID stable until its READY handshake, and the
--    response beat holds BRESP/RDATA stable while BVALID/RVALID is high.
--    Addresses must be aligned to the data width. Any other address, or a
--    PROT value that is not a legal 3-bit encoding, gets SLVERR and does
--    not change the register bank.
---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi is
  generic (
    addr_width : positive := 8;
    data_width : positive := 32
  );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;

    -- Write address channel
    awaddr  : in  std_logic_vector(addr_width - 1 downto 0);
    awprot  : in  std_logic_vector(2 downto 0);
    awvalid : in  std_logic;
    awready : out std_logic;

    -- Write data channel
    wdata   : in  std_logic_vector(data_width - 1 downto 0);
    wstrb   : in  std_logic_vector((data_width / 8) - 1 downto 0);
    wvalid  : in  std_logic;
    wready  : out std_logic;

    -- Write response channel
    bresp   : out std_logic_vector(1 downto 0);
    bvalid  : out std_logic;
    bready  : in  std_logic;

    -- Read address channel
    araddr  : in  std_logic_vector(addr_width - 1 downto 0);
    arprot  : in  std_logic_vector(2 downto 0);
    arvalid : in  std_logic;
    arready : out std_logic;

    -- Read data channel
    rdata   : out std_logic_vector(data_width - 1 downto 0);
    rresp   : out std_logic_vector(1 downto 0);
    rvalid  : out std_logic;
    rready  : in  std_logic
  );
end entity axi;

architecture rtl of axi is
  constant resp_okay   : std_logic_vector(1 downto 0) := "00";
  constant resp_slverr : std_logic_vector(1 downto 0) := "10";
  constant strb_width  : positive := data_width / 8;

  -- Number of low address bits that select a byte inside one data word.
  function byte_addr_bits return natural is
    variable bits : natural := 0;
    variable span : natural := 1;
  begin
    while span < strb_width loop
      span := span * 2;
      bits := bits + 1;
    end loop;
    assert span = strb_width
      report "axi: data_width must be 8, 16, 32, or 64"
      severity failure;
    assert addr_width >= bits
      report "axi: addr_width is smaller than the byte offset of data_width"
      severity failure;
    return bits;
  end function byte_addr_bits;

  constant addr_lsb   : natural := byte_addr_bits;
  constant word_bits  : natural := addr_width - addr_lsb;
  constant word_count : positive := 2 ** word_bits;

  type mem_t is array (0 to word_count - 1) of std_logic_vector(data_width - 1 downto 0);

  type wr_state_t is (wr_idle, wr_wait_data, wr_wait_addr, wr_resp);
  type rd_state_t is (rd_idle, rd_data);

  signal mem       : mem_t := (others => (others => '0'));
  signal wr_state  : wr_state_t := wr_idle;
  signal rd_state  : rd_state_t := rd_idle;
  signal awaddr_q  : std_logic_vector(addr_width - 1 downto 0) := (others => '0');
  signal awprot_q  : std_logic_vector(2 downto 0) := (others => '0');
  signal wdata_q   : std_logic_vector(data_width - 1 downto 0) := (others => '0');
  signal wstrb_q   : std_logic_vector(strb_width - 1 downto 0) := (others => '0');

  function legal_prot(prot : std_logic_vector(2 downto 0)) return boolean is
  begin
    case prot is
      when "000" | "001" | "010" | "011" | "100" | "101" | "110" | "111" =>
        return true;
      when others =>
        return false;
    end case;
  end function legal_prot;

  function is_aligned(addr : std_logic_vector(addr_width - 1 downto 0)) return boolean is
  begin
    for bit_index in addr'reverse_range loop
      exit when bit_index >= addr_lsb;
      if addr(bit_index) /= '0' then
        return false;
      end if;
    end loop;
    return true;
  end function is_aligned;

  function word_index(addr : std_logic_vector(addr_width - 1 downto 0)) return natural is
    variable index : natural := 0;
    variable place : natural := 1;
  begin
    for bit_index in addr'reverse_range loop
      if bit_index >= addr_lsb then
        if addr(bit_index) = '1' then
          index := index + place;
        end if;
        place := place * 2;
      end if;
    end loop;
    return index;
  end function word_index;

  -- Apply WSTRB to one stored word. Unaligned and illegal PROT beats are refused.
  procedure commit_write(
    signal storage : inout mem_t;
    addr           : in std_logic_vector(addr_width - 1 downto 0);
    prot           : in std_logic_vector(2 downto 0);
    data           : in std_logic_vector(data_width - 1 downto 0);
    strb           : in std_logic_vector(strb_width - 1 downto 0);
    signal resp    : out std_logic_vector(1 downto 0)
  ) is
    variable word : std_logic_vector(data_width - 1 downto 0);
  begin
    if not is_aligned(addr) or not legal_prot(prot) then
      resp <= resp_slverr;
      return;
    end if;

    word := storage(word_index(addr));
    for byte_index in 0 to strb_width - 1 loop
      if strb(byte_index) = '1' then
        for bit_index in 0 to 7 loop
          word(byte_index * 8 + bit_index) := data(byte_index * 8 + bit_index);
        end loop;
      end if;
    end loop;
    storage(word_index(addr)) <= word;
    resp <= resp_okay;
  end procedure commit_write;

begin
  assert data_width = 8 or data_width = 16 or data_width = 32 or data_width = 64
    report "axi: data_width must be 8, 16, 32, or 64"
    severity failure;
  assert addr_width >= addr_lsb
    report "axi: addr_width is smaller than the byte offset of data_width"
    severity failure;

  -- Write channels. AWREADY and WREADY depend only on this FSM, so the slave
  -- never waits for one write channel before acknowledging the other.
  write_channels : process (aclk, aresetn)
  begin
    if aresetn = '0' then
      wr_state <= wr_idle;
      awaddr_q <= (others => '0');
      awprot_q <= (others => '0');
      wdata_q  <= (others => '0');
      wstrb_q  <= (others => '0');
      awready  <= '0';
      wready   <= '0';
      bvalid   <= '0';
      bresp    <= resp_okay;
      mem      <= (others => (others => '0'));
    elsif rising_edge(aclk) then
      case wr_state is
        when wr_idle =>
          awready <= '1';
          wready  <= '1';
          bvalid  <= '0';
          if awvalid = '1' and wvalid = '1' then
            commit_write(mem, awaddr, awprot, wdata, wstrb, bresp);
            awready  <= '0';
            wready   <= '0';
            bvalid   <= '1';
            wr_state <= wr_resp;
          elsif awvalid = '1' then
            awaddr_q <= awaddr;
            awprot_q <= awprot;
            awready  <= '0';
            wr_state <= wr_wait_data;
          elsif wvalid = '1' then
            wdata_q  <= wdata;
            wstrb_q  <= wstrb;
            wready   <= '0';
            wr_state <= wr_wait_addr;
          end if;

        when wr_wait_data =>
          awready <= '0';
          wready  <= '1';
          if wvalid = '1' then
            commit_write(mem, awaddr_q, awprot_q, wdata, wstrb, bresp);
            wready   <= '0';
            bvalid   <= '1';
            wr_state <= wr_resp;
          end if;

        when wr_wait_addr =>
          wready  <= '0';
          awready <= '1';
          if awvalid = '1' then
            commit_write(mem, awaddr, awprot, wdata_q, wstrb_q, bresp);
            awready  <= '0';
            bvalid   <= '1';
            wr_state <= wr_resp;
          end if;

        when wr_resp =>
          awready <= '0';
          wready  <= '0';
          bvalid  <= '1';
          if bready = '1' then
            bvalid   <= '0';
            awready  <= '1';
            wready   <= '1';
            wr_state <= wr_idle;
          end if;
      end case;
    end if;
  end process write_channels;

  -- Read channels. One address beat is accepted, then RVALID stays high
  -- until the master takes the data beat.
  read_channels : process (aclk, aresetn)
  begin
    if aresetn = '0' then
      rd_state <= rd_idle;
      arready  <= '0';
      rvalid   <= '0';
      rresp    <= resp_okay;
      rdata    <= (others => '0');
    elsif rising_edge(aclk) then
      case rd_state is
        when rd_idle =>
          arready <= '1';
          rvalid  <= '0';
          if arvalid = '1' then
            arready <= '0';
            rvalid  <= '1';
            if is_aligned(araddr) and legal_prot(arprot) then
              rdata <= mem(word_index(araddr));
              rresp <= resp_okay;
            else
              rdata <= (others => '0');
              rresp <= resp_slverr;
            end if;
            rd_state <= rd_data;
          end if;

        when rd_data =>
          arready <= '0';
          rvalid  <= '1';
          if rready = '1' then
            rvalid   <= '0';
            arready  <= '1';
            rd_state <= rd_idle;
          end if;
      end case;
    end if;
  end process read_channels;

end architecture rtl;
