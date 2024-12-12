# BIG-IP Dashboard Workbook

## Introduction
BIG-IP in Azure uses [Telemetry Streaming](https://clouddocs.f5.com/products/extensions/f5-telemetry-streaming/latest/) to declaratively aggregate, normalize, and forward statistics and events from the BIG-IP to a consumer application. BIG-IP Telemetry Streaming is an iControl LX Extension delivered as a TMOS-independent RPM file. The RPM is available [here](https://github.com/F5Networks/f5-telemetry-streaming/tree/master).

You can do all of this by POSTing a single TS JSON declaration to BIG-IP Telemetry Streaming’s declarative REST API endpoint. The BIG-IP Telemetry Streaming System Poller collects System configuration and statistics it receives on the specified internal port from the BIG-IP System and forwards to Azure Log Analytics. This includes data on GSLB Wide IPs, GSLB Pools, LTM Virtual Servers and Pools, and SSL Certificates.

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
This workbook displays a summary of Performance and Availability of DNS (GTM) and LTM objects relating to Wide-IPs and LTM Virtual Servers and Pools.

It support BIG-IP configuration which exists in multiple partitions ('tenants' in AS3 speak) and I believe it should work with any standard BIG-IP VE deployment in Azure, but may need some tweaking, which you are free to do. There are some nuances with the way the data is pulled for some queries - I explain this below. It is also supposed to be a demonstration of the kind of data you can pull and visualise from a number of different log sources - again, feel free to add anything else you want.

Finally, the workbook also scans all the subscriptions which the current user has access to looking for F5 BIG-IP Devices. When found, it will try and obtain data from the device on the status of Telemetry Streaming. This is useful to determine if any systems have stopped sending log information in. It assumes that system logging is set as per above example on the *Telemetry_System_Poller* to an interval of 60 seconds minimum.

### Log Analytics Logs
This workbook is dependant on the availability of the following logs:

To report on Telemetry Status:
* F5Telemetry_telemetryServiceInfo_CL

For DNS/GTM Reporting:
* F5Telemetry_deviceGroups_CL
* F5Telemetry_aWideIps_CL and F5Telemetry_aaaaWideIps_CL
* F5Telemetry_aPoolMembers_CL and F5Telemetry_aaaaPoolMembers_CL
* F5Telemetry_virtualServers_CL

For LTM Reporting:
* F5Telemetry_LTM_CL
* F5Telemetry_poolMembers_CL

For TLS Certificate Reporting:
* F5Telemetry_sslCerts_CL

## Workbook Features

### Telemetry Streaming Status
The top of the report shows the status of all devices in the environment and their telemetry status:
![Dashboard Telemetry Status](/images/dash_tsStatus.png)

The list of devices is derived by a lookup in [Azure Resource Graph](https://learn.microsoft.com/en-us/azure/virtual-machines/resource-graph-samples?) for all virtual machines which have an image publisher of 'f5-networks'. The query is ran on a parameter (allBIGIPSystems) which is then used to create a datatable in the Status visualization:

``` kusto
Resources
| where type == 'microsoft.compute/virtualmachines'
| where properties.storageProfile.imageReference.publisher == 'f5-networks'
| project name
```

This is then compared with the names of systems which are streaming data into the selected workspace. The status is determined by reading the information in the `F5Telemetry_telemetryServiceInfo_CL` log. A device with a good status is shown as either 'Polling' or 'Processing'. If this log does not contain a system found via Resource Graph, it is shown with an error status ('No Logs').


### Global Traffic Management (GTM)

#### DNS Sync
For GTM information, the workbook assumes that [GSLB ConfigSync](https://my.f5.com/manage/s/article/K45907236) is active on the BIG-IP devices in operation (and all devices therefore have identical information). The workbook allocates a reference BIG-IP to pull DNS data from, which it stores in the parameter: *ReportingDNSSystem*.

The parameter query looks at device sync information held in the `F5Telemetry_deviceGroups_CL` log and for all machines running in the *gtmd* DNS synchronization group. 

It then assigns a priority based on the instance number of the VM. This assumes 2 things:
1. You are naming VMs in accordance with the [Azure CAF naming convention](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) with an 'instance number' as the last element of the hypenated name.
2. That the primary DNS server in the DNS Synchronization Group is VM instance `-001` (and assigned priority 1).

``` kusto
F5Telemetry_deviceGroups_CL
| where TimeGenerated > ago (2m)
| where name_s == "/Common/gtm"
| extend hostname_s = tostring(split(_ResourceId, '/')[-1])
| extend priority_d = toint(split(hostname_s, '-')[-1])
| distinct hostname_s, priority_d
| top 1 by priority_d asc
| project hostname_s
```
If the primary DNS server fails, the workbook will automatically select an alternative device in the sync group. If in your environment, this auto-selection does not work, you can always edit the workbook and manually set the *ReportingDNSSystem* parameter.

#### Global Availability
This section of the workbook shows all Wide IPs which are defined in the reference DNS system. The information can be filtered per domain (the FQDN suffix is extracted from all configured WIPs on the system). The tile app name can be clicked to display a side-bar with more Wide IP information and statistics. The tile shows the currently active status of the WIP.

When you click on a tile, the GSLB Pool information is displayed. This shows the following:
* All the pools allocated to the WIP (The Pool LB mode is shown above).
* The status of the pool members
   * The Pool name can be clicked to open a side-bar with more Pool information and statistics.
* The Virtual Server reference of the pool member
   * The Virtual Server can be clicked to open a side-bar with more VS information and statistics.

![GSLB Global Availability](/images/dash_gtm.png)

Pool Availability is also then shown on a time graph with a selectable time period.

### Local Traffic Management

LTM Data assumes HTTP/API Data as this is what this workbook was originally designed to show. However, if you have other types of data, you should be able to amend the workbook to visualise your own services.

![LTM Request Logging](/images/dash_httpProfile.png)

LTM Data relies on [Request/Response Logging](https://techdocs.f5.com/kb/en-us/products/big-ip_ltm/manuals/product/bigip-external-monitoring-implementations-12-0-0/3.html) to have been enabled on the BIG-IP system. It uses information which relies on specific fields in the Request Logging Profile. To get the report working correctly, please add *at least* the following to the templates:

**Request Logging Template:**
```
event_source="request_logging",hostname="$BIGIP_HOSTNAME",client_ip="$CLIENT_IP",server_ip="$SERVER_IP",dest_ip="$VIRTUAL_IP",dest_port="$VIRTUAL_PORT",http_method="$HTTP_METHOD",http_uri="$HTTP_URI",virtual_name="$VIRTUAL_NAME",event_timestamp="$DATE_HTTP",Microtimestamp="$TIME_USECS"
```

**Response Logging Template:**
```
event_source="response_logging",hostname="$BIGIP_HOSTNAME",client_ip="$CLIENT_IP",server_ip="$SERVER_IP",http_method="$HTTP_METHOD",http_uri="$HTTP_URI",virtual_name="$VIRTUAL_NAME",event_timestamp="$DATE_HTTP",http_statcode="$HTTP_STATCODE",http_status="$HTTP_STATUS",Microtimestamp="$TIME_USECS",response_ms="$RESPONSE_MSECS"
```

The request log time chart plots all API requests (effectively, all URIs which are recorded in the $HTTP_URI field above). The chart can be brushed to zoom in on particular data. When brushed, the proceeding pie-charts showing Message Volumes and HTTP Response Codes, and the log table are adjusted to the brushed time period only.

![API Request Time Chart](/images/dash_apiReqs.png)

The Request/Response Log table combines both the request and response into a single log and shows the server response time (SRT) for the request. To ensure it correctly links the 2 logs, it uses the *Microtimestamp* field which holds the request-time fraction in microseconds. As this is a millionth of a second, it is highly unlikely you would get 2 requests at the same time which would confuse the *join* function being used in the log query.


### LTM Other Data
A key part of a successfully operating BIG-IP system is that the API endpoints which are being accessed via LTM Pools are in service, and that correct HTTPS operation is working with no expired certificates. 

The final section of the workbook allows you to select a LTM pool and view a time chart of availability for the selected time period.

Also, all the SSL certificates which are held on the devices being monitored are shown with the number of days before expiry. This will allow you to see when certificates need to be renewed.

![SSL Certificate Status](/images/dash_sslCerts.png)