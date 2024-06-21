# BIG-IP EAV Monitors for Microsoft Azure

**Applies to:** :heavy_check_mark: F5 BIG-IP VE VMs :heavy_check_mark: Microsoft Azure :heavy_check_mark: LTM EAV Health Probes

## Introduction
Within BIG-IP health monitoring, there is a large number of 'built-in' monitors which allow you to perform various health checks to endpoints to ascertain their
availability and then mark LTM pool members up, down or disabled accordingly.
For newer applications (especially cloud), these monitors are still usable (eg. the https monitor) but may not have the extensibility required to properly health
probe newer services - particularly PaaS services. This is where we can use 'Extended Application Verification' (EAV) or external monitors. External monitors
let you create custom scripts to monitor the health of pool members and nodes. 

An external monitor contains the following three components:
* A BIG-IP monitor that references a script using the `External` setting.
* A script that contains logic to determine the health of a service.
* A response from the script to mark the monitor UP or DOWN.

Reference: https://my.f5.com/manage/s/article/K71282813

# EAV Scripts

## monitor_azure_paas
This script is used to test availability of Azure PaaS resources. 

Currently, I've only added 3 PaaS resources which covered my use-case I had:

* Managed SQL Server
* COSMOS Database
* Blob Storage

However, the guts of the script doesn't change for monitoring any other PaaS service as the `Microsoft.Health` endpoint is published in (what looks to be) the same location in all of their PaaS services. Therefore, to add another you would just need to modify the code and add another condition to the case statement at [lines 48-69](https://github.com/thepowercoders/f5-bigip/blob/448d8c92fb09ad976c064e64cec2f26b30271ec9/eav_monitors/monitor_azure_paas#L48).

### Azure health monitoring
PaaS resources can be monitored using the `availabilityStatuses/current` API endpoint within the `Microsoft.ResourceHealth` provider. More information on how resource health is determined is provided [here](https://learn.microsoft.com/en-us/azure/service-health/resource-health-overview).

A resource is a specific *instance* of an Azure service, such as a specific SQL Database or Blob. Resource Health relies on signals from different Azure services to assess whether a resource is healthy. The availabilityStatuses endpoint provides a response which is one of the following:

* Available - the resource is healthy and working.
* Degraded - this means there is an issue, but the resource is not necessarily unhealthy. I've decided to mark this status as still 'up' on the F5 health probe, but you can change this if you want - change [result=0](https://github.com/thepowercoders/f5-bigip/blob/448d8c92fb09ad976c064e64cec2f26b30271ec9/eav_monitors/monitor_azure_paas#L140) to result=1.
* Unavailable - the resource is not working - this triggers a 'down' event on the health probe.
* Unknown - the resource is in an unknown state - this triggers a 'down' event on the health probe.

### Pre-requisites
To operate this script requires the following:
* The big-ip Virtual Machine requires a User Assigned Managed Service Identity (MSI).
* The big-ip requires network access to the IMDS API at 169.254.169.254. The API is only accessible via the primary NIC (management port) of the big-ip.
* For all Azure PaaS resources you wish to monitor health for, the big-ip's MSI requires *read* access to the resource.
  
### Script processing
The script performs 2 functions. Firstly, it leverages the Virtual Machine [Instance Metadata Service](https://learn.microsoft.com/en-us/azure/virtual-machines/instance-metadata-service) (IMDS) to pull a security token for the management.azure.com API.  

![image](https://github.com/thepowercoders/f5-bigip/assets/32461620/d7da0327-9a40-4c7c-a35b-cdd5d433caea)

It then queries the resource health endpoint to get the current availability status. Based on the response, the EAV script will mark the monitor as up or down.

### Configuration
* To configure the probe, add the script to: **System  ››  File Management : External Monitor Program File List** 
* Then configure a new monitor of type 'External' and select the 'External Program' as matching the name given above.
* In the 'Variables' section, add the following:
  
| Name | Value |
|------|-------|
| `VM_MSI_OID` | the object ID of the Virtual Machine's **USER ASSIGNED** Managed Service Identity.
| `SUBSCRIPTION` | the subscription ID which the Azure PaaS service is provisioned within.
| `RESOURCE_GROUP` | the resource group name which the Azure PaaS service is provisioned within.
| `PROVIDER` | one of the script's supported PaaS provider resources, which is either `storage`, `cosmos` or `sqlserver`.
| `RESOURCE_NAME` | the actual name of the resource you want to check.
| (optional) `SUBRESOURCE_NAME` | for some resources (e.g. SQL), a sub-resource may need to be checked within the PaaS service.
| (optional) `DEBUG` | this is used to add debug information to `/var/log/ltm` log. Set to 0 (off) or 1 (on). If omitted, debug is set off.

You can then add the monitor to a LTM pool for anything which relies on the availability of the PaaS service to function.
