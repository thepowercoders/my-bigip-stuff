# f5-bigip

This repo contains various F5 scripts and tools which I have developed in supporting build and configuration of the big-ip NVA. I only build in Microsoft Azure so these
 scripts may be usable for appliances or other clouds, but bear in mind that I am not writing or supporting them for anything other than Azure.
 
## Scripts

### upload_package

This script is used to install a iControl LX package (DO, AS3, TS ..etc). It was written as the [bigip-runtime-init](https://github.com/F5Networks/f5-bigip-runtime-init) was 
failing for me when I was trying to install Telemetry Streaming due to a timeout (ref: [github issue 51](https://github.com/F5Networks/f5-bigip-runtime-init/issues/51)).

The script will install the package and check that install has been successful by polling the iApps LX package control endpoint: `/mgmt/shared/iapp/package-management-tasks`
