<#PSScriptInfo

.VERSION 1.0.0

.GUID 78e86a37-3bb3-479c-be12-41ed50a1d60a

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
    Installs Java

    .DESCRIPTION
    This script uninstalls old Java versions, then installs a newer version. Use the SkipUninstallation switch to only install Java, without trying to uninstall anything first.

    .INPUTS
    None

    .OUTPUTS
    None
#> 
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('17.0.12')]
    [string]$Version = '17.0.12',

    [switch]$SkipUninstallation
)

function Out-LogFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [string]$Content,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$DirectoryPath
    )

    if (-not (Test-Path -Path $DirectoryPath)) {
        Write-Verbose "Creating log directory '$DirectoryPath'."
        New-Item -Path $DirectoryPath -ItemType Directory
    }

    $logFilePath = Join-Path -Path $DirectoryPath -ChildPath 'Install-Java.log'
    ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Content) | Out-File -FilePath $logFilePath -Append -ErrorAction Continue
}

function Get-JavaVersionInfo {
    return [PSCustomObject]@(
        @{
            Version = '17'
            InstallationName = 'jdk-17'
            SoftwareId = '{7111A3FA-CDA7-58DA-874C-94AAB58DCF67}'
        }

        @{
            Version = '17.0.1'
            InstallationName = 'jdk-17.0.1'
            SoftwareId = '{7ECAAC8F-FBBE-5265-BBF4-0AC48139FB26}'
        }

        @{
            Version = '17.0.2'
            InstallationName = 'jdk-17.0.2'
            SoftwareId = '{65BA81E7-0238-5B54-9069-A59610247B0B}'
        }

        @{
            Version = '17.0.3'
            InstallationName = 'jdk-17.0.3'
            SoftwareId = '{05A143A7-E923-580E-8FF9-D6D9679FEE40}'
        }

        @{
            Version = '17.0.3.1'
            InstallationName = 'jdk-17.0.3.1'
            SoftwareId = '{6BFFE4EC-9566-51A5-A7CB-37999A712E2B}'
        }

        @{
            Version = '17.0.4'
            InstallationName = 'jdk-17.0.4'
            SoftwareId = '{939A3D92-E4EC-599C-B706-C872465960D2}'
        }

        @{
            Version = '17.0.4.1'
            InstallationName = 'jdk-17.0.4.1'
            SoftwareId = '{A2B43423-25AE-511B-9487-A304DCCA672A}'
        }

        @{
            Version = '17.0.5'
            InstallationName = 'jdk-17.0.5'
            SoftwareId = '{523C28BF-1BB4-5EB4-AD61-2D035E64A315}'
        }

        @{
            Version = '17.0.6'
            InstallationName = 'jdk-17'
            SoftwareId = '{1D1A55AE-520B-5885-B559-6121460FE780}'
        }

        @{
            Version = '17.0.7'
            InstallationName = 'jdk-17.0.7'
            SoftwareId = '{61C3B7D2-33F9-5107-9F20-AB1A7C8B5C2A}'
        }

        @{
            Version = '17.0.8'
            InstallationName = 'jdk-17'
            SoftwareId = '{77C5AB95-C9DB-5259-B8E9-0AB8E68ED510}'
        }

        @{
            Version = '17.0.9'
            InstallationName = 'jdk-17'
            SoftwareId = '{7CD8D9DB-19F2-57B0-8F04-99DA5B3C62D4}'
        }

        @{
            Version = '17.0.10'
            InstallationName = 'jdk-17'
            SoftwareId = '{F1FB15A1-E909-592A-BC35-C68EA29D4785}'
        }

        @{
            Version = '17.0.11'
            InstallationName = 'jdk-17'
            SoftwareId = '{0FAEA8F8-E75C-579F-981F-093F0430FE97}'
        }

        @{
            Version = '17.0.12'
            InstallationName = 'jdk-17'
            SoftwareId = '{DA08718E-972A-58E7-AE7E-C45114C82E13}'
        }
    )
}

function Test-JavaInstallation {
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            '17', '17.0.1', '17.0.2', '17.0.3',
            '17.0.3.1', '17.0.4', '17.0.4.1', '17.0.5',
            '17.0.6', '17.0.7', '17.0.8', '17.0.9',
            '17.0.10', '17.0.11', '17.0.12'
        )]
        [string]$Version
    )

    $java = Get-JavaVersionInfo | Where-Object { $_.Version -eq $Version }
    $registryUninstallerKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{0}' -f $java.SoftwareId
    $uninstallerItem = Get-Item -Path $registryUninstallerKeyPath -ErrorAction SilentlyContinue
    return ($null -ne $uninstallerItem)
}

function Uninstall-OldJavaVersions {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$SystemDrive,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$TempDirectoryPath,

        [Parameter(Mandatory)]
        [ValidateSet(
            '17', '17.0.1', '17.0.2', '17.0.3',
            '17.0.3.1', '17.0.4', '17.0.4.1', '17.0.5',
            '17.0.6', '17.0.7', '17.0.8', '17.0.9',
            '17.0.10', '17.0.11', '17.0.12'
        )]
        [string]$NewVersion
    )

    $javaVersions = Get-JavaVersionInfo

    foreach ($java in $javaVersions) {
        if ($java.Version -ne $NewVersion) {
            Write-Verbose "Attempting to uninstall Java $($java.Version)..."

            $newJavaVersion = $javaVersions | Where-Object { $_.Version -eq $NewVersion }

            $installationPath = '{0}\Program Files\Java\{1}' -f $SystemDrive, $java.InstallationName
            $environmentVariablesPath = '{0}\Program Files\Java\{1}\bin' -f $SystemDrive, $java.InstallationName
            $registryInstallerKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Folders'
            $registryInstallerValue = '{0}\Program Files\Java\{1}\' -f $SystemDrive, $java.InstallationName
            $registryUninstallerKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{0}' -f $java.SoftwareId
            $registryJavasoftKeyPath = 'HKLM:\SOFTWARE\JavaSoft\JDK\{0}' -f $java.Version

            # Remove installation folder.
            $shouldRemoveInstallationFolder = (
                (Test-JavaInstallation -Version $java.Version) -and
                (-not (Test-JavaInstallation -Version $NewVersion) -or ($java.InstallationName -ne $newJavaVersion.InstallationName)) -and
                (Test-Path -Path $installationPath -PathType Container)
            )
            if ($shouldRemoveInstallationFolder) {
                Write-Verbose "Removing installation folder '$installationPath'."
                try {
                    Remove-Item -Path $installationPath -Recurse -Force
                    Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Removed installation folder '$installationPath'."
                }
                catch {
                    Write-Error "Failed to remove installation folder. $PSItem"
                    Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Failed to remove installation folder '$installationPath'."
                }
            }

            # Remove from PATH environment variable.
            $currentEnvironmentPathVariable = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') -split ';'
            $shouldRemoveEnvironmentPathVariable = (
                (Test-JavaInstallation -Version $java.Version) -and
                (-not (Test-JavaInstallation -Version $NewVersion) -or ($java.InstallationName -ne $newJavaVersion.InstallationName)) -and
                ($currentEnvironmentPathVariable -contains $environmentVariablesPath)
            )
            if ($shouldRemoveEnvironmentPathVariable) {
                Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Current environment PATH variable: $($currentEnvironmentPathVariable -join ';')"

                # Update the environment variable.
                if ($PSCmdlet.ShouldProcess('Environment PATH variable', 'Remove Java Path')) {
                    Write-Verbose "Removing Java binary path '$environmentVariablesPath' from environment PATH variable."
                    $newEnvironmentPathVariable = ($currentEnvironmentPathVariable | Where-Object { $_ -ne $environmentVariablesPath }) -join ';'
                    try {
                        [System.Environment]::SetEnvironmentVariable('PATH', $newEnvironmentPathVariable, 'Machine')
                        Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Removed '$environmentVariablesPath' from environment PATH variable."
                    }
                    catch {
                        Write-Error "Failed to remove environment PATH variable. $PSItem"
                        Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Failed to remove '$environmentVariablesPath' from environment PATH variable."
                    }
                }
            }

            # Remove installer registry value.
            $installerProperty = Get-ItemProperty -Path $registryInstallerKeyPath -Name $registryInstallerValue -ErrorAction SilentlyContinue
            $shouldRemoveInstallerRegistryValue = (
                (Test-JavaInstallation -Version $java.Version) -and
                (-not (Test-JavaInstallation -Version $NewVersion) -or ($java.InstallationName -ne $newJavaVersion.InstallationName)) -and
                ($null -ne $installerProperty)
            )
            if ($shouldRemoveInstallerRegistryValue) {
                Write-Verbose "Removing installer registry value '$registryInstallerValue' from key '$registryInstallerKeyPath'."
                try {
                    Remove-ItemProperty -Path $registryInstallerKeyPath -Name $registryInstallerValue
                    Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Removed installer registry value '$registryInstallerValue' from key '$registryInstallerKeyPath'."
                }
                catch {
                    Write-Error "Failed to remove installer registry value. $PSItem"
                    Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Failed to remove installer registry value '$registryInstallerValue' from key '$registryInstallerKeyPath'."
                }
            }

            # Delete uninstaller registry key.
            if ([string]::IsNullOrEmpty($java.SoftwareId) -eq $false) {
                $uninstallerItem = Get-Item -Path $registryUninstallerKeyPath -ErrorAction SilentlyContinue
                if ($null -ne $uninstallerItem) {
                    Write-Verbose "Removing uninstaller registry key '$registryUninstallerKeyPath'."
                    try {
                        Remove-Item -Path $registryUninstallerKeyPath -Recurse
                        Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Removed uninstaller registry key '$registryUninstallerKeyPath'."
                    }
                    catch {
                        Write-Error "Failed to remove uninstaller registry key. $PSItem"
                        Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Failed to remove uninstaller registry key '$registryUninstallerKeyPath'."
                    }
                }
            }

            # Delete JavaSoft registry key.
            $javasoftItem = Get-Item -Path $registryJavasoftKeyPath -ErrorAction SilentlyContinue
            if ($null -ne $javasoftItem) {
                Write-Verbose "Removing JavaSoft registry key '$registryJavasoftKeyPath'."
                try {
                    Remove-Item -Path $registryJavasoftKeyPath -Recurse
                    Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Removed JavaSoft registry key '$registryJavasoftKeyPath'."
                }
                catch {
                    Write-Error "Failed to remove JavaSoft registry key. $PSItem"
                    Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Failed to remove JavaSoft registry key '$registryJavasoftKeyPath'."
                }
            }
        }
    }
}

function Install-NewJavaVersion {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('17.0.12')]
        [string]$Version,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$TempDirectoryPath
    )

    Write-Verbose "Attempting to install Java $Version..."
    $newJavaVersions = @{
        '17.0.12' = @{
            DownloadUrl = 'https://download.oracle.com/java/17/archive/jdk-17.0.12_windows-x64_bin.msi'
            DestinationFilePath = Join-Path -Path $TempDirectoryPath -ChildPath 'jdk-17.0.12_windows-x64_bin.msi'
            SoftwareId = '{DA08718E-972A-58E7-AE7E-C45114C82E13}'
            FileHash = '1BBA48B74318F329899B92ED06773D97980722BE8C213923F79BCF1CBAF67316'
        }
    }

    if (-not (Test-Path -Path $TempDirectoryPath)) {
        Write-Verbose "Creating temp directory '$TempDirectoryPath'."
        New-Item -Path $TempDirectoryPath -ItemType Directory
    }

    $retryCountLeft = 6
    if (-not (Test-JavaInstallation -Version $Version)) {
        # Remove Java installer file it it's invalid/corrupt (file hash mismatch).
        if ((Test-Path -Path $newJavaVersions[$Version].DestinationFilePath) -and
            ((Get-FileHash -Path $newJavaVersions[$Version].DestinationFilePath).Hash -ne $newJavaVersions[$Version].FileHash)
        ) {
            Write-Verbose "File hash of Java installer '$($newJavaVersions[$Version].DestinationFilePath)' is invalid. Attempting to remove the file..."
            try {
                Remove-Item -Path $newJavaVersions[$Version].DestinationFilePath
                Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Removed invalid Java installer file '$($newJavaVersions[$Version].DestinationFilePath)'."
            }
            catch {
                Write-Error "Failed to remove invalid Java installer file. $PSItem"
                Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Failed to remove invalid Java installer file '$($newJavaVersions[$Version].DestinationFilePath)'."
            }
        }

        # Download Java installer if it doesn't already exist.
        if (-not (Test-Path -Path $newJavaVersions[$Version].DestinationFilePath)) {
            do {
                Write-Verbose "Downloading Java installer '$($newJavaVersions[$Version].DownloadUrl)'."
                try {
                    if ($PSCmdlet.ShouldProcess('Java installer', 'Download installer file')) {
                        $webClient = New-Object System.Net.WebClient
                        $webClient.DownloadFile($newJavaVersions[$Version].DownloadUrl, $newJavaVersions[$Version].DestinationFilePath)
                    }
                    else {
                        $retryCountLeft = 0
                    }
                    Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Downloaded Java installer to '$($newJavaVersions[$Version].DestinationFilePath)'."
                }
                catch {
                    Write-Error "Failed to download Java installer. $PSItem"
                    Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Failed to download Java installer from '$($newJavaVersions[$Version].DownloadUrl)'."
                }

                if (Test-Path -Path $newJavaVersions[$Version].DestinationFilePath) {
                    $retryCountLeft = 0
                }
                else {
                    if ($retryCountLeft -gt 0) {
                        Write-Warning 'Retrying download in 20 seconds...'
                        Start-Sleep -Seconds 20
                    }
                    else {
                        Out-LogFile -DirectoryPath $TempDirectoryPath -Content 'Java installer download has timed out.'
                        throw 'Java installer download has timed out.'
                    }
                    $retryCountLeft--
                }
            } while ($retryCountLeft -gt 0)
        }

        Write-Verbose "Installing Java $Version."
        if ($PSCmdlet.ShouldProcess('Java installation', 'Install Java')) {
            Start-Process -FilePath $newJavaVersions[$Version].DestinationFilePath -ArgumentList @('/qn /norestart') -Wait -ErrorAction SilentlyContinue
        }

        if (Test-JavaInstallation -Version $Version) {
            Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Installed Java $($Version)."

            # Remove the downloaded Java installer file (if it was successfully installed).
            if (Test-Path -Path $newJavaVersions[$Version].DestinationFilePath) {
                Write-Verbose "Removing Java installer file '$($newJavaVersions[$Version].DestinationFilePath)'."
                try {
                    Remove-Item -Path $newJavaVersions[$Version].DestinationFilePath
                    Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Removed Java installer file '$($newJavaVersions[$Version].DestinationFilePath)'."
                }
                catch {
                    Write-Error "Failed to remove Java installer file. $PSItem"
                    Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Failed to remove Java installer file '$($newJavaVersions[$Version].DestinationFilePath)'."
                }
            }
        }
        else {
            Write-Error "Failed to install Java. $PSItem"
            Out-LogFile -DirectoryPath $TempDirectoryPath -Content "Failed to install Java $($Version)."
        }
    }
    else {
        Write-Warning "Java $Version is already installed."
    }
}

$systemDrive = $env:SystemDrive
if ([string]::IsNullOrEmpty($systemDrive)) {
    $systemDrive = 'C:'
}

$tempDirectoryPath = Join-Path -Path $systemDrive -ChildPath 'Temp'

if (-not $PSBoundParameters.ContainsKey('SkipUninstallation')) {
    Uninstall-OldJavaVersions -SystemDrive $systemDrive -TempDirectoryPath $tempDirectoryPath -NewVersion $Version
}

Install-NewJavaVersion -Version $Version -TempDirectoryPath $tempDirectoryPath
