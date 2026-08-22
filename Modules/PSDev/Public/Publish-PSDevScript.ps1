<# 
.SYNOPSIS
Publishes a custom PowerShell script to a repository.

.DESCRIPTION
This function takes the script name, root directory path and repository name, and creates a package for the custom PowerShell script in the specified repository.

.INPUTS
System.String
    You can pipe a string that contains the script name.

.OUTPUTS
None.

.EXAMPLE
Publish-PSDevScript -Name "MyScript" -Path "$env:USERPROFILE\PSDev\Scripts" -Repository "MyRepository"
#>
function Publish-PSDevScript {
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

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Repository
    )

    begin {}

    process {
        $version = Get-PSDevLatestReleasedDevVersion -Path (Join-Path -Path $Path -ChildPath $Name)
        $sourcePath = Join-Path -Path $Path -ChildPath (Join-Path -Path $Name -ChildPath $Name -AdditionalChildPath $version.FullVersion)
        if (Test-Path -Path $sourcePath -PathType Container) {
            try {
                Publish-Script -Path (Join-Path -Path $sourcePath -ChildPath "$($Name).ps1") -Repository $Repository
            }
            catch {
                throw "Failed to publish script '$Name'. $PSItem"
            }
        }
        else {
            throw "Cannot find the directory '$sourcePath'."
        }
    }

    end {}
}