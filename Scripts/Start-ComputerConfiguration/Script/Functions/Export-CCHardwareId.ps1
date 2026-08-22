function Export-CCHardwareId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Path
    )

    Write-Output ('Exporting hardware ID...' -f $Path)

    Write-Verbose 'Installing "NuGet" package provider...'
    Install-PackageProvider -Name 'NuGet' -Scope CurrentUser -Force | Out-Null

    if ((Get-InstalledScript -Name 'Get-WindowsAutopilotInfo' -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
        Write-Verbose 'Installing hardware ID export script "Get-WindowsAutopilotInfo"...'
        Install-Script -Name 'Get-WindowsAutopilotInfo' -Scope CurrentUser -Force
    }

    try {
        Get-WindowsAutopilotInfo -OutputFile $Path -ErrorAction 'Stop'
        Write-Output ('Exported hardware ID to "{0}".' -f $Path)
    }
    catch {
        throw "Failed to export hardware ID file. $PSItem"
    }

    if ((Get-InstalledScript -Name 'Get-WindowsAutopilotInfo' -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
        Write-Verbose 'Uninstalling hardware ID export script "Get-WindowsAutopilotInfo"...'
        Uninstall-Script -Name 'Get-WindowsAutopilotInfo'
    }
}