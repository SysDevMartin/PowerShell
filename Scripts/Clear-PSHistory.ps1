<# 
.SYNOPSIS
Clear executed commands from your terminal history.

.DESCRIPTION
This function clears previously executed commands from the current session and the commands that are stored in the PSReadLine history file.

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
Clear-PSHistory

Clear PSReadLine history file.

.EXAMPLE
Clear-PSHistory -Confirm $false

Clear PSReadLine history file without confirmation.
#>
function Clear-PSHistory {
    param(
        [ValidateNotNull()]
        [bool]$Confirm = $true
    )

    $PSReadLineHistoryFilePath = "$($env:APPDATA)\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    Clear-Content -Path $PSReadLineHistoryFilePath -Confirm:$Confirm
}