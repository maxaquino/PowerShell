# Server-Provision.ps1
The Server-Provision.ps1 script is a PowerShell script used to deploy OS to physical server thru iLO virtual Media and OneView.
The original script available here https://github.com/DungKHoang/Provision-Server-thru-iLO-OneView has been modified to allow provisioning Gen10 server.

# Pre-requisites
The script requires the following HPE Libraries:
* HPE iLORedfish cmdlets
* HPE OneView PowerShell library 

## Intalling the HPE libraries
    * HPE iLORedfish cmdlets 
```
    Install-Module HPRedfishCmdlets
```    
    * HPE OneView PowerShell library
```
    Install-Module HPOneView.310
``` 

### Scenarios and Syntax

Two(2) scenarios:
* Connecting to a server through ILO directly
```

    .\ Provision-Server.ps1 -iloIP 10.234.1.21 -iLOUser admin -iLOPassword password -isoURL "http://10.239.16.2/ISO/ubuntu-16.04.3-server-amd64.iso" 
        The script connects to the iLO and provisions server with URL provided in isoURL

        The script connects to OneView, selects the server specified in parameter and and provisions server with URL provided in isoURL


```

* Connecting through OneView
```

        .\ Provision-Server.ps1 -OVApplianceIP 10.254.1.66 -OVAdminName Administrator -password P@ssword1 -Server "Encl1, Bay3" -ServerProfileTemplate "DL-Template" -isoURL "http://10.239.16.2/ISO/ubuntu-16.04.3-server-amd64.iso"

        The script connects to OneView, selects the server specified in parameter and enables iLO IPMI on this server
        ** If server has no profile, the script will apply a profile template to this server
        ** The script then establishes a SSO to the iLO of the server
        ** It then deploys the OS thru virtual media

```
