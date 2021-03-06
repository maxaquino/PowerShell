# -------------------------------------------------------------------------------------------------------------
##
##
##      Description: Provision Server
##
## DISCLAIMER
## The sample scripts are not supported under any HPE standard support program or service.
## The sample scripts are provided AS IS without warranty of any kind. 
## HP further disclaims all implied warranties including, without limitation, any implied 
## warranties of merchantability or of fitness for a particular purpose. 
##
##    
## Scenario
##     	
##	
## Description
##      
##		
##
## Input parameters:
##         iloIP                              = IP address of the ILO Server
##		   iloUSer                            = iLO user name on iLO
##         iloPassword                        = iLO  password
##         isoURL                             = URL where ISO is 
##
##         OVApplianceIP                      = IP address of the OV appliance
##		   OVAdminName                        = Administrator name of the appliance
##         OVAdminPassword                    = Administrator's password
##         OneViewModule                      = OneView library module
##         OVAuthDomain                       = Doamin to authenticate against
##         Server                             = Server hardware in OneView to connect to
#          ServerProfileTemplate              = Server profile Template to be assigned to server if the server has no profile assigned yet
##
##
## History: 
##         March 2018         - Adapted for Gen10
##
##   Version : 3.2 - March 2018
##
##   Version : 3.1 - October 2017 - First release
##
## Revision by: massimiliano.aquino@hpe.com
## Contact : Dung.HoangKhac@hpe.com
##
##
## -------------------------------------------------------------------------------------------------------------
<#
  .SYNOPSIS
    Provision Server thru OneView/iLO
  
  .DESCRIPTION
	 Provision Server thru OneView/iLO
        
  .EXAMPLE



    .\Provision-Server.ps1 -iloIP 10.234.1.21 -iLOUser admin -iLOPassword password -isoURL "http://10.239.16.2/ISO/ubuntu-16.04.3-server-amd64.iso" 
        The script connects to the iLO and provisions server with URL provided in isoURL


    .\Provision-Server.ps1 -OVApplianceIP 10.254.1.66 -OVAdminName Administrator -password P@ssword1 -Server "Encl1, Bay3" -ServerProfileTemplate "DL-Template" -isoURL "http://10.239.16.2/ISO/ubuntu-16.04.3-server-amd64.iso"
        The script connects to OneView, selects the server specified in parameter and and provisions server with URL provided in isoURL


  .PARAMETER iloIP                               
    IP address of the ILO Server

  .PARAMETER iloUSer                            
    iLO user name on iLO

  .PARAMETER iloPassword                       
   iLO  password

  .PARAMETER isoURL                                              
    URL where ISO is OVApplianceIP  

  .PARAMETER OVApplianceIP                   
    IP address of the OV appliance

  .PARAMETER OVAdminName                     
    Administrator name of the appliance

  .PARAMETER OVAdminPassword                 
    Administrator s password
  
  .PARAMETER OneViewModule
    Module name for POSH OneView library.
	
  .PARAMETER OVAuthDomain
    Authentication Domain to login in OneView.

  .PARAMETER Server
    Server name that is managed by OneView.   

  .PARAMETER ServerProfileTemplate
    Server profile Template to be assigned to server if the server has no profile assigned yet

  .Notes
    NAME:  Porvision-Server
    LASTEDIT: 27/03/2018
    KEYWORDS: OV  Export
   
  .Link
     Http://www.hpe.com
 
 #Requires PS -Version 5.0
 #>
  
## -------------------------------------------------------------------------------------------------------------

Param ( 
    
    [string]$iLOIP          = "10.239.7.0",
    [string]$iLOUser        = "",
    [string]$iLOpassword    = "",
    [string]$isoURL         = "http://10.239.16.2/ISO/ubuntu-16.04.3-server-amd64.iso",
    
    [string]$OVApplianceIP          = "10.239.121.121", 
    [string]$OVAdminName            = "administrator", 
    [string]$OVAdminPassword        = "",
    [string]$OVAuthDomain           = "local",

    [string]$Server                 = "",
    [string]$ServerProfileTemplate  = "",


    [string]$OneViewModule          = "HPOneView.310"
    )
    
    
    
    $RedfishRoot      = "/redfish/v1"
    $RedfishAccount   = "/redfish/v1/AccountService"
    $RedfishChassis   = "/redfish/v1/Chassis"
    $RedfishEvent     = "/redfish/v1/EventService"
    $RedfishManagers  = "/redfish/v1/Managers"
    $RedfishSession   = "/redfish/v1/SessionService"
    $RedfishSystems   = "/redfish/v1/Systems"
    
    
    Function Set-Power ( [string]$ActionValue, $iLOsession)
    {
        #Available Actions:
        #On,ForceOff,ForceRestart,Nmi,PushPowerButton
    
    
        $Systems = Get-HPERedfishDataRaw -Odataid $RedfishSystems -Session $iLOsession
		
		foreach ($sys in $Systems.Members.'@odata.id') # /redfish/v1/systems/1 or /redfish/v1/systems/2
        {
    
            #Get System Data
			$sysData   = Get-HPERedfishDataRaw -Odataid $sys -Session $iLOsession
			
            # creating setting object to invoke reset action.  
            # Details of invoking reset (or other possible actions) is present in 'AvailableActions' of system data   
            $dataToPost = @{} 
            $dataToPost.Add('ResetType', $ActionValue) 
    
            switch ($ActionValue)
            {
                'ForceOff'     
                            {
                                if ($sysData.PowerState -eq 'On') 
                                {    $dataToPost
                                    # Sending reset request to system using 'POST' in Invoke-HPERedfishAction 
										$ret = Invoke-HPERedfishAction -Odataid $sysData.Actions.'#ComputerSystem.Reset'.target -Data $dataToPost -Session $iLOsession
                                }
                            }
                'On'
                            {
                                if ($sysData.PowerState -eq 'Off') 
                                {    
                                    $dataToPost
                                    # Sending reset request to system using 'POST' in Invoke-HPERedfishAction
										$ret = Invoke-HPERedfishAction -Odataid $sysData.Actions.'#ComputerSystem.Reset'.target -Data $dataToPost -Session $iLOsession
                                }
                            }
            }
    
    
        }
    }
    
    
    Function Set-OneTimeBoot ( [string]$BootTarget, $iLOsession)
    {
        #Possible values for $BootTarget are:
        #None , Cd , Hdd , Usb  , Utilities ,Diags , BiosSetup , Pxe , UefiShell
    
    
        $Systems = Get-HPERedfishDataRaw -Odataid $RedfishSystems -Session $iLOsession
    
		foreach ($sys in $Systems.Members.'@odata.id') # /redfish/v1/systems/1 or /redfish/v1/systems/2
        {
            #Get System Data
            $sysData   = Get-HPERedfishDataRaw -Odataid $sys -Session $iLOsession 

            $bootData  = $sysData.boot

			if(-not($bootData.'BootSourceOverrideTarget@Redfish.AllowableValues' -Contains $BootTarget))
            {
                # if user provided not supported then print error
                Write-Host "$BootTarget not supported"
            }
            else
            {
                # create object to PATCH
                $tempBoot = @{'BootSourceOverrideTarget'=$BootTarget}
                $OneTimeBoot = @{'Boot'=$tempBoot}
    
                # PATCH the data using Set-HPERedfishData cmdlet
                $ret = Set-HPERedfishData -Odataid $sys -Setting $OneTimeBoot -Session $iLOsession
                
                #process message returned by Set-HPERedfishData cmdlet
                if($ret.Messages.Count -gt 0)
                {
                    foreach($msgID in $ret.Messages)
                    {
                        $status = Get-HPERedfishMessage -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $iLOSession
                        $status
                    }
                }
    
                #get and print updated value
                $sysData   = Get-HPERedfishDataRaw -Odataid $sys -Session $iLOSession 
                $bootData  = $sysData.boot  
            }
        }
    }
	
	
    Function Set-VirtualMedia ([string]$ISOurl, $iLOSession)
    {
        $managers = Get-HPERedfishDataRaw -Odataid $RedfishManagers -Session $ILOsession
		
        foreach($mgr in $managers.Members.'@odata.id')
        {
    
            $mgrData = Get-HPERedfishDataRaw -Odataid $mgr -Session $ILOsession
			
            # Check if virtual media is supported
			if( -not ($mgrData.VirtualMedia.'@odata.id') )
            {
                # If virtual media is not present in links under manager details, print error
                Write-Host 'Virtual media not available in Manager links'
            }
            else
            {
                ###$vmhref = $mgrData.links.VirtualMedia.href
				$vmhref = $mgrData.VirtualMedia.'@odata.id'
                $vmdata = Get-HPERedfishDataRaw -Odataid $vmhref -Session $ILOsession
				
				foreach($vm in $vmdata.Members.'@odata.id')
                {
    
                    $data = Get-HPERedfishDataRaw -Odataid $vm -Session $ILOsession
					
                    # select the media option which contains DVD
                    if($data.MediaTypes -contains 'DVD')
                    {
                        # Create object to PATCH to update ISO image URI and to set
    
                        # Eject Media if there is already one
                        if ($data.Image)
                        {
                            # Dismount DVD if there is already one
                            $mountSetting = @{'Image'=$null}
                            $ret = Set-HPERedfishData -Odataid $vm -Setting $mountSetting -Session $ILOsession 
                        }
    
                        # Attach DVD file to media
                        $mountSetting = @{'Image'=[System.Convert]::ToString($IsoUrl)}
    
                        if($BootOnNextReset -ne $null -and $IsoUrl -ne $null)
                        {
                            # Create object to PATCH 
                            $oem = @{'Hpe'=@{'BootOnNextServerReset'=[System.Convert]::ToBoolean($BootOnNextReset)}}
    
                            $mountSetting.Add('Oem',$oem)
                        }
    
                        # PATCH the data to $vm href by using Set-HPERedfishData
                        $ret = Set-HPERedfishData -Odataid $vm -Setting $mountSetting -Session $ILOsession 
                        
    
                        # Process message(s) returned from Set-HPERedfishData
    
                            if($ret.Messages.Count -gt 0)
                            {
                                foreach($msgID in $ret.Messages)
                                {
                                    $status = Get-HPERedfishMessage -MessageID $msgID.MessageID -MessageArg $msgID.MessageArgs -Session $ILOsession
                                    $status
                                }
                            }
    
                            Get-HPERedfishDataRaw -Odataid $vm -Session $ILOsession
                        
                    }
                }        
            }
        }
    }
    
    
	Disable-HPERedfishCertificateAuthentication
    if ($iLOIP -and $iLOUser -and $iLOPassword)
    {
        Try 
        {
            $iLOSession    = Connect-HPERedfish -address $iLOIP -username $iLOuser -password $iLOpassword -ErrorAction stop #-DisableCertificateAuthentication 
        
        }
        catch 
        {
            write-host -foreground Yellow " Cannot connect to ILO with $iLOIP / user: $iLOuser / password: $iLOpassword. "
        }
    }
    else 
    {
    
        # -------------------------------Use OneView 
        $LoadedModule = get-module -listavailable $OneviewModule
    
    
        if ($LoadedModule -ne $NULL)
        {
                $LoadedModule = $LoadedModule.Name.Split('.')[0] + "*"
                remove-module $LoadedModule
        }
    
        import-module $OneViewModule
    
    
        # ---------------- Connect to OneView appliance
    
        write-host -foreground Cyan "$CR Connect to the OneView appliance..."
        try 
        {
            $ThisConnection =  Connect-HPOVMgmt -hostname $OVApplianceIP -user $OVAdminName -password $OVAdminPassword  -AuthLoginDomain $OVAuthDomain    
        }
        catch 
        {
            write-host -foreground Yellow " Cannot connect to OneView $OVApplianceIP ...."
        }
    
        # ----------------Get Server 
        if ($Server)
        {
            try 
            {
                $ThisServer     = Get-HPOVServer -name $Server -ErrorAction stop
            }
            catch 
            {
                write-host -foreground YELLOW "Server $Server does not exist. Exiting now...."
                $iLOSession = $ThisServer = $NULL
            }

            
            if ($ThisServer)
            {
                if ($ThisServer.ServerProfileURI)
                {
                    $iLOSession = $ThisServer | Get-HPOVIloSso -IloRestSession 
                }
                else # Server has no profile
                {
                    if ($ServerProfileTemplate)
                    {
                        $ThisTemplate = Get-HPOVServerProfileTemplate -Name $ServerProfileTemplate
                        try 
                        {
                            write-host -foreground CYAN "Create profile for $Server using template $ServerProfileTemplate.... " 
                            if ($ThisServer.powerState -eq 'On')
                                { $ThisServer | Stop-HPOVServer -Force -Confirm:$False | Wait-HPOVTaskComplete }

                            New-HPOVServerProfile -Name "Profile of $Server" -ServerProfileTemplate $ThisTemplate -Server $ThisServer  -AssignmentType Server -ErrorAction stop | Wait-HPOVTaskComplete
                            $iLOSession = $ThisServer | Get-HPOVIloSso -IloRestSession 
                        }
                        catch
                        {
                            write-host -foreground YELLOW "Cannot create server profile for server $Server with profile template $ServerPRofileTemplate. Exiting now...."
                            $iLOSession = $NULL
                        }

                        

                    }
                    else 
                    {
                        write-host -foreground Yellow "Server hardware --> $Server has no profile and Server Profile Template is not specified. Exiting now... "
                        $iLOSession = $NULL
                    }
                }
            }
            else 
            {
                write-host -foreground Yellow "Server hardware --> $Server does not exist in OneView. Exiting now... "
                
            }
        }
        else 
        {
            write-host -foreground Yellow "No server specified. Specify server name and re-run the script "
        }
    }
    
    if ($iLOSession)
    {
        write-host -foreground  CYAN " iLO - Force Shutdown server  ......"
        Set-Power  -ActionValue ForceOff  -ILOsession $iLOSession
    
        write-host -foreground  CYAN " iLO - Configure OneTime Boot to be CD/DVD ......"
        Set-OneTimeBoot -BootTarget Cd -ILOsession $iLOSession
    
        write-host -foreground  CYAN " iLO - Configure URL to point to $isoURL ......"
        Set-VirtualMedia -isoURL $isoURL -ILOsession $iLOSession
    
        write-host -foreground  CYAN " iLO - Power On server ......"
        Set-Power -ActionValue On  -ILOsession $iLOSession
		
		Disconnect-HPERedfish -Session $iLOSession

    }
    if ($ConnectedSessions)
    {
        Disconnect-HPOVMgmt
    }    

