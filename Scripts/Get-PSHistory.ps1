<# 
.SYNOPSIS
Gets a list of executed commands from your terminal history.

.DESCRIPTION
This function shows a list of commands that you have previously executed in the terminal.

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
Get-PSHistory

Gets a list of command history from current session.

.EXAMPLE
Get-PSHistory -All

Gets a list of all saved PSReadLine command history.

.EXAMPLE
Get-PSHistory -All -ShowGridView

Show the command history as a grid view where you can select a command to copy it to clipboard.
#>
function Get-PSHistory {
    param(
        [switch]$All,

        [switch]$ShowGridView
    )

    begin {}

    process {
        if ($All) {
            # PSReadLine previous commands.
            $history = Get-Content -Path "$($env:APPDATA)\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" | Select-Object -Property @{ Name = 'Command'; Expression = { $_ } }
            if (($history | Measure-Object).Count -gt 1) {
                $history | ForEach-Object { $_ | Add-Member -Name 'Id' -MemberType NoteProperty -Value ($history.IndexOf($_) + 1) }
                [array]::Reverse($history)
            }

            if ($ShowGridView) {
                $selectedCommand = $history | Select-Object -Property Id, Command |
                    Out-GridView -Title 'PSReadLine command history -- Select a command and press OK to copy it to clipboard' -OutputMode Single
                
                if (($selectedCommand | Measure-Object).Count -gt 0) {
                    try {
                        Set-Clipboard -Value $selectedCommand.Command
                    }
                    catch {
                        Write-Error "Failed to copy command '$($selectedCommand.Command)'. $PSItem"
                    }
                }
            }
        }
        else {
            # Current session commands.
            $history = Get-History | Select-Object Id, @{ Name = 'Command'; Expression = { $_.CommandLine } }
            if (($history | Measure-Object).Count -gt 1) {
                [array]::Reverse($history)
            }

            if ($ShowGridView) {
                $selectedCommand = $history | Select-Object -Property Id, Command |
                    Out-GridView -Title 'Session command history -- Select a command and press OK to copy it to clipboard' -OutputMode Single

                if (($selectedCommand | Measure-Object).Count -gt 0) {
                    try {
                        Set-Clipboard -Value $selectedCommand.Command
                    }
                    catch {
                        Write-Error "Failed to copy command '$($selectedCommand.Command)'. $PSItem"
                    }
                }
            }
        }
    }

    end {
        if (-not $ShowGridView) {
            $history | Select-Object -Property Id, Command
        }
    }
}