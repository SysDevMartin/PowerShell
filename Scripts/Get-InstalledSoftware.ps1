<#PSScriptInfo

.VERSION 1.0.0

.GUID df29f67e-4af9-4527-b2e5-440d0ca1b603

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
Get a list of installed software.

.DESCRIPTION 
This script fetches a list of installed software from the registry.

.INPUTS
None

.OUTPUTS
.System.Management.Automation.PSCustomObject

.EXAMPLE
Get-InstalledSoftware

#>
param()

begin {
    $installedSoftware = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_.DisplayName) }
}

process {
    $softwareList = [PSCustomObject]($installedSoftware | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Sort-Object DisplayName)
}

end {
    return $softwareList

}
