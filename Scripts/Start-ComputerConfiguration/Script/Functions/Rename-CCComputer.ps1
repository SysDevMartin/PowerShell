function Rename-CCComputer {
    param(
        [switch]$SkipCaseValidation
    )

    Write-Host "Current computer name: $env:COMPUTERNAME" -ForegroundColor Yellow
    $newComputerName = (Read-Host 'Enter new computer name (or leave blank to keep current name)').Trim()

    if ((-not $SkipCaseValidation) -and ($newComputerName -cmatch '[a-z]')) {
        Write-Warning ('The name "{0}" contains lower-case letters.' -f $newComputerName)
        Read-Host 'Press <Enter> to continue with this name or <Ctrl+C> to cancel'
    }

    if (($env:COMPUTERNAME -ne $newComputerName) -and (-not [string]::IsNullOrWhitespace($newComputerName))) {
        Write-Verbose 'Renaming computer...'
        Rename-Computer -NewName $newComputerName -Restart -Confirm -ErrorAction 'Stop'
    }
}