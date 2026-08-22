<# 
.SYNOPSIS
Run automated tests for a custom PowerShell module.

.DESCRIPTION
This function takes the name of a custom PowerShell module and the path to the root custom module directory, and runs automated tests for the module.

.INPUTS
This function takes a string that contains the module name.

.OUTPUTS
None.

.EXAMPLE
Invoke-PSDevModulePesterTest -Name 'MyModule' -Path "$env:USERPROFILE\PSDevModules"
#>
function Invoke-PSDevModulePesterTest {
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

        [ValidateSet('None', 'Normal', 'Minimal', 'Detailed', 'Diagnostic')]
        [string]$Output = 'Normal',

        [switch]$PassThru
    )

    $testDirectoryPath = Join-Path -Path (Join-Path -Path $Path -ChildPath $Name) -ChildPath (Join-Path -Path 'Development' -ChildPath 'Tests')
    Invoke-Pester -Path "$testDirectoryPath\*.ps1" -Output $Output -PassThru:$PassThru
}