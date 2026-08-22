<#PSScriptInfo

.VERSION 1.0.0

.GUID 5bf239ee-ba5a-4d72-98a1-228e1d174fb5

.AUTHOR Martin Olsson

.COMPANYNAME Martin Olsson

.COPYRIGHT (c) Martin Olsson. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 
.SYNOPSIS
Set Netboot GUID for an Active Directory computer. A use-case could be auto-deploying Windows to new machines.

.DESCRIPTION 
This script takes an AD computer and a MAC address to update the computer's Netboot GUID with the provided MAC address. Requires you to provide account credentials with permissions to modify AD computers.

.INPUTS
None

.OUTPUTS
.None

.EXAMPLE
Get-ADComputer -Identity MyNewComputer | Set-ADComputerNetbootGuid -MACAddress 'AA:BB:CC:DD:EE:FF' -Credential 'MYDOMAIN\MyServiceAccountName'

#>
param(
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateNotNull()]
    [Microsoft.ActiveDirectory.Management.ADComputer]$Computer,

    [Parameter(Mandatory)]
    [ValidatePattern('^([a-zA-Z0-9]{2}:){5}[a-zA-Z0-9]{2}$')]
    [string]$MACAddress,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$Credential
)

try {
    $formattedMACAddress = $MACAddress.Replace(':', '').ToLower()
    [guid]$netbootGuid = "00000000-0000-0000-0000-$($formattedMACAddress)"
}
catch {
    throw "Failed to generate netboot GUID for $($Computer.Name). $($PSItem)"
}

try {
    $params = @{
        Identity = $Computer
        Replace = @{ 'netbootGUID' = $netbootGuid }
        Credential = $Credential
        Confirm = $true
    }
    Set-ADComputer @params
}
catch {
    throw "Failed to configure netboot GUID for $($Computer.Name). $($PSItem)"
}


Get-ADComputer -Identity $Computer -Property netbootGUID

