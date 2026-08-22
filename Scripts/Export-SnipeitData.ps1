#Requires -Modules SnipeitPS
<#PSScriptInfo

.VERSION 1.0.0

.GUID 88ee7e07-8202-47d7-b283-80a6607bdeb9

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
.DESCRIPTION
Export data from Snipe-IT. Requires the SnipeitPS module.

.EXAMPLE

Export-SnipeitData.ps1 -ApiBaseUrl 'https://snipeit.domain.com' -SecureApiKey (Read-Host 'API key' -AsSecureString) -Destination 'C:\Snipe-IT\Backup'

Export Snipe-IT data to CSV files.

.EXAMPLE
Export-SnipeitData.ps1 -ApiBaseUrl 'https://snipeit.domain.com' -SecureApiKey (Read-Host 'API key' -AsSecureString) -Destination 'C:\Snipe-IT\Backup' -RetentionDays 90

Export Snipe-IT data to CSV files, then delete exported files that are 90 days or older.
#>
param(
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [string]$ApiBaseUrl,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [SecureString]$SecureApiKey,

    [Parameter(Mandatory)]
    [ValidateScript({
        if (Test-Path -Path $_ -PathType Container) { return $true }
        else { throw [System.IO.DirectoryNotFoundException] "Cannot find the directory '$_'." }
    })]
    [string]$DestinationDirectoryPath,

    [ValidateRange(0, 3650)]
    [int]$RetentionDays = 0
)

Write-Verbose 'Connecting to Snipe-IT...'
try {
    Connect-SnipeitPS -url $ApiBaseUrl -apiKey (ConvertFrom-SecureString -SecureString $SecureApiKey -AsPlainText)
}
catch {
    Write-Error "Failed to connect to Snipe-IT. $PSItem"
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HHmmss'
$exportAssetsFilename = 'Snipe-IT assets ({0}).csv' -f $timestamp
$exportAssetsFilePath = Join-Path -Path $DestinationDirectoryPath -ChildPath $exportAssetsFilename

$exportUsersFilename = 'Snipe-IT users ({0}).csv' -f $timestamp
$exportUsersFilePath = Join-Path -Path $DestinationDirectoryPath -ChildPath $exportUsersFilename

Write-Verbose 'Getting assets...'
$assets = Get-SnipeitAsset -all
if ($null -ne $assets) {
    Write-Verbose 'Exporting assets to CSV...'
    $assets | Export-Csv -Path $exportAssetsFilePath -Delimiter ';'
    (Get-Item -Path $exportAssetsFilePath).FullName
}

Write-Verbose 'Getting users...'
$users = Get-SnipeitUser -all
if ($null -ne $users) {
    Write-Verbose 'Exporting users to CSV...'
    $users | Export-Csv -Path $exportUsersFilePath -Delimiter ';'
    (Get-Item -Path $exportUsersFilePath).FullName
}

# Clean up old exported files.
if ($RetentionDays -gt 0) {
    Write-Host "Cleaning up old exported files in '$DestinationDirectoryPath'..."
    Get-ChildItem -Path $DestinationDirectoryPath -Filter 'Snipe-IT * (*).csv' -File | Where-Object {
        $_.CreationTime -lt (Get-Date).AddDays(-($RetentionDays))
    } | Remove-Item
}