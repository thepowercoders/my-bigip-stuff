# f5-bigip

This repo contains various F5 scripts and workbooks which I have developed in supporting build and configuration of the F5 BIG-IP NVA. I only build in Microsoft Azure so these scripts may be usable for appliances or other clouds, but bear in mind that I am not writing or supporting them for anything other than Azure. The repo contains the following:
 
## azure-build
This folder contains scripts which have been developed to support the build of a BIG-IP Virtual Edition (VE) Virtual Machines in Azure. 

## ltm
This folder contains scripts used in the Local Traffic Manager (LTM). The scripts are detailed below:

### EAV Monitor


## scripts
This folder contains various scripts used to support various activities on the BIG-IP. The scripts are detailed below:

### upload_package
This script is used to install a iControl LX package (DO, AS3, TS ..etc). It was written as the [bigip-runtime-init](https://github.com/F5Networks/f5-bigip-runtime-init) was failing for me when I was trying to install Telemetry Streaming due to a timeout (ref: [github issue 51](https://github.com/F5Networks/f5-bigip-runtime-init/issues/51)).

The script will install the package and check that install has been successful by polling the iApps LX package control endpoint: `/mgmt/shared/iapp/package-management-tasks`

## telemetry-streaming
This folder contains Azure Log Analytics workbooks which have been developed to visual telemetry data sent to Azure by the [Telemetry Streaming](https://clouddocs.f5.com/products/extensions/f5-telemetry-streaming/latest/) service.

The following workbooks have been developed:

* [BIG-IP AFM Workbook](/telemetry-streaming/afm/README.md) - Visualizations and Data Tables for the Advanced Firewall Manager (AFM).
* [BIG-IP Configuration Workbook](/telemetry-streaming/bigipConfig/README.md) - Creates similar looking data tables to the BIG-IP GUI in Azure.
* [BIG-IP Dashboard Workbook](/telemetry-streaming/dashboard/README.md) - Visualizations and Data Tables showing availability and performance of various GTM (DNS) and LTM components.
* [BIG-IP Syslog Workbook](/telemetry-streaming/syslog/README.md) - A workbook to display syslog data being sent by the BIG-IP.

To install a workbook, type 'workbooks' in the Azure Portal search bar and select 'Azure Workbooks':

![Azure Portal Search](/images/workbook_search.png)

Select 'Create' and then select to create an Empty workbook
![New Workbook](/images/workbook_new.png)

Click the Advanced Editor button : ![Advanced Editor Button](/images/workbook_editor.png)

* Make sure *Template Type* is set to 'Gallery Template'.
* In the edit box, remove the initial configuration.
* Copy-Paste the required workbook from this repo into the edit box.
* Click on the *Apply* button.