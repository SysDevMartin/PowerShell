function Test-CCSoftwareInstallation {
    param(
        [string]$InstallationPath
    )

    return (-not [string]::IsNullOrEmpty($InstallationPath)) -and (Test-Path -Path $InstallationPath)
}