<# 
.SYNOPSIS
Exports a new version of a custom PowerShell script.

.DESCRIPTION
This function takes the path to a PowerShell script in development and makes a copy of it in its release folder.

.INPUTS
System.String
    You can pipe a string that contains a script path.

.OUTPUTS
None.

.EXAMPLE
Export-PSDevScript -Name "MyScript" -Path "$env:USERPROFILE\PSDev\Scripts"

Export a new script version.

.EXAMPLE
Export-PSDevScript -Name "MyScript" -Path "$env:USERPROFILE\PSDev\Scripts" -SkipVersionCheck

Export a new script version without checking if current version matches the current month.
#>
function Export-PSDevScript {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Container) { return $true }
            else { throw [System.IO.DirectoryNotFoundException] ('Cannot find the directory "{0}".' -f $_) }
        })]
        [string]$Path,

        [switch]$SkipVersionCheck
    )

    begin {
        $ignoreItems = @('.git', 'Tests')
    }

    process {
        try {
            $sourceFullPath = Join-Path -Path (Join-Path -Path $Path -ChildPath $Name) -ChildPath 'Development'
            $sourceDirectory = Get-Item -Path $sourceFullPath
        }
        catch {
            throw "Failed to get directories. $($PSItem)"
        }
    
        # Get script version.
        try {
            $sourceItems = Get-ChildItem -Path $sourceDirectory.FullName
            $sourceScriptFilePath = Join-Path -Path $sourceDirectory.FullName -ChildPath "$($Name).ps1"
            $scriptContent = [string](Get-Content -Path $sourceScriptFilePath)
            if ($scriptContent -match "\.VERSION (\d+\.\d+\.\d+)") {
                $scriptVersion = $Matches[1]
            }
            else {
                throw 'Invalid script version.'
            }
        }
        catch {
            throw "Failed to get source file/directories or script version. $($PSItem)"
        }
    
        # Check if script version is same as current month.
        if (-not $SkipVersionCheck) {
            if ($scriptVersion -match '\d+\.(\d+)\.\d+') {
                $month = $Matches.1
                if ($month -ne (Get-Date).Month) {
                    throw 'Script version month is not current month.'
                }
            }
            else {
                throw "Invalid script version format '$($moduleVersion)'."
            }
        }
    
        # Copy the development version to a new directory.
        try {
            $newVersionDestinationPath = Join-Path -Path $Path -ChildPath (Join-Path -Path $Name -ChildPath $Name) -AdditionalChildPath $scriptVersion
            if (!(Test-Path -Path $newVersionDestinationPath)) {
                New-Item -Path $newVersionDestinationPath -ItemType Directory
            }
            else {
                throw "Version $($scriptVersion) already exists in the development directory."
            }
            $sourceItems | Where-Object { $_.Name -notin $ignoreItems } | Copy-Item -Destination $newVersionDestinationPath -Recurse
        }
        catch {
            throw "Failed to copy version $($scriptVersion) to development directory '$($newVersionDestinationPath)'. $($PSItem)"
        }
    }

    end {}
}