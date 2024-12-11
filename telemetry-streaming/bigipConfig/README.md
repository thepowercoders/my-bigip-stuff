# BIG-IP Configuration Information Workbook

## Introduction
BIG-IP in Azure uses [Telemetry Streaming](https://clouddocs.f5.com/products/extensions/f5-telemetry-streaming/latest/) to declaratively aggregate, normalize, and forward statistics and events from the BIG-IP to a consumer application. BIG-IP Telemetry Streaming is an iControl LX Extension delivered as a TMOS-independent RPM file. The RPM is available [here](https://github.com/F5Networks/f5-telemetry-streaming/tree/master).

You can do all of this by POSTing a single TS JSON declaration to BIG-IP Telemetry Streaming’s declarative REST API endpoint. The BIG-IP Telemetry Streaming System Poller collects System configuration and statistics it receives on the specified internal port from the BIG-IP System and forwards to Azure Log Analytics. This includes data on Virtual Servers, Pools, Pool Members, Profiles and Policies.

The specific object needed in the TS json declaration is a `Telemetry_System_Poller`:
```
"telemetry-systemPollerAzure": {
   "class": "Telemetry_System_Poller",
   "interval": 60,
   "actions": [
      {
         "setTag": {
            "tenant": "`T`",
            "application": "`A`"
         },
         "enable": true
      },
   ]
}
```
> :warning: **Important:** The workbook relies on the presence of the columns `f5tenant_s` and `application_s` which are populated using the setTag option in the System Poller above. If you omit this from your TS declaration, the workbook will not work properly.

## Workbook
This workbook displays configuration information for BIG-IP LTM Virtual Servers, Pools and Pool Members. Information is displayed in a similar format to replicate the functionality of the BIG-IP GUI Interface and provides a method of viewing configuration, across multiple devices reporting into Azure via Telemetry Streaming, without having to access the device(s).

It support BIG-IP configuration which exists in multiple partitions ('tenants' in AS3 speak) and I believe it should work with any standard BIG-IP VE deployment in Azure, but may need some tweaking which you are free to do.

## Log Analytics Logs
This workbook is dependant on the availability of the following logs:
* F5Telemetry_virtualServers_CL
* F5Telemetry_pools_CL
* F5Telemetry_poolMembers_CL

The workbook can be uploaded to provide troubleshooting engineers an easier way to view BIG-IP configuration through the Azure Portal. It has the following features:

* Can select subscriptions and multiple workspaces so if you have BIG-IP devices in different subscriptions, the report can correlate all this data into one.
* Always shows the latest status and statistics of the virtual servers and pools.
   * The workbook assumes that System logging is being sent at least every 60 seconds from the BIG-IP devices into Azure.
* Provides a global view of configuration for:
   * Virtual Servers
   * Pools
   * Pool Members - including the status for members in pools which have a Monitor
* As an improvement to the BIG-IP Web GUI, the workbook also gives a summary of statistics on the same page - including the ability to click on the VS or Pool to get details stats on a side-panel.


