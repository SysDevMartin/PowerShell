function Add-CCWifiProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Path
    )

    Write-Verbose 'Adding wifi profile...'

    try {
        Invoke-Expression ('netsh wlan add profile filename="{0}"' -f $Path) -ErrorAction 'Stop'
    }
    catch {
        throw "Failed to add wifi profile. $PSItem"
    }
}