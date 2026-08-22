<#PSScriptInfo

.VERSION 1.0.0

.GUID fef610d6-ddc9-4373-954c-3183a66bbf12

.AUTHOR Martin Olsson

.COMPANYNAME Martin Olsson

.COPYRIGHT (c) Martin Olsson. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION
Backup files on your workstation.

.EXAMPLE
BackupWorkstationFiles-Config.psd1:
@{
    # Clear files and folders.
    ClearRecycleBin = $false
    ClearDownloadsFolder = $false

    # Copy files.
    CopyFiles = @{
        Jobs = @(
            # Excel files
            @{
                Name = 'Excel files'
                Source = @{
                    Path = 'C:\Users\Username\Excel files'
                    Filter = '*.xlsx'
                    DeleteAfterCopy = $false
                }
                Destination = @{
                    Path = 'C:\Users\Username\Backup\Excel files'
                    TimestampFormat = '_yyyy-MM-dd_HHmmss'
                }
                Enabled = $false
            }

            # Log files
            @{
                Name = 'Log files'
                Source = @{
                    Path = 'C:\Users\Username\Log files'
                    Filter = '*.log'
                    DeleteAfterCopy = $true
                }
                Destination = @{
                    Path = 'C:\Users\Username\Backup\Log files'
                    TimestampFormat = ''
                }
                Enabled = $false
            }
        )
    }

    # Copy files from a remote host.
    CopyRemoteFiles = @{
        Jobs = @(
            # Server database A
            @{
                Name = 'Server database A'
                Connection = @{
                    Host = '10.0.0.10'
                    Username = 'user'
                    ConnectionFile = 'C:\Users\Username\.ssh\id_rsa_server_a'
                }
                Source = @{
                    Path = '/volume1/backup/'
                    Filter = 'database_*.tar.gz'
                }
                Destination = @{
                    Path = 'C:\Users\Username\Backup\ServerDatabaseA'
                }
                Enabled = $false
            }

            # Server database B
            @{
                Name = 'Server database B'
                Connection = @{
                    Host = '10.0.0.20'
                    Username = 'user'
                    ConnectionFile = 'C:\Users\Username\.ssh\id_rsa_server_b'
                }
                Source = @{
                    Path = '/volume1/backup/'
                    Filter = 'database_*.tar.gz'
                }
                Destination = @{
                    Path = 'C:\Users\Username\Backup\ServerDatabaseB'
                }
                Enabled = $false
            }
        )
    }

    # Delete old files.
    DeleteOldFiles = @{
        Jobs = @(
            # Old log files
            @{
                Name = 'Old log files'
                Source = @{
                    Path = 'C:\Users\Username\Old log files'
                    Filter = '*.log'
                    KeepFiles = 10
                }
                Enabled = $false
            }

            # Old PDF files
            @{
                Name = 'Old PDF files'
                Source = @{
                    Path = 'C:\Users\Username\Old PDF files'
                    Filter = '*.pdf'
                    KeepFiles = 15
                }
                Enabled = $false
            }
        )
    }

    # Copy directories.
    CopyDirectories = @{
        Jobs = @(
            # General files
            @{
                Name = 'General files'
                Source = @{
                    Path = 'C:\Users\Username\Documents\General files'
                    AllowEmptySource = $false
                }
                Destination = @{
                    Path = 'C:\Users\Username\Backup\General files'
                    PurgeExtraFiles = $true
                }
                Enabled = $false
            }

            # Important files
            @{
                Name = 'Important files'
                Source = @{
                    Path = 'C:\Users\Username\Documents\Important files'
                    AllowEmptySource = $false
                }
                Destination = @{
                    Path = 'C:\Users\Username\Backup\Important files'
                    PurgeExtraFiles = $true
                }
                Enabled = $false
            }
        )
    }

    # Copy directories to an attached drive.
    CopyDirectoriesToDrive = @{
        Verification = @{
            DriveName = 'BACKUP'
            FilePath = 'DriveVerification.txt'
            FileContent = 'ABCdef123456'
        }
        Jobs = @(
            # General files
            @{
                Name = 'General files'
                Source = @{
                    Path = 'C:\Users\Username\Documents\General files'
                    AllowEmptySource = $false
                }
                Destination = @{
                    SubPath = 'Backup\General files'
                    PurgeExtraFiles = $true
                }
                Enabled = $false
            }

            # Important files
            @{
                Name = 'Important files'
                Source = @{
                    Path = 'C:\Users\Username\Documents\Important files'
                    AllowEmptySource = $false
                }
                Destination = @{
                    SubPath = 'Backup\Important files'
                    PurgeExtraFiles = $true
                }
                Enabled = $false
            }
        )
    }
}

Example configuration file.
#>
param(
    [Parameter(Mandatory)]
    [ValidateScript({
            if (Test-Path -Path $_ -PathType Leaf) { return $true }
            else { throw [System.IO.FileNotFoundException] "Cannot find the file '$_'." }
        })]
    [string]$ConfigurationPath
)

#region Functions

function Clear-ScriptDirectory {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
                if ((Test-Path -Path $_ -PathType Container) -eq $true) { return $true }
                else { throw 'Unable to find the directory.' }
            })]
        [string]$Path
    )

    $deletedItems = 0

    # Delete files.
    $files = Get-ChildItem $Path -File
    foreach ($file in $files) {
        try {
            Remove-Item -Path $file -ErrorAction SilentlyContinue
            $deletedItems++
        }
        catch {
            Write-Host "Failed to delete file: $($file.FullName)"
            Write-Host $PSItem
        }
    }

    # Delete directories.
    $directories = Get-ChildItem -Path $Path -Directory
    foreach ($dir in $directories) {
        try {
            Remove-Item -Path $dir -Recurse -ErrorAction SilentlyContinue
            $deletedItems++
        }
        catch {
            Write-Host "Failed to delete directory: $($dir.FullName)"
            Write-Host $PSItem
        }
    }

    return $deletedItems
}

function Copy-ScriptDirectory {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [bool]$AllowEmptySource = $false,

        [bool]$PurgeExtraFiles = $false
    )

    $isCommandExecuted = $false

    if ((Test-Path $Source) -eq $true) {
        if ((Test-Path $Destination) -eq $true) {
            $totalSourceFileSize = 0

            # Calculate total file size.
            if ($AllowEmptySource -eq $false) {
                foreach ($file in Get-ChildItem -Path $Source -Recurse) {
                    $totalSourceFileSize += ($file | Measure-Object -Property Length -Sum).Sum
                }
            }

            if (($AllowEmptySource -eq $true) -or ($totalSourceFileSize -gt 0)) {
                $commandString = $null

                if ($PurgeExtraFiles -eq $true) {
                    # Mirror sync files (delete missing source files from destination).
                    $commandString = 'robocopy "{0}" "{1}" /mir /r:2 /w:5' -f $Source, $Destination
                }
                else {
                    # Copy files (don't delete any files at destination).
                    $commandString = 'robocopy "{0}" "{1}" /e /r:2 /w:5' -f $Source, $Destination
                }

                if ($null -ne $commandString) {
                    try {
                        cmd.exe /c $commandString | Out-Null
                        $isCommandExecuted = $true
                    }
                    catch {
                        Write-Error "Failed to copy directory: $PSItem"
                    }
                }
                else {
                    Write-Error 'Invalid command string.'
                }
            }
            else {
                Write-Warning "Empty source: $($Source)"
            }
        }
        else {
            Write-Error "Invalid destination: $($Destination)"
        }
    }
    else {
        Write-Error "Invalid source: $($Source)"
    }

    return $isCommandExecuted
}

function Copy-ScriptFile {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [ValidateNotNullOrEmpty()]
        [string]$Filter = '*',

        [ValidateNotNull()]
        [bool]$DeleteAfterCopy = $false,

        [ValidateNotNull()]
        [string]$TimestampFormat = ''
    )

    $copiedFiles = 0
    $files = Get-ChildItem -Path $Source -Filter $Filter -File

    foreach ($file in $files) {
        $destFilename = $file.Name

        # Append timestamp to filename.
        if ($TimestampFormat.Length -gt 0) {
            $time = $file.LastWriteTime
            $timestamp = $time.ToString($TimestampFormat)
            $filename = $file.BaseName
            $extension = $file.Extension
            $destFilename = '{0}{1}{2}' -f $filename, $timestamp, $extension
        }

        # Get destination paths.
        $destFilePath = Join-Path -Path $Destination -ChildPath $destFilename
        $destDirPath = Split-Path -Path $destFilePath -Parent
        $destDirExists = Test-Path -Path $destDirPath

        if ($destDirExists -eq $true) {
            try {
                # Copy source file to destination.
                Copy-Item -Path $file -Destination $destFilePath -ErrorAction SilentlyContinue
                $copiedFiles++

                # Delete source file.
                if ($DeleteAfterCopy -eq $true) {
                    try {
                        Remove-Item -Path $file -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Host "Failed to delete source file: $($file.FullName)" -ForegroundColor Red
                        Write-Host $PSItem
                    }
                }
            }
            catch {
                Write-Host "Failed to copy file: $($file.FullName)" -ForegroundColor Red
                Write-Host $PSItem
            }
        }
        else {
            Write-Host "Invalid destination directory: $($destDirPath)" -ForegroundColor Red
        }
    }

    return $copiedFiles
}

function Copy-ScriptRemoteFile {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Hostname,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [string]$Filter = '*',

        [string]$ConnectionFile = ''
    )

    $isCommandExecuted = $false
    $commandString = $null

    if ($ConnectionFile.Length -gt 0) {
        # Use a specific connection profile.
        $commandString = 'scp -i "{0}" {1}@{2}:"{3}{4}" "{5}"' -f $ConnectionFile, $Username, $Hostname, $Source, $Filter, $Destination
    }
    else {
        # Use the default connection profile.
        $commandString = 'scp {0}@{1}:"{2}{3}" "{4}"' -f $Username, $Hostname, $Source, $Filter, $Destination
    }

    if ($null -ne $commandString) {
        try {
            cmd.exe /c $commandString | Out-Null
            $isCommandExecuted = $true
        }
        catch {
            Write-Host 'Failed to copy remote files.' -ForegroundColor Red
            Write-Host $PSItem
        }
    }
    else {
        Write-Host 'Invalid command string.' -ForegroundColor Red
    }

    return $isCommandExecuted
}

function Get-ScriptAttachedDrive {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Label,

        [ValidateNotNullOrEmpty()]
        [string[]]$IncludeType = @('Fixed', 'Removable'),

        [ValidateNotNullOrEmpty()]
        [string[]]$ExcludeLetter = @('C')
    )

    $drive = $null

    try {
        # Get the drive.
        $drive = Get-Volume | Where-Object -FilterScript {
            ($IncludeType -contains $_.DriveType) -and
            ($ExcludeLetter -notcontains $_.DriveLetter) -and
            ($_.FileSystemLabel -ceq $Label)
        }

        # Confirm that exactly one drive was found.
        if ($drive.Count -ne 1) {
            $drive = $null
        }
    }
    catch {
        Write-Error "Cannot find a valid drive with the label '$($Label)'. $($PSItem)"
    }

    return $drive
}

function Remove-ScriptOldFile {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Filter,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]$KeepFiles
    )

    $deletedFiles = 0

    # Delete files in destination that exceed the limit (oldest first).
    if ((Test-Path -Path $Path) -eq $true) {
        $files = Get-ChildItem -Path $Path -Filter $Filter -File | Sort-Object -Property LastWriteTime
        $exceedingFiles = $files.Count - $KeepFiles
        if ($exceedingFiles -gt 0) {
            for ($i = 0; $i -lt $exceedingFiles; $i++) {
                try {
                    Remove-Item -Path $files[$i] -ErrorAction SilentlyContinue
                    $deletedFiles++
                }
                catch {
                    Write-Host "Failed to delete file: $($files[$i])" -ForegroundColor Red
                    Write-Host $PSItem
                }
            }
        }
    }
    else {
        Write-Host "Invalid path: $($Path)" -ForegroundColor Red
    }

    return $deletedFiles
}

#endregion

$Config = Import-PowerShellDataFile -Path $ConfigurationPath -ErrorAction Stop

# Copy files from local source to local destination.
if ($null -ne $Config.CopyFiles.Jobs) {
    Write-Host '--- Copy files ---' -ForegroundColor Cyan
    foreach ($job in $Config.CopyFiles.Jobs) {
        if ($job.Enabled) {
            Write-Host "`n$($job.Name)" -ForegroundColor DarkCyan
            $params = @{
                Source          = $job.Source.Path
                Destination     = $job.Destination.Path
                Filter          = $job.Source.Filter
                DeleteAfterCopy = $job.Source.DeleteAfterCopy
                TimestampFormat = $job.Destination.TimestampFormat
            }
            $copiedFiles = Copy-ScriptFile @params
            Write-Host "Copied $($copiedFiles) file(s)."
        }
    }
}

# Copy files from server.
if ($null -ne $Config.CopyRemoteFiles.Jobs) {
    Write-Host
    Write-Host '--- Copy remote files ---' -ForegroundColor Cyan
    foreach ($job in $Config.CopyRemoteFiles.Jobs) {
        if ($job.Enabled) {
            Write-Host "`n$($job.Name)" -ForegroundColor DarkCyan
            $params = @{
                Hostname       = $job.Connection.Host
                Username       = $job.Connection.Username
                Source         = $job.Source.Path
                Destination    = $job.Destination.Path
                Filter         = $job.Source.Filter
                ConnectionFile = $job.Connection.ConnectionFile
            }
            $isFileCopied = Copy-ScriptRemoteFile @params
            if ($isFileCopied) {
                Write-Host 'Copied remote files.' 
            }
        }
    }
}

# Delete old local files.
if ($null -ne $Config.DeleteOldFiles.Jobs) {
    Write-Host
    Write-Host '--- Delete old files ---' -ForegroundColor Cyan
    foreach ($job in $Config.DeleteOldFiles.Jobs) {
        if ($job.Enabled) {
            Write-Host "`n$($job.Name)" -ForegroundColor DarkCyan
            $params = @{
                Path      = $job.Source.Path
                Filter    = $job.Source.Filter
                KeepFiles = $job.Source.KeepFiles
            }
            $deletedFiles = Remove-ScriptOldFile @params
            Write-Host "Deleted $($deletedFiles) old file(s)."
        }
    }
}

# Copy directories.
if ($null -ne $Config.CopyDirectories.Jobs) {
    Write-Host
    Write-Host '--- Copy directories ---' -ForegroundColor Cyan
    foreach ($job in $Config.CopyDirectories.Jobs) {
        if ($job.Enabled) {
            Write-Host "`n$($job.Name)" -ForegroundColor DarkCyan
            $params = @{
                Source           = $job.Source.Path
                Destination      = $job.Destination.Path
                AllowEmptySource = $job.Source.AllowEmptySource
                PurgeExtraFiles  = $job.Destination.PurgeExtraFiles
            }
            $isDirectoryCopied = Copy-ScriptDirectory @params
            if ($isDirectoryCopied) {
                Write-Host 'Copied directory.'
            }
        }
    }
}

# Copy directories to removable drive.
if ($null -ne $Config.CopyDirectoriesToDrive.Jobs) {
    Write-Host
    Write-Host '--- Copy directories to removable drive ---' -ForegroundColor Cyan
    $drive = Get-ScriptAttachedDrive -Label $Config.CopyDirectoriesToDrive.Verification.DriveName

    if ($null -ne $drive) {
        foreach ($job in $Config.CopyDirectoriesToDrive.Jobs) {
            if ($job.Enabled) {
                Write-Host "`n$($job.Name) [$($drive.DriveLetter):\]" -ForegroundColor DarkCyan

                $params = @{
                    Path      = "$($drive.DriveLetter):\"
                    ChildPath = $Config.CopyDirectoriesToDrive.Verification.FilePath
                }
                $path = Join-Path @params
                $verificationFileExists = Test-Path -Path $path

                if ($verificationFileExists) {
                    $verificationFileContent = Get-Content -Path $path
                    $requiredVerificationFileContent = $Config.CopyDirectoriesToDrive.Verification.FileContent
                    $isCodeValid = $verificationFileContent -ceq $requiredVerificationFileContent
                
                    if ($isCodeValid) {
                        $destPath = (Join-Path -Path "$($drive.DriveLetter):\" -ChildPath $job.Destination.SubPath)
                        $params = @{
                            Source           = $job.Source.Path
                            Destination      = $destPath
                            AllowEmptySource = $job.Source.AllowEmptySource
                            PurgeExtraFiles  = $job.Destination.PurgeExtraFiles
                        }
                        $isDirectoryCopied = Copy-ScriptDirectory @params
                        if ($isDirectoryCopied) {
                            Write-Host 'Copied directory.'
                        }
                    }
                    else {
                        Write-Error 'Invalid verification file content.' 
                    }
                }
                else {
                    Write-Error 'Unable to find the verification file.' 
                }
            }
        }
    }
    else {
        Write-Warning 'No valid drive attached.'
    }
}

# Clean-up temporary files.
Write-Host
Write-Host '--- Temp files ---' -ForegroundColor Cyan

# Clear downloads folder.
if ($Config.ClearDownloadsFolder) {
    Write-Host "`nDownloads folder" -ForegroundColor DarkCyan
    $downloadsPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
    $deletedItems = Clear-ScriptDirectory -Path $downloadsPath
    Write-Host "Deleted $($deletedItems) items(s)."
}

# Clear recycle bin.
if ($Config.ClearRecycleBin) {
    Write-Host "`nRecycle bin" -ForegroundColor DarkCyan
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Host 'Cleared recycle bin.'
    }
    catch {
        Write-Error "Failed to clear recycle bin. $($PSItem)"
    }
}

# Show "backup finished" notification.
if ((Get-Command -Name 'New-BurntToastNotification' -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
    New-BurntToastNotification -Text 'Backup workstation files', 'Backup finished'
}