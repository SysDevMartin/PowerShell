<#PSScriptInfo

.VERSION 1.0.0

.GUID da13a505-66d9-4f4f-8218-d83a36b030d4

.AUTHOR Martin Olsson

.COMPANYNAME Martin Olsson

.COPYRIGHT (c) Martin Olsson. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES DhcpServer,DnsServer,GroupPolicy

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.PRIVATEDATA

#>

<# 

.DESCRIPTION 
Back-up Windows Server domain configuration (DNS, DHCP, GPO).

.EXAMPLE
Export-WindowsServerDomainConfiguration -Destination 'C:\Backups\WindowsServerConfig'

Export DNS, DHCP and GPO configurations to C:\Backups\WindowsServerConfig and keep them forever.

.EXAMPLE
Export-WindowsServerDomainConfiguration -Destination 'C:\Backups\WindowsServerConfig' -RetentionDays 90

Export DNS, DHCP and GPO configurations to C:\Backups\WindowsServerConfig and delete previously exported configurations that are older than 90 days. Setting the RetentionDays parameter value to 0 (or omitting the RetentionDays parameter) will keep the files forever.
#>
param(
    [Parameter(Mandatory)]
    [ValidateScript({
        if (Test-Path -Path $_ -PathType Container) { return $true }
        else { throw [System.IO.DirectoryNotFoundException] "Cannot find the directory '$($_)'." }
    })]
    [string]$Destination,

    [Parameter(Mandatory)]
    [ValidateRange(0, 3650)]
    [int]$RetentionDays = 0,

    [ValidateNotNull()]
    [string[]]$DNSZones = @()
)

#region Functions

function Remove-ExpiredBackupItem {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Container) { return $true }
            else { throw [System.IO.DirectoryNotFoundException] "Cannot find the directory '$($_)'." }
        })]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Filter,

        [Parameter(Mandatory)]
        [ValidateRange(0, 3650)]
        [int]$RetentionDays
    )

    try {
        # Get items in the path that match the filter and age (last write time).
        $itemList = Get-ChildItem -Path $Path -Filter $Filter | Where-Object {
            ($null -ne $_.CreationTime) -and
            ($null -ne $_.LastWriteTime) -and
            (
                ($_.CreationTime.Date -lt ((Get-Date).AddDays(-($RetentionDays))).Date) -or
                ($_.LastWriteTime.Date -lt ((Get-Date).AddDays(-($RetentionDays))).Date)
            )
        }

        # Delete the filtered items.
        $itemList | ForEach-Object {
            if (Test-Path -Path $_.FullName -PathType Leaf) {
                try {
                    # Delete file.
                    Remove-Item -Path $_.FullName
                    Write-Verbose "Deleted expired file '$($_.Name)'."
                }
                catch {
                    throw "Failed to delete expired backup file '$($_.FullName)'. $($PSItem)"
                }
            }
            elseif (Test-Path -Path $_.FullName -PathType Container) {
                try {
                    # Delete directory and sub-items.
                    Remove-Item -Path $_.FullName -Recurse -Force
                    Write-Verbose "Deleted expired directory '$($_.Name)'."
                }
                catch {
                    throw "Failed to delete expired backup directory '$($_.FullName)'. $($PSItem)"
                }
            }
        }
    }
    catch {
        throw "Failed to delete expired backup items in '$($Path)' with filter '$($Filter)'. $($PSItem)"
    }
}

#endregion

$DHCPDestinationDirectoryPath = Join-Path -Path $Destination -ChildPath 'DHCP'
$DNSDestinationDirectoryPath = Join-Path -Path $Destination -ChildPath 'DNS'
$GPODestinationDirectoryPath = Join-Path -Path $Destination -ChildPath 'GPO'

# Delete old DHCP configuration exports.
if ($RetentionDays -gt 0) {
    $params = @{
        Path = $DHCPDestinationDirectoryPath
        Filter = 'DHCP_Config*.xml'
        RetentionDays = $RetentionDays
    }
    try {
        Remove-ExpiredBackupItem @params
    }
    catch {
        Write-Error "Failed to delete expired DHCP configurations. $($PSItem)"
    }
}

# Export current DHCP configuration.
try {
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $filename = ('{0}_{1}{2}' -f 'DHCP_Config', $timestamp, '.xml')
    $exportPath = Join-Path -Path $DHCPDestinationDirectoryPath -ChildPath $filename
    Export-DhcpServer -File $exportPath -ErrorAction Stop
}
catch {
    Write-Error "Failed to export DHCP configuration. $PSItem"
}

# Delete old DNS record exports.
if ($RetentionDays -gt 0) {
    $params = @{
        Path = $DNSDestinationDirectoryPath
        Filter = 'DNS_Zone*.csv'
        RetentionDays = $RetentionDays
    }
    Remove-ExpiredBackupItem @params
}

# Export current DNS records.
if (($DNSZones | Measure-Object).Count -gt 0) {
    $DNSZones | ForEach-Object {
        try {
            $properties = @(
                'HostName',
                @{
                    Name = 'RecordData'
                    Expression = {
                        if (-not [string]::IsNullOrWhitespace($_.RecordData.IPv4Address)) { $_.RecordData.IPv4Address }
                        else { $_.RecordData.NameServer }
                    }
                },
                'RecordType',
                'RecordClass',
                'DistinguishedName',
                'Timestamp',
                'TimeToLive',
                'PSComputerName'
            )
            $zone = $_
            $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
            $filename = ('{0}_{1}_{2}{3}' -f 'DNS_Zone', $zone, $timestamp, '.csv')
            $exportPath = Join-Path -Path $DNSDestinationDirectoryPath -ChildPath $filename
            Get-DnsServerResourceRecord -ZoneName $zone | Select-Object -Property $properties | Export-Csv -Path $exportPath -Delimiter ';' -NoTypeInformation
        }
        catch {
            Write-Error "Failed to export DNS records for zone '$zone' to '$exportPath'. $PSItem"
        }
    }
}

# Delete old GPO reports.
if ($RetentionDays -gt 0) {
    $params = @{
        Path = $GPODestinationDirectoryPath
        Filter = 'GPO_Report*.html'
        RetentionDays = $RetentionDays
    }
    try {
        Remove-ExpiredBackupItem @params
    }
    catch {
        Write-Error "Failed to delete expired GPO reports. $PSItem"
    }
}

# Export GPO report for current configuration.
try {
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $filename = ('{0}_{1}{2}' -f 'GPO_Report', $timestamp, '.html')
    $exportPath = Join-Path -Path $GPODestinationDirectoryPath -ChildPath $filename
    Get-GPOReport -All -ReportType HTML -Path $exportPath
}
catch {
    Write-Error "Failed to export GPO report to '$exportPath'. $PSItem"
}

# Delete old GPO configurations.
if ($RetentionDays -gt 0) {
    $params = @{
        Path = $GPODestinationDirectoryPath
        Filter = 'GPO_Policies*.zip'
        RetentionDays = $RetentionDays
    }
    try {
        Remove-ExpiredBackupItem @params
    }
    catch {
        Write-Error "Failed to delete expired GPO configurations. $($PSItem)"
    }
}

# Export current GPO configuration.
try {
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $directoryName = ('{0}_{1}' -f 'GPO_Policies', $timestamp)
    $exportDirectoryPath = Join-Path -Path $GPODestinationDirectoryPath -ChildPath $directoryName
    New-Item -Path $exportDirectoryPath -ItemType Directory | Out-Null
    Backup-GPO -All -Path $exportDirectoryPath | Out-Null

    $zipFilename = 'GPO_Policies_{0}.zip' -f $timestamp
    $zipFilePath = Join-Path -Path $GPODestinationDirectoryPath -ChildPath $zipFilename
    Compress-Archive -Path $exportDirectoryPath -DestinationPath $zipFilePath

    Remove-Item -Path $exportDirectoryPath -Recurse
}
catch {
    Write-Error "Failed to export GPO configuration to '$exportPath'. $PSItem"
}