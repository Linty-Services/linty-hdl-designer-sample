# Linty HDL Designer Project Sample

This project is a nice sample to test [Linty HDL Designer](https://hdl-designer.linty-services.com).

It comes with proper Linty configuration.
See [Scan Your Code documentation](https://doc.linty-services.com/doc/scan.html)
and related [read.ys](./.linty/yosys/read.ys), [hierarchy.ys](./.linty/yosys/hierarchy.ys)
and [linty.properties](./.linty/linty.properties)
files.

The following steps will help you set up this project in [Linty HDL Designer](https://hdl-designer.linty-services.com).

## Install Linty HDL Designer

Install extensions from [Linty HDL Designer Extension Pack](https://hdl-designer-pack.linty-services.com) to VS Code.

## Start Fixing Issues

1. Clone [this project](https://github.com/Linty-Services/linty-hdl-designer-sample)
2. Open it in VS Code.
3. Without any configuration, you should already be able to see issues from Linty, browse nicely colorized code, etc.
   For instance, open [cache.vhd](./src/cache.vhd) file.

## Connect Your VS Code Project to Your Linty Platform

To give the fully-featured version of Linty HDL Designer a try, please, [contact us](mailto:contact@linty-services.com)
to get a trial license.

1. [Deploy your Linty platform](https://doc.linty-services.com/doc/install.html)
2. [Provision your project](https://doc.linty-services.com/doc/scan.html) with key
   from [linty.properties](./.linty/linty.properties)
3. [Connect your local project in VS Code to your Linty platform](https://hdl-designer.linty-services.com/#connected-mode-paid-version).

## Run Full Analysis and Browse CDCs, RDCs, FSMs details, etc.

1. From your Linty platform, on your project, go to **Project Settings > HDL** and set the **Top-Level Module/Entity**
   property to `plasma_3e`.
2. [Active and configure rules to check](https://doc.linty-services.com/doc/rules_to_check.html) for VHDL and HDL
   languages. You can start with **Deep Code Checks** profiles.
3. [Run a Linty scan](https://doc.linty-services.com/doc/scan.html#run-linty-scan)
4. You can now [browse CDCs, RDCs, FSMs details, etc.](https://hdl-designer.linty-services.com/#report-paid-version)

## Toggle Between Overall Code and New Code Focus

1. Update [linty.properties](./.linty/linty.properties) by setting `sonar.projectVersion` property to `2`.
2. [Run a Linty scan](https://doc.linty-services.com/doc/scan.html)
3. You can
   now [toggle between Overall code and New code focus](https://hdl-designer.linty-services.com/#focus-on-new-code-paid-version)
   to hide existing issues and focus on your own code quality. 
