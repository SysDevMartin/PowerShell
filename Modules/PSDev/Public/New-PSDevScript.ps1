<# 
.SYNOPSIS
Creates a new custom PowerShell script.

.DESCRIPTION
This function takes properties for a new script and creates it in the specified custom root script directory path.

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
New-PSDevScript -Name "MyNewScript" -Description "This is a description of the new script." -Author "My Name" -Path "$env:USERPROFILE\PSDev\Scripts"
#>
function New-PSDevScript {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Description,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Author,

        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Container) { return $true }
            else { throw [System.IO.DirectoryNotFoundException] ('Cannot find the directory "{0}".' -f $_) }
        })]
        [string]$Path
    )

    begin {}

    process {
        $newScriptDirectoryPath = Join-Path -Path $Path -ChildPath $Name
        if (-not (Test-Path -Path $newScriptDirectoryPath)) {
            try {
                # Create root folder.
                New-Item -Path $newScriptDirectoryPath -ItemType Directory
    
                # Create development folder.
                $newScriptDevDirectoryPath = Join-Path -Path $newScriptDirectoryPath -ChildPath 'Development'
                New-Item -Path $newScriptDevDirectoryPath -ItemType Directory
    
                # Create release folder.
                $newReleaseDirectoryPath = Join-Path -Path $Path -ChildPath $Name -AdditionalChildPath $Name
                New-Item -Path $newReleaseDirectoryPath -ItemType Directory
    
                # Create data folder and sub-folders.
                $newDataDirectoryPath = Join-Path -Path $Path -ChildPath $Name -AdditionalChildPath 'Data'
                New-Item -Path $newDataDirectoryPath -ItemType Directory
                New-Item -Path (Join-Path -Path $newDataDirectoryPath -ChildPath 'Development') -ItemType Directory
                New-Item -Path (Join-Path -Path $newDataDirectoryPath -ChildPath 'Production') -ItemType Directory
    
                # Create script file (ps1).
                $params = @{
                    Path = (Join-Path -Path $newScriptDevDirectoryPath -ChildPath "$($Name).ps1")
                    Description = $Description
                    Author = $Author
                    CompanyName = 'Unspecified Company'
                    Copyright = '(c) Unspecified Company. All rights reserved.'
                    Version = "$(Get-Date -Format 'yy.M').1"
                }
                New-ScriptFileInfo @params
    
                # Update script file content.
                $scriptTemplate = @'
param()
'@
                $scriptContent = Get-Content -Path $params.path
                if ($scriptContent.StartsWith("`n")) {
                    $scriptContent = $scriptContent | Select-Object -Skip 1
                }
                $newScriptContent = $scriptContent.Replace('Param()', $scriptTemplate)
                Set-Content -Path $params.Path -Value $newScriptContent
            }
            catch {
                throw "Failed to create script. $($PSItem)"
            }
        }
        else {
            throw ('A script with the name "{0}" already exists.' -f $Name)
        }

        Set-Location -Path $newScriptDevDirectoryPath
    }

    end {}
}