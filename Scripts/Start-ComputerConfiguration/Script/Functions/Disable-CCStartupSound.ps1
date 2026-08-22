function Disable-CCStartupSound {
    Write-Verbose 'Disabling startup sound...'
    try {
        $params = @{
            Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
            Name = 'DisableStartupSound'
            Value = 0
            ErrorAction = 'Stop'
        }
        Set-ItemProperty @params
        Write-Output 'Disabled startup sound.'
    }
    catch {
        throw "Failed to disable startup sound. $PSItem"
    }
    
}