## -------------------------------------------------------------------------------------------------------------
##
##
##      Description: OneView-iLO functions
##
## DISCLAIMER
## The sample scripts are not supported under any HPE standard support program or service.
## The sample scripts are provided AS IS without warranty of any kind. 
## HP further disclaims all implied warranties including, without limitation, any implied 
## warranties of merchantability or of fitness for a particular purpose. 
##
##    
## Scenario
##     	Use SSO to configure iLO from OneView
##		
##
## Input parameters:
##         OVApplianceIP                      = IP address of the OV appliance
##		   OVAdminName                        = Administrator name of the appliance
##         OVAdminPassword                    = Administrator's password
##         iLOUserCSV                         = path to the CSV file containing user accounts definition
##
## History: 
##
##		  March-2018	  : v1.1 - modifiche per supporto Gen10
##        December-2017   : v1.0 - modificati parametri di default (connection, file csv e modulo OV)
##        February-2016   : v1.0
##
## Version : 1.1
##
##
##
## Examples:
##
## Example 1)
## - gen9sy4.0.csv
## ServerName,Username,Password,Privileges
## "CN754604F4, bay 1",hptest,password,All
## 
## - Per Gen9 da OneView400
## .\ilo-adduser.ps1 -OVApplianceIP 192.168.0.100 -OVAdminName Administrator -OVAdminPassword password -iLOAccountCSV .\gen9sy4.0.csv
## 
## Example 2)
## - gen10.csv
## ServerName,Username,Password,Privileges
## "ILOCZ273001F0",hptest3,password,All
## 
## - Per Gen10 da OneView310 (-OVApplianceIP 192.168.0.100 -OVAdminName Administrator -OVAdminPassword password)
## .\ilo-adduser.ps1
## 
## -------------------------------------------------------------------------------------------------------------

Param ( [string]$OVApplianceIP="192.168.0.100", 
        [string]$OVAdminName="Administrator", 
        [string]$OVAdminPassword='password',
        [string]$OneViewModule = "HPOneView.400",  

        [string]$iLOAccountCSV = "gen10.csv"

)



## -------------------------------------------------------------------------------------------------------------
##
##                     Function Create-iLOAccount
##
## -------------------------------------------------------------------------------------------------------------

Function Create-iLOAccount {

<#
  .SYNOPSIS
    Create iLO accounts from OneView
  
  .DESCRIPTION
	Create iLO accounts from OneView
      
  .EXAMPLE
    Create-iLOAccount.ps1  -iLOaccountCSV .\iLOaccount.CSV 



  .PARAMETER iLOAccountCSV
    Name of the CSV file containing iLO account definition
	

  .Notes
    NAME:  Create-iLOAccount
    LASTEDIT: 03/01/2018
    KEYWORDS: iLO accounts
   
  .Link
     Http://www.hpe.com
 
 #Requires PS -Version 3.1
 #>
Param ([string]$iLOAccountCSV ="")

    if ( -not (Test-path $iLOAccountCSV))
    {
        write-host "No file specified or file $iLOAccountCSV does not exist. Skip creating iLO account"        return    }    # Read the CSV Users file    $tempFile = [IO.Path]::GetTempFileName()    type $iLOAccountCSV | where { ($_ -notlike ",,,,,*") -and ( $_ -notlike "#*") -and ($_ -notlike ",,,#*") } > $tempfile   # Skip blank line    $ListofAccts    = import-csv $tempfile
 
      foreach ($A in $ListofAccts)    {		$Brand         = "Hp"
		$isGen10       = $false
        $userName      = $A.userName        $ServerName    = $A.ServerName        if (($userName -eq "") -or ($ServerName -eq ""))        {            write-host -ForegroundColor Yellow "No username specified or No Server HArdware specified. Skip creating accounts..."                    }        else        {            ## ---- Get Server Hardware
			## For Gen10, the data model has changed. Hp is no more valid. Use Hpe instead
            $ThisServer = Get-HPOVServer -name $ServerName
			if ( $ThisServer.model -match 'Gen10' ) {
				$isGen10 = $true
				$Brand = "Hpe"
			}

            $Password      = $A.Password            $LoginName     = if ($A.LoginName) { $A.LoginName} else {$userName}            $PrivList      = if ($A.Privileges) { $($A.Privileges).split('|')} else { ""}                    if ($PrivList -eq 'All')             {                $PrivList = @(
                    'RemoteConsolePriv',                    'iLOConfigPriv',                    'VirtualMediaPriv',                    'UserConfigPriv',                    'VirtualPowerAndResetPriv',
					'LoginPriv')

				# for Gen9 and older, Host* privileges are not valid
				# if 'SystemRecoveryConfigPriv'	is used, then the scripts exit with errors
				if ( $isGen10 ) {
					$PrivList += 'HostBIOSConfigPriv'
					$PrivList += 'HostNICConfigPriv'
					$PrivList += 'HostStorageConfigPriv'
				}
            }
            ## ----- Build up data now            $priv = @{}
                foreach ($p in $PrivList)
                {
                    $priv.Add($p,$true)
                }            $hp = @{}
                $hp.Add('LoginName',$LoginName)
                $hp.Add('Privileges',$priv)            $oem = @{}
                $oem.Add($Brand,$hp)
            $Headers = @{}
                $Headers.Add("UserName" , $userName)                            
                $Headers.Add("Password" , $Password)   
                $Headers.Add('Oem',$oem)

            $data  = $Headers |ConvertTo-Json -Depth 10            if ($ThisServer)            {                $ThisRemoteConsole = "$($ThisServer.Uri)/remoteConsoleUrl"                $resp = Send-HPOVRequest $ThisRemoteConsole                $URL,$session          = $resp.remoteConsoleUrl.Split("&")
                $http, $iLOIP          = $URL.split("=")
                $sName,$sessionkey     = $session.split("=")                        $rootURI   = "https://$iLOIP/redfish/v1"                $AcctUri   = "/redfish/v1/AccountService/Accounts"                $iloSession = new-object PSObject -Property @{"RootUri" = $rootURI ; "X-Auth-Token" = $sessionkey}                                write-host -ForegroundColor Cyan "-----------------------------------------------------"                write-host -ForegroundColor Cyan "Creating account $username on ILO $iLOIP.... "                write-host -ForegroundColor Cyan "-----------------------------------------------------"				# Invoke-HPRESTAction does not work on Gen10
                Invoke-HPERedFishAction -Odataid $AcctUri -data $headers -session $iLOsession -DisableCertificateAuthentication            }            else            {                write-host -foreground Yellow "Server Hardware --> $ServerName is not managed by this OneView appliance. Skip creating accounts in iLO"            }                    } #end else username empty                  }

}

## -------------------------------------------------------------------------------------------------------------
##
##                     Main Entry
##
## -------------------------------------------------------------------------------------------------------------

       # -----------------------------------       #    Always reload module          $LoadedModule = get-module -listavailable $OneviewModule       if ($LoadedModule -ne $NULL)       {         $LoadedModule = $LoadedModule.Name.Split('.')[0] + "*"         remove-module $LoadedModule       }       import-module $OneViewModule

       # ---------------- Connect to OneView appliance       #       write-host -ForegroundColor Cyan "-----------------------------------------------------"       write-host -ForegroundColor Cyan "Connect to the OneView appliance..."       write-host -ForegroundColor Cyan "-----------------------------------------------------"       Connect-HPOVMgmt -appliance $OVApplianceIP -user $OVAdminName -password $OVAdminPassword
       if ( ! [string]::IsNullOrEmpty($iLOAccountCSV) -and (Test-path $iLOAccountCSV) )
       {
           Create-iLOAccount -iLOAccountCSV $iLOAccountCSV        }



       write-host -ForegroundColor Cyan "-----------------------------------------------------"
       write-host -ForegroundColor Cyan "Disconnect from OneView appliance ................"
       write-host -ForegroundColor Cyan "-----------------------------------------------------"
       
       Disconnect-HPOVMgmt