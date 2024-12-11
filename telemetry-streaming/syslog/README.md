# BIG-IP Capturing Syslog in Azure

## Introduction
BIG-IP in Azure uses [Telemetry Streaming](https://clouddocs.f5.com/products/extensions/f5-telemetry-streaming/latest/) to declaratively aggregate, normalize, and forward statistics and events from the BIG-IP 
to a consumer application. BIG-IP Telemetry Streaming is an iControl LX Extension delivered as a TMOS-independent RPM file. The RPM is available [here](https://github.com/F5Networks/f5-telemetry-streaming/tree/master).

You can do all of this by POSTing a single TS JSON declaration to BIG-IP Telemetry Streaming’s declarative REST API endpoint. The BIG-IP Telemetry Streaming Event Listener collects event logs it receives on the specified
port from configured BIG-IP sources, including LTM, ASM, AFM, APM, and AVR. This provides a good amount of telemetry events but does not pick up on some system level errors which may only show up in the system
logs (mainly `/var/log/ltm`). A good example is the pkcs11d daemon which handles errors from external HSMs. Errors are logged in `/var/log/ltm` but not standard Telemetry logs.

To allow Azure to see these errors and potentially alert on them, we use the 'Remote Logging' feature on the BIG-IP to send syslog to the local loopback IP, on a port which the TS service is listening on.
Due to the very high amount of syslog logging, I only include logs of severity warning and above; otherwise, Log Analytics gets rather flooded with unimportant information.

We redirect to the localhost on port 6514 as it will then be picked up by the `Telemetry-System` listener and pushed out to Azure Log Analytics:
```
"My_Listener": {
   "class": "Telemetry_Listener",
   "port": 6514
}
```
> :memo: **Reference:** https://clouddocs.f5.com/products/extensions/f5-telemetry-streaming/latest/event-listener.html

## BIG-IP Configuration

1. Log into the tmsh of your BIG-IP device and enter the command:
`(tmos)# edit /sys syslog all-properties`
1. this opens up the settings in the vi editor.
1. In the edited section remove the line `include none` and replace it with the below code:
```
include "
filter f_remote_loghost {
level(warning..emerg);
};

destination d_remote_loghost {
udp(\"127.0.0.1\" port(6514));
};

log {
source(s_syslog_pipe);
filter(f_remote_loghost);
destination(d_remote_loghost);
};
"
```
1. then write-quit vi (type ':wq')
1. you should get the prompt: `Save changes? (y/n/e)` - select 'y'
1. finally save the config: `(tmos)# save /sys config`

## Log Analytics Logs
Once it has been enabled, you should shortly see a new table created in Azure in your log analytics workspace for syslog:
![syslog_customlog](/images/syslog_customlog.png)

This just dumps the raw data of the log into a column, if you want to get something a little more readable, you can use the following kusto query:
``` kusto
F5Telemetry_syslog_CL 
| where TimeGenerated > ago(5m)
| extend processName = extract(@'([\w-]+)\[\d+\]:', 1, data_s)
| extend message_s = extract(@'\[\d+\]: (.*)', 1, data_s)
| project
   TimeGenerated,
   message_s,
   processName,
   hostname_s,
   Type,
   telemetryEventCategory_s,
   _ResourceId
```

## Workbook
The workbook provided here can be uploaded to provide a easier way to view and report on syslog events. It shows events based on the process or daemon which raised them, by severity,
and contains a searchable table of syslog messages over the selected time period, and by device.

### Logged Daemons
There are a number of system processes and daemons which run as part of the bigip and provide logging to various logs in syslog. A list of these is available from [this link](https://my.f5.com/manage/s/article/K67197865).

**Example Showing Time Graph of syslog Messages (with time brush slicer)**
![syslog_timegraph](/images/syslog_timegraph.png)

The time graph over the selected period can be brushed using your cursor to select a time interval within the main interval, if you spot an interesting period within the time graph and only wish to see what logs were created at this period. In the top right there is a small icon: <img src="/images/syslog_graph_reset_icon.png" width="30" /> which allows you to reset the time range selection.

The workbook creates tiles for each daemon process and these can be clicked on to filter the log table to that specific type of log. For most purposes, the `/var/log/ltm` log provides the main notification of traffic or operational events which are generated from the `tmm` daemon. If your bigip is running DNS (GTM) then the gtmd process also provide GSLB notifications.  

**Example showing Count of syslog Messages per Process/Daemon**
![image](https://github.com/thepowercoders/f5-bigip/assets/32461620/6078c057-33b4-47d2-8c06-49fe1eb783cc)

![syslog_count_per_msg](/images/syslog_count_per_msg.png)

>📝 **Note:** tmm is a multi-threaded process which has multiple instances matching the cpus on the bigip VE. The process name in the log will show the instance number (e.g. tmm2, tmm5 ...etc) but in the 'Count of syslog Messages per Process/Daemon' tiles (above), all these logs are wrapped up and counted under the 'tmm' tile.

You can also click on the discovered severity types to further filter the log table. Finally, the log table itself has a search function and also allows export of data to Excel.
