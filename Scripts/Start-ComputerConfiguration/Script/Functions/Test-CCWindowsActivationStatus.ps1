function Test-CCWindowsActivationStatus {
    [CmdletBinding()]
    param()

    begin {
        Write-Verbose 'Checking if Windows is activated...'
    }

    process {
        $activationStatus = Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%'" -Verbose:$false |
            Where-Object { $_.PartialProductKey } |
            Select-Object -Property Description, LicenseStatus
        
        $isWindowsLicenseActivated = ($null -ne $activationStatus) -and ($activationStatus.LicenseStatus -eq 1)
    }
    
    end {
        return $isWindowsLicenseActivated
    }
}