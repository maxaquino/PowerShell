##############################################################################
# Manage_Scope.ps1
#
# Example script to manage multitenance users.
# Starting from a csv file, this script creates a new scope and associate it some resources (users, networks and server hardware)
#
#
#
#   VERSION x
#
# (C) Copyright 2013-2018 Hewlett Packard Enterprise Development LP 
##############################################################################

#if (-not (get-module HPOneview.310)) 
#{
#    Import-Module HPOneView.310
#}

# Se specificato lo switch delete, cancella scopes e utenti
Param(
   [switch]$delete
)

write-host "Connecting to the appliance...."
###$MyConnection = Connect-HPOVMgmt -Hostname 192.168.0.20 -Credential $HPOVPSCredential
$MyConnection = Connect-HPOVMgmt -Hostname 192.168.0.20 -Username Administrator -Password password

# View the connected HPE OneView appliances from the library by displaying the global $ConnectedSessions variable
###$ConnectedSessions

$ScopeCSV = ".\Scope.csv"

# Read the CSV  file
$tempFile = [IO.Path]::GetTempFileName()
type $ScopeCSV | where { ($_ -notlike ",,,,*") -and ( $_ -notlike "#*") -and ($_ -notlike ",,,#*") } > $tempfile   # Skip blank line

$ScopeList  = import-csv $tempfile

$uri_user = "/rest/users"

#ScopeName,UserName,UserDescription,UserPassword,Networks,ServerHardware
#Client_03,client03,client 03,password,net1:800|net2:801,"CN754604F4, bay 1"

foreach ($SC in $ScopeList)
{
  $ScopeName        = $SC.ScopeName
  $ScopeDescription = $SC.ScopeDescription
  $UserName         = $SC.UserName
  $UserDescription  = $SC.UserDescription
  $UserPassword     = $SC.UserPassword
  $Networks         = $SC.Networks
  $ServerHardware   = $SC.ServerHardware
  
  #write-host $ScopeName
  #write-host $ScopeDescription
  #write-host $UserName
  #write-host $UserDescription
  #write-host $UserPassword
  #write-host $Networks
  #write-host $ServerHardware

  if ( -not $delete ) {
    write-host "`nCreating a new scope $ScopeName"
    New-HPOVScope -Name $ScopeName -Description $ScopeDescription
    
    Start-Sleep -s 10
    
    #write-host "Waiting for the scope to be created..."
    do {
      Start-Sleep -s 1
      #write-host "sleep 1 sec"
      $scope = Get-HPOVScope -Name $ScopeName
    } while ( -not $scope )
    
    write-host "`nManaging Networks"
    $NetList = $Networks.Split("|")
    foreach ($network in $NetList) {
      $net,$vlanid= $network.Split('=')
	  
	  $isnet = Get-HPOVNetwork | where Name -eq $net
	  if ( $isnet -eq $Null ) {
	    write-host "Creating $net..."
	    $out = New-HPOVNetwork -type Ethernet -name $net -vlanid $vlanid -Scope $scope
	  }
	  else {
	    # Se la network esiste, la aggiungo alle risorse da assegnare allo scope
		write-host "Adding network $net into the scope..."
	    $resources = Get-HPOVNetwork -name $net
		$out = Get-HPOVScope -Name $scope | Add-HPOVResourceToScope -InputObject $resources
	  }
    }
    
    #write-host "Get the first two server and assign them to the current scope"
    #$resources += Get-HPOVServer -NoProfile -ErrorAction Stop | Select -First 2
    #Get-HPOVScope -Name $scope | Add-HPOVResourceToScope -InputObject $resources
    write-host "`nManaging Server Hardware..."
    $ServerList = $ServerHardware.Split("|")
    foreach ($server in $ServerList) {
      # aggiungo il server hardware allo scope
	  write-host "Adding server $server into the scope"
      $resources = Get-HPOVServer -name $server
	  $out = Get-HPOVScope -Name $scope | Add-HPOVResourceToScope -InputObject $resources
    }
    
    # aggiungo tutte le risorse allo scope
    #Get-HPOVScope -Name $scope | Add-HPOVResourceToScope -InputObject $resources
    
    write-host "`n`nCreating a new user and assigning a scope..."
    $body = '{"type":"UserAndPermissions","userName":"' + $UserName + '","fullName":"' + $UserDescription + '","password":"' + $UserPassword + '","emailAddress":"","officePhone":"","mobilePhone":"","enabled":true,"permissions":[{"roleName":"Server administrator","scopeUri":"' + $scope.uri + '"}]}'
    ###write-host $body
    
    $out = Send-HPOVRequest -uri $uri_user -method POST -body $body
  }
  else {
    write-host "Removing $ScopeName and $UserName"
	Get-HPOVUser -Name $UserName | Remove-HPOVUser -Confirm:$false
	Get-HPOVScope -Name $ScopeName | Remove-HPOVScope -Confirm:$false
  }

}

Disconnect-HPOVMgmt

