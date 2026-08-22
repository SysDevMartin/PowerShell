<# 
.SYNOPSIS
Creates a new custom PowerShell module.

.DESCRIPTION
This function takes properties for a new module and creates it in the specified custom root module directory path.

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
New-PSDevModule -Name "MyNewModule" -Description "This is a description of the new module." -Author "My Name" -Path "$env:USERPROFILE\PSDev\Modules"
#>
function New-PSDevModule {
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
        $newModuleDirectoryPath = Join-Path -Path $Path -ChildPath $Name
        if (-not (Test-Path -Path $newModuleDirectoryPath)) {
            try {
                # Create root folder.
                New-Item -Path $newModuleDirectoryPath -ItemType Directory
    
                # Create development folder.
                $newDevDirectoryPath = Join-Path -Path $Path -ChildPath $Name -AdditionalChildPath 'Development'
                New-Item -Path $newDevDirectoryPath -ItemType Directory
                New-Item -Path (Join-Path -Path $newDevDirectoryPath -ChildPath 'Private') -ItemType Directory
                New-Item -Path (Join-Path -Path $newDevDirectoryPath -ChildPath 'Public') -ItemType Directory
                New-Item -Path (Join-Path -Path $newDevDirectoryPath -ChildPath 'Tests') -ItemType Directory
    
                # Create release folder.
                $newReleaseDirectoryPath = Join-Path -Path $Path -ChildPath $Name -AdditionalChildPath $Name
                New-Item -Path $newReleaseDirectoryPath -ItemType Directory
    
                # Create data folder.
                $newDataDirectoryPath = Join-Path -Path $Path -ChildPath $Name -AdditionalChildPath 'Data'
                New-Item -Path $newDataDirectoryPath -ItemType Directory
                New-Item -Path (Join-Path -Path $newDataDirectoryPath -ChildPath 'Development') -ItemType Directory
                New-Item -Path (Join-Path -Path $newDataDirectoryPath -ChildPath 'Production') -ItemType Directory
    
                # Create module file (psm1).
                $content = @'
foreach ($directoryName in @('Private', 'Public')) {
    $directoryPath = Join-Path -Path $PSScriptRoot -ChildPath $directoryName
    if (Test-Path -Path $directoryPath) {
        Get-ChildItem -Path (Join-Path -Path $directoryPath -ChildPath '*.ps1') | ForEach-Object { . $_.FullName }
    }
}
'@
                New-Item -Path (Join-Path -Path $newDevDirectoryPath -ChildPath "$($Name).psm1") -ItemType File -Value $content

                # Create example function file (ps1).
                $content = @'
function New-ExampleFunction {
<# 
.SYNOPSIS
Example function.

.DESCRIPTION
This function is an example function.

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
New-ExampleFunction
#>
    param()

    Write-Host "Hello world!"
}
'@
                New-Item -Path (Join-Path -Path $newDevDirectoryPath -ChildPath (Join-Path -Path 'Public' -ChildPath 'New-ExampleFunction.ps1')) -ItemType File -Value $content

                # Create example Pester test file.
                $content = @'
BeforeAll {
    $rootDirectoryPath = Split-Path -Path $PSScriptRoot -Parent
    . "$rootDirectoryPath\Public\New-ExampleFunction.ps1"
}

Describe 'New-ExampleFunction' {
    It 'Create new example function' {
        $example = New-ExampleFunction
        $example | Should -Exist
    }
}
'@
                New-Item -Path (Join-Path -Path $newDevDirectoryPath -ChildPath (Join-Path -Path 'Tests' -ChildPath 'New-ExampleFunction.Tests.ps1')) -ItemType File -Value $content
    
                # Create manifest file (psd1).
                $params = @{
                    Path = (Join-Path -Path $newDevDirectoryPath -ChildPath "$($Name).psd1")
                    RootModule = "$($Name).psm1"
                    Description = $Description
                    Author = $Author
                    CompanyName = 'Unspecified Company'
                    Copyright = '(c) Unspecified Company. All rights reserved.'
                    ModuleVersion = "$(Get-Date -Format 'yy.M').1"
                    AliasestoExport = @()
                    CmdletsToExport = @()
                    FunctionsToExport = @()
                    VariablesToExport = @()
                }
                New-ModuleManifest @params
            }
            catch {
                throw "Failed to create module. $($PSItem)"
            }
        }
        else {
            throw ('A module with the name "{0}" already exists.' -f $Name)
        }

        Set-Location -Path $newDevDirectoryPath
    }

    end {}
}