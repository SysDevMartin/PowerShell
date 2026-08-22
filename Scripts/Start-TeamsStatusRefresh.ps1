function Start-TeamsStatusRefresh {
    $previousWindowTitle = $Host.UI.RawUI.WindowTitle
    while ($true) {
        try {
            Get-Process -Name 'ms-teams' -ErrorAction Stop | Out-Null
            $Host.UI.RawUI.WindowTitle = "Teams is running"
            $wshell = New-Object -ComObject wscript.shell
            $wshell.SendKeys("{NUMLOCK}{NUMLOCK}")
            Write-Host ('[{0}] Microsoft Teams is running. Pressed NUMLOCK twice and waiting for 60 seconds...' -f (Get-Date)) -ForegroundColor Green
            Start-Sleep -Seconds 60
        }
        catch {
            $Host.UI.RawUI.WindowTitle = "Teams is not running"
            Write-Warning ('[{0}] Microsoft Teams is not running. Waiting for 15 seconds...' -f (Get-Date))
            Start-Sleep -Seconds 15
        }
        finally {
            $Host.UI.RawUI.WindowTitle = $previousWindowTitle
        }
    }
}