<#PSScriptInfo

.VERSION 1.0.0

.GUID dd97ca12-6b5c-4f3c-a67b-491eda880d80

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
 Prepares and configures a computer for deployment 

#> 
[CmdletBinding()]
param(
    [string]$DomainName,

    [string]$DomainJoinAccountUsername,

    [string]$DesktopOUPath,

    [string]$LaptopOUPath,

    [string]$WifiProfilePath = 'Resources\WifiProfile.xml',

    [ValidateNotNull()]
    [int]$MonitorTimeoutOnPowerSupply = 30,

    [ValidateNotNull()]
    [int]$MonitorTimeoutOnBattery = 15,

    [ValidateNotNull()]
    [int]$StandbyTimeoutOnPowerSupply = 0,

    [ValidateNotNull()]
    [int]$StandbyTimeoutOnBattery = 60,

    [ValidateNotNull()]
    [bool]$DoNothingOnLidClose = $true,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [string]$RootDirectoryPath,

    [ValidateNotNull()]
    [string]$SoftwareDirectoryPath = 'Software',

    [ValidateNotNull()]
    [string]$SoftwareSettingsFilename = 'settings.csv'
)

Get-ChildItem -Path "$($PSScriptRoot)\Functions\*.ps1" | ForEach-Object { . $_.FullName }

if (-not (Test-CCRunAsAdmin)) {
    throw 'The script needs to run as an administrator.'
}

Write-Host "`n# Set computer name" -ForegroundColor Cyan
try {
    Rename-CCComputer
}
catch {
    throw "Failed to rename computer. $PSItem"
}

Write-Host "`n# Configure settings" -ForegroundColor Cyan
Disable-CCStartupSound

$params = @{
    MonitorTimeoutOnPowerSupply = $MonitorTimeoutOnPowerSupply
    MonitorTimeoutOnBattery = $MonitorTimeoutOnBattery
    StandbyTimeoutOnPowerSupply = $StandbyTimeoutOnPowerSupply
    StandbyTimeoutOnBattery = $StandbyTimeoutOnBattery
    DoNothingOnLidClose = $DoNothingOnLidClose
}
Set-CCPowerSettings @params

Write-Host "`n# Validate Windows license" -ForegroundColor Cyan
Write-Output 'Validating activation status...'
if (-not (Test-CCWindowsActivationStatus)) {
    Write-Error 'Windows is not activated.'
    Read-Host 'Press <Enter> to continue or <Ctrl+C> to cancel'
}

Write-Host "`n# Install software" -ForegroundColor Cyan
$params = @{
    Title = 'Software'
    Prompt = ('Install software?' -f $hwidFilePath)
    Choices = @('&Yes', '&No')
    Default = 0
}
$softwareInstallationChoice = Read-CCUserChoice @params

if ($softwareInstallationChoice -eq 0) {
    $softwareSettings = [PSCustomObject]@()
    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem -Verbose:$false).Manufacturer
    $softwareDirectories = Get-ChildItem -Path (Join-Path -Path $RootDirectoryPath -ChildPath $SoftwareDirectoryPath) -Directory

    foreach ($dir in $softwareDirectories) {
        $softwareSettingsFilePath = Join-Path -Path $dir.FullName -ChildPath $SoftwareSettingsFilename
        $softwareSettings += Get-CCSoftwareSettings -Path $softwareSettingsFilePath
    }

    $softwareSettings = $softwareSettings | Sort-Object -Property InstallOrder, Name

    foreach ($settings in $softwareSettings) {
        if ($null -ne $settings) {
            if ((-not [string]::IsNullOrEmpty($manufacturer)) -and ($manufacturer -like $settings.Manufacturer)) {
                $isSoftwareInstalled = Test-CCSoftwareInstallation -InstallationPath $settings.InstallValidationPath

                if (-not $isSoftwareInstalled) {
                    $params = @{
                        DirectoryPath = $settings.DirectoryPath
                        Filter = $settings.File
                        Argument = $settings.Argument
                    }
                    Install-CCSoftware @params
                }
                else {
                    Write-Warning ("Skipping ""$($settings.Name)"". It's already installed.")
                }
            }
            else {
                Write-Warning "Skipping ""$($settings.Name)"". Device manufacturer ""$manufacturer"" doesn't match ""$($settings.Manufacturer)""."
            }
        }
        else {
            Write-Error ('Skipping "{0}". Invalid software settings. Check the settings file.' -f $settings.Name)
        }
    }

    Write-Host "`n# Validate installations" -ForegroundColor Cyan
    Write-Output 'Validating software installations...'
    foreach ($dir in $softwareDirectories) {
        $softwareSettingsFilePath = Join-Path -Path $dir.FullName -ChildPath $SoftwareSettingsFilename
        $softwareSettings = Get-CCSoftwareSettings -Path $softwareSettingsFilePath

        if (($null -ne $softwareSettings) -and
            (-not [string]::IsNullOrEmpty($softwareSettings.InstallValidationPath)) -and
            (-not [string]::IsNullOrEmpty($manufacturer)) -and
            ($manufacturer -like $softwareSettings.Manufacturer)
        ) {
            Write-Verbose ('Validating installation for "{0}"...' -f $softwareSettings.Name)
            $isSoftwareInstalled = Test-CCSoftwareInstallation -InstallationPath $softwareSettings.InstallValidationPath
            if (-not $isSoftwareInstalled) {
                Write-Warning ('"{0}" is not installed.' -f $softwareSettings.Name)
            }
        }
    }
}

Write-Host "`n# Export hardware ID file" -ForegroundColor Cyan
$hwidFilePath = Join-Path -Path $RootDirectoryPath -ChildPath "$($env:COMPUTERNAME)_HWID.csv"
if (-not (Test-Path -Path $hwidFilePath)) {
    $params = @{
        Title = 'Hardware ID'
        Prompt = ('Export hardware ID file to "{0}"?' -f $hwidFilePath)
        Choices = @('&No', '&Yes')
        Default = 0
    }
    $exportHwidFileChoice = Read-CCUserChoice @params

    if (($exportHwidFileChoice -eq 1) -and (-not (Test-Path -Path $hwidFilePath))) {
        Export-CCHardwareId -Path $hwidFilePath
    }
}
else {
    Write-Warning ('Hardware ID file "{0}" already exists.' -f $hwidFilePath)
}

Write-Host "`n# Set computer type" -ForegroundColor Cyan
$ComputerOUPath = $null

$params = @{
    Title = 'Computer type'
    Prompt = 'What type of computer is this?'
    Choices = @('&Desktop', '&Laptop')
    Default = 0
}
$computerTypeChoice = Read-CCUserChoice @params

switch ($computerTypeChoice) {
    0 {
        # Desktop.
        Write-Output "Setting desktop OU path: $DesktopOUPath"
        $ComputerOUPath = $DesktopOUPath
    }

    1 {
        # Laptop.
        if (-not [string]::IsNullOrEmpty($LaptopOUPath)) {
            Write-Output "Setting laptop OU path: $LaptopOUPath"
            $ComputerOUPath = $LaptopOUPath
        }

        if (-not [string]::IsNullOrEmpty($WifiProfilePath)) {
            Write-Output 'Adding wifi profile...'
            $fullWifiProfileFilePath = Join-Path -Path $RootDirectoryPath -ChildPath $WifiProfilePath
            Add-CCWifiProfile -Path $fullWifiProfileFilePath
        }
    }
}

if (-not [string]::IsNullOrEmpty($DomainName)) {
    Write-Host "`n# Domain-join the computer" -ForegroundColor Cyan

    if ([string]::IsNullOrEmpty($ComputerOUPath)) {
        Write-Warning 'Computer OU path is empty. The computer will be added to the default AD computer OU.'
    }
    else {
        Write-Host "OU path: $ComputerOUPath"
    }

    if (-not [string]::IsNullOrEmpty($DomainJoinAccountUsername)) {
        $credentials = Get-Credential -Credential $DomainJoinAccountUsername
    }
    else {
        $credentials = Get-Credential
    }

    if (-not [string]::IsNullOrEmpty($ComputerOUPath)) {
        Add-CCComputerToDomain -DomainName $DomainName -OUPath $ComputerOUPath -Credential $credentials
    }
    else {
        Add-CCComputerToDomain -DomainName $DomainName -Credential $credentials
    }
}