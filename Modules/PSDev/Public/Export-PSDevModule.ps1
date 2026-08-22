<# 
.SYNOPSIS
Exports a new version of a custom PowerShell module.

.DESCRIPTION
This function takes the path to a PowerShell module in development and makes a copy of it in its release folder.

.INPUTS
System.String
    You can pipe a string that contains a module path.

.OUTPUTS
None.

.EXAMPLE
Export-PSDevModule -Name "MyModule" -Path "$env:USERPROFILE\PSDev\Modules"

Export a new module version.

.EXAMPLE
Export-PSDevModule -Name "MyModule" -Path "$env:USERPROFILE\PSDev\Modules" -SkipVersionCheck -SkipFunctionExportCheck -SkipTests

Export a new module version without checking if current version matches the current month, without checking if the function exists in the module manifest list of exported functions, and without running Pester tests.
#>
function Export-PSDevModule {
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

        [switch]$SkipVersionCheck,

        [switch]$SkipFunctionExportCheck,

        [switch]$SkipTests
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
    
        # Get module version.
        try {
            $sourceItems = Get-ChildItem -Path $sourceDirectory.FullName
            $sourceManifestFilePath = Join-Path -Path $sourceDirectory.FullName -ChildPath "$($Name).psd1"
            $manifestContent = [string](Get-Content -Path $sourceManifestFilePath)
            if ($manifestContent -match "ModuleVersion = '(\d+\.\d+\.\d+)'") {
                $moduleVersion = $Matches[1]
            }
            else {
                throw 'Invalid module version.'
            }
        }
        catch {
            throw "Failed to get source items or module version. $($PSItem)"
        }
    
        # Check if module version is same as current month.
        if (-not $SkipVersionCheck) {
            if ($moduleVersion -match '\d+\.(\d+)\.\d+') {
                $month = $Matches.1
                if ($month -ne (Get-Date).Month) {
                    throw 'Module version month is not current month.'
                }
            }
            else {
                throw "Invalid module version format '$($moduleVersion)'."
            }
        }

        # Get subdirectories and function files.
        $developmentDirectoryPath = Join-Path -Path (Join-Path -Path $Path -ChildPath $Name) -ChildPath 'Development'
        $privateFunctionsDirectoryPath = Join-Path -Path $developmentDirectoryPath -ChildPath 'Private'
        $publicFunctionsDirectoryPath = Join-Path -Path $developmentDirectoryPath -ChildPath 'Public'
        $functionFiles = Get-ChildItem -Path $privateFunctionsDirectoryPath, $publicFunctionsDirectoryPath -Filter '*.ps1' -File
        $testDirectoryPath = Join-Path $developmentDirectoryPath -ChildPath 'Tests'
        $testFiles = Get-ChildItem -Path $testDirectoryPath -Filter '*.Tests.ps1' -File

        # Verify the existence of each public function in the module manifest list of exported functions.
        if (-not $SkipFunctionExportCheck) {
            $moduleManifestFilePath = Join-Path -Path $developmentDirectoryPath -ChildPath ('{0}.psd1' -f $Name)
            $moduleManifestExportedFunctions = (Import-PowerShellDataFile -Path $moduleManifestFilePath).FunctionsToExport
            $publicFunctionFiles = Get-ChildItem -Path $publicFunctionsDirectoryPath -Filter '*.ps1' -File
            foreach ($file in $publicFunctionFiles) {
                if ($file.BaseName -notin $moduleManifestExportedFunctions) {
                    throw "Public function '$($file.BaseName)' is not in the module manifest list of exported functions."
                }
            }
        }

        # Run Pester tests.
        if (-not $SkipTests) {
            if (($testFiles | Measure-Object).Count -gt 0) {
                try {
                    $pesterTests = Invoke-PSDevModulePesterTest -Name $Name -Path $Path -Output Minimal -PassThru
                }
                catch {
                    throw "Failed to run Pester tests. $PSItem"
                }

                if ($pesterTests.Result -ne 'Passed') {
                    throw ('Failed {0} Pester test(s).' -f $pesterTests.FailedCount)
                }
            }
            else {
                Write-Warning "Found no valid test files in '$testDirectoryPath'."
            }
        }

        # Verify the existence of a test file for each function.
        foreach ($file in $functionFiles) {
            $testFilePath = Join-Path -Path $testDirectoryPath -ChildPath ('{0}.Tests.ps1' -f $file.BaseName)
            if (-not (Test-Path $testFilePath -PathType Leaf)) {
                $parentDirName = (Get-Item -Path (Split-Path -Path $file.FullName -Parent)).Name
                Write-Warning "Cannot find a test file for function '$parentDirName\$($file.Name)'."
            }
        }
    
        # Copy the development version to a new directory.
        try {
            $newVersionDestinationPath = Join-Path -Path $Path -ChildPath (Join-Path -Path $Name -ChildPath $Name) -AdditionalChildPath $moduleVersion
            if (!(Test-Path -Path $newVersionDestinationPath)) {
                New-Item -Path $newVersionDestinationPath -ItemType Directory
            }
            else {
                throw "Version $($moduleVersion) already exists in the development directory."
            }
            $sourceItems | Where-Object { $_.Name -notin $ignoreItems } | Copy-Item -Destination $newVersionDestinationPath -Recurse
        }
        catch {
            throw "Failed to copy version $($moduleVersion) to development directory '$($newVersionDestinationPath)'. $($PSItem)"
        }
    }

    end {}
}