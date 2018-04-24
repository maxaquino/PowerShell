##############################################################################
# Server_Profile_Template_Multiconn.ps1
#
# Example script to demonstrate creating a Server Profile Template
# with the following:
#
# - HPE Synery 480 Gen 9
# - Configure a Server Profile Template using a csv file
# - Local Storage
#
#
#   VERSION 3.10
#
# (C) Copyright 2013-2018 Hewlett Packard Enterprise Development LP 
##############################################################################
<#
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>
##############################################################################

if (-not (get-module HPOneview.310)) 
{

    Import-Module HPOneView.310

}

###$MyConnection = Connect-HPOVMgmt -Hostname 192.168.0.20 -Credential $HPOVPSCredential
$MyConnection = Connect-HPOVMgmt -Hostname 192.168.0.20 -Username Administrator -Password password

# View the connected HPE OneView appliances from the library by displaying the global $ConnectedSessions variable
$ConnectedSessions

# Now view what enclosures have been imported
Get-HPOVEnclosure

# Now list all the servers that have been imported with their current state
Get-HPOVServer

$ProfileTemplateCSV = ".\ProfileTemplate.csv"

# Read the CSV  file
$tempFile = [IO.Path]::GetTempFileName()
type $ProfileTemplateCSV | where { ($_ -notlike ",,,,*") -and ( $_ -notlike "#*") -and ($_ -notlike ",,,#*") } > $tempfile   # Skip blank line

$ProfileTemplateList  = import-csv $tempfile


foreach ($SPT in $ProfileTemplateList)
{
  $TemplateName        = $SPT.ProfileTemplateName
  $TemplateDescription = $SPT.Description
  $ServerHardwareType  = $SPT.ServerHardwareType
  $eg                  = Get-HPOVEnclosureGroup -Name $SPT.EnclosureGroup
  $Firmware            = ($SPT.FWEnable -like 'Yes')
  $BootMode            = $SPT.BootMode
  $ManageBoot          = ($SPT.ManageBoot -like 'Yes')
  $BootOrder           = $SPT.BootOrder
  $HideUnusedFlexnics  = ($SPT.HideUnusedFlexnics -like 'Yes')
  $connectionarray = @()
  # the maximum flex nics allowed is 8
  1..8 | % {
    $conn          = "conn" + $_
	$desc          = "conn" + $_ + "desc"
	$networktype   = ""
	$Cmd           = "Get-HPOVNetwork"
    $connectionid  = $_
	$networktype,$connectionname,$connectiondescription = $SPT.$conn.Split('|')
	
	if ( $connectionname ) {
	    # Se ns = networkset, altrimenti estrae network
	    if ( $networktype -eq 'ns' ) { $Cmd = "Get-HPOVNetworkSet" }

		# il carattere ` serve per fare il parse delle variabili altrimenti in caso di spazio fallisce il comando
		$Cmd += " -Name `$connectionname -ErrorAction Stop | New-HPOVServerProfileConnection -ConnectionID `$connectionid -Name `$connectiondescription"
		$conntemp = Invoke-Expression $Cmd
		
		$connectionarray += $conntemp
	}
  }
}


# Next, show the avialble servers from the available Server Hardware Type
$SY480Gen9SHT = Get-HPOVServerHardwareType -name $ServerHardwareType -ErrorAction Stop
Get-HPOVServer -ServerHardwareType $SY480Gen9SHT -NoProfile

#Disconnect-HPOVMgmt -Hostname $MyConnection

#Exit

$LogicalDisk1        = New-HPOVServerProfileLogicalDisk -Name 'BootDisk' -RAID RAID1 -Bootable $True
$StorageController   = New-HPOVServerProfileLogicalDiskController -ControllerID Embedded -Mode RAID -Initialize -LogicalDisk $LogicalDisk1

$params = @{
	Name               = $TemplateName;
	Description        = $TemplateDescription;
	ServerHardwareType = $SY480Gen9SHT;
	EnclosureGroup     = $eg;
	Connections        = $connectionarray;
	Firmware           = $Firmware;
	BootMode           = $BootMode;
	ManageBoot         = $ManageBoot;
	BootOrder          = $BootOrder;
	LocalStorage       = $True;
	StorageController  = $StorageController;
	HideUnusedFlexnics = $HideUnusedFlexnics
}

# Create Server Profile Template
New-HPOVServerProfileTemplate @params | Wait-HPOVTaskComplete

# Get the created Server Profile Template
$spt = Get-HPOVServerProfileTemplate -Name "$TemplateName" -ErrorAction Stop

# Create Server Profile from Server Profile Template, searching for a SY480 Gen10 server with at least 2 CPU and 256GB of RAM
Get-HPOVServer -ServerHardwareType $SY480Gen9SHT -NoProfile -ErrorAction Stop | ? { ($_.processorCount * $_.processorCoreCount) -ge 2 -and $_.memoryMb -ge (256 * 1024) } | Select -First 1 -OutVariable svr

# Make sure servers are powered off
$svr | Stop-HPOVServer -Confirm:$false

# Create the number of Servers from the $svr collection
1..($svr.Count) | % {

	New-HPOVServerProfile -Name "ServerProfile-0$_" -Assignment Server -Server $svr[($_ - 1)] -ServerProfileTemplate $spt -Async

}

Get-HPOVTask -State Running | Wait-HPOVTaskComplete

Disconnect-HPOVMgmt -Hostname $MyConnection
