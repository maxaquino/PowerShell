##############################################################################
# DefineNetworks.ps1
# - Defines networks from a csv file.
#
#   VERSION 1.0
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
Function CreateNetwork {
    Param ([string]$NetworkName)
	$Cmd = "New-HPOVNetwork -type $Type -name `$NetworkName $Options"
	write-host
	write-host -ForegroundColor Cyan "Creating network $NetworkName..."

	$out = Invoke-Expression $Cmd
	
	if ( $NetworkSet ) {
	    $ns = Get-HPOVNetworkSet | Where Name -eq $NetworkSet
	    if ( $ns ) {
		    # Se il network set e' gia' presente, aggiunge la network
        	write-host -ForegroundColor Cyan "Adding network $NetworkName to $NetworkSet"
            $ns.networkUris += (Get-HPOVNetwork | where Name -eq $NetworkName).uri
            Set-HPOVNetworkSet -NetworkSet $ns
		}
		else {
		    # Il networkset non esiste
        	write-host -ForegroundColor Cyan "Creating the network set $NetworkSet and adding network $NetworkName"
			New-HPOVNetworkSet -name $NetworkSet -Networks $NetworkName
		}
	}
}

if (-not (get-module HPOneview.310))
{

    Import-Module HPOneView.310

}

if (-not $ConnectedSessions) 
{

	$Appliance = Read-Host 'ApplianceName'
	$Username  = Read-Host 'Username'
	$Password  = Read-Host 'Password' -AsSecureString

    $ApplianceConnection = Connect-HPOVMgmt -Hostname $Appliance -Username $Username -Password $Password

}

# List any existing networks and network sets
write-host "Existing Networks:"
write-host "---------------------------"
write-host
Get-HPOVNetwork
write-host
#write-host "Existing Network Sets:"
#write-host "---------------------------"
#write-host
#Get-HPOVNetworkSet
#write-host

$NetworksCSV = ".\Networks.csv"


# Read the CSV  file
$tempFile = [IO.Path]::GetTempFileName()
type $NetworksCSV | where { ($_ -notlike ",,,,*") -and ( $_ -notlike "#*") -and ($_ -notlike ",,,#*") } > $tempfile   # Skip blank line

$NetworksList  = import-csv $tempfile

foreach ($Net in $NetworksList)
{
    $Options              = ""
	$vlanID               = ""
	$NetworkSet           = $Net.NetworkSet
    $NetworkName          = $Net.NetworkName

    # Se la rete esiste gia', skip al item successivo
	$n = Get-HPOVNetwork | where Name -eq $NetworkName
	if ( $n ) {
	    write-host -ForegroundColor Yellow "$NetworkName already exist"
		continue
	}

	$Type                 = $Net.Type
	$vlanID               = $Net.vlanID
	if ( $vlanID ) { $Options = " -vlanId `$vlanID " }
	$vlanRange            = $Net.vlanRange
	###if ( $vlanRange ) { $Options = " -vlanRange `$vlanRange " }
	$vlanType             = $Net.vlanType
	$Subnet               = $Net.Subnet
	$NSTypicalBandwidth   = $Net.NSTypicalBandwidth
	$NSMaximumBandwidth   = $Net.NSMaximumBandwidth
	$TypicalBandwidth     = $Net.TypicalBandwidth
	$MaximumBandwidth     = $Net.MaximumBandwidth
	if ( $Net.SmartLink -eq 'Yes' ) {  $Options += " -SmartLink `$true"}
	$PrivateNetwork       = $Net.PrivateNetwork
	$Purpose              = $Net.Purpose

    $FabricType           = $Net.FabricType
	$ManagedSAN           = $Net.ManagedSAN
	#$LoginRedistribution = ""
	#$LinkStabilityTime   = ""
	
	if ( $vlanRange ) {
	    $start,$end = $vlanRange.Split('-')
		$start..$end | % {
			# In case of a vlan Range, it needs to set the vlan id again
			$Options = " -vlanId $_ "
		    $newNetworkName = $NetworkName + "_" + $_
			CreateNetwork -NetworkName $newNetworkName
		}
	}
	else {
	    $newNetworkName = $NetworkName
		CreateNetwork -NetworkName $newNetworkName
	}
}

