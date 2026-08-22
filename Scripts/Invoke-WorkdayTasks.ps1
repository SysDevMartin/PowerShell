function Invoke-WorkdayTasks {
    param([switch]$Force)

    # Only run the code in Windows Terminal.
    if ($env:WT_SESSION) {
        $lastWorkdayTime = $null
        $now = Get-Date

        # Get path to last workday file.
        $localAppDataPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
        $powershellProfileDirectoryPath = Join-Path -Path $localAppDataPath -ChildPath 'PowerShell' -AdditionalChildPath 'Profile'
        $lastWorkdayTimeFilePath = Join-Path -Path $powershellProfileDirectoryPath -ChildPath 'LastWorkdayTime.txt'

        # Get last workday time.
        if (Test-Path -Path $lastWorkdayTimeFilePath -PathType Leaf) {
            $lastWorkdayTimeFileContent = Get-Content -Path $lastWorkdayTimeFilePath
            if (-not [string]::IsNullOrWhiteSpace($lastWorkdayTimeFileContent)) {
                $lastWorkdayTime = Get-Date $lastWorkdayTimeFileContent
            }
        }

        # Run the following code once a day.
        if (($lastWorkdayTime.Date -lt $now.Date) -or $Force) {
            # Update timestamp in last workday file.
            (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Out-File -FilePath $lastWorkdayTimeFilePath

            # Check PS script execution policy.
            $currentScriptExecutionPolicy = Get-ExecutionPolicy
            if ($currentScriptExecutionPolicy -ne 'RemoteSigned') {
                Write-Warning ('Execution policy is "{0}" but should be "RemoteSigned".' -f $currentScriptExecutionPolicy)
            }

            # Check PSGallery repository installation policy.
            $currentRepositoryInstallationPolicy = (Get-PSRepository -Name 'PSGallery').InstallationPolicy
            if ($currentRepositoryInstallationPolicy -ne 'Untrusted') {
                Write-Warning ('Installation policy for PSGallery is "{0}" but should be "Untrusted".' -f $currentRepositoryInstallationPolicy)
            }

            # Clean up old download files.
            Write-Host 'Cleaning up old files from the Downloads folder...'
            $downloadedFilesRetentionDays = 7
            $downloadDirectoryPath = Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads'
            Get-ChildItem -Path $downloadDirectoryPath | ForEach-Object {
                if ($_.LastWriteTime.Date -lt (Get-Date).Date.AddDays(-($downloadedFilesRetentionDays))) {
                    $_ | Remove-Item -Recurse
                }
            }

            # Wait for web browser.
            [ScriptBlock]$waitForBrowser = {
                (Get-Process -Name 'msedge' | Where-Object { $_.MainWindowHandle -gt 0 } | Measure-Object).Count -eq 0
            }
            if (Invoke-Command -ScriptBlock $waitForBrowser) {
                Write-Host 'Waiting for Microsoft Edge...'
                do { Start-Sleep -Seconds 5 }
                while (Invoke-Command -ScriptBlock $waitForBrowser)
            }

            # Connect to Exchange Online.
            Write-Host 'Connecting to Exchange Online...'
            Connect-ExchangeOnline -UserPrincipalName 'myuser@mydomain.com' -ShowBanner:$false

            switch ($now.DayOfWeek) {
                'Friday' {
                    # Export a list of installed PowerShell modules.
                    (Get-InstalledModule |
                        Select-Object Name, Version, Repository, InstalledDate |
                        Sort-Object Name |
                        Format-Table -AutoSize |
                        Out-String -Width 4096).Trim() |
                        Out-File -Path ('{0}\Installed PowerShell modules ({1}).txt' -f "$env:USERPROFILE\Documents", $env:COMPUTERNAME)
                    
                    # Export a list of installed VS Code extensions.
                    code --list-extensions | Out-File -Path ('{0}\Installed VS Code extensions ({1}).txt' -f "$env:USERPROFILE\Documents", $env:COMPUTERNAME)
                }
            }
        }
    }
}