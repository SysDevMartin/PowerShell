<# 
.SYNOPSIS
Publishes a custom PowerShell module to a repository.

.DESCRIPTION
This function takes the module name, root directory path and repository name, and creates a package for the custom PowerShell module in the specified repository.

.INPUTS
System.String
    You can pipe a string that contains the module name.

.OUTPUTS
None.

.EXAMPLE
Publish-PSDevModule -Name "MyModule" -Path "$env:USERPROFILE\PSDev\Modules" -Repository "MyRepository"
#>
function Publish-PSDevModule {
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
                Publish-Module -Path $sourcePath -Repository $Repository
            }
            catch {
                throw "Failed to publish module '$Name'. $PSItem"
            }
        }
        else {
            throw "Cannot find the directory '$sourcePath'."
        }
    }

    end {}
}