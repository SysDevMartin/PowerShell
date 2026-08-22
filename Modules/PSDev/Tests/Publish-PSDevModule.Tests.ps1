BeforeAll {
    $rootDirectoryPath = Split-Path -Path $PSScriptRoot -Parent
    . "$rootDirectoryPath\Public\Get-PSDevLatestReleasedDevVersion.ps1"
    . "$rootDirectoryPath\Public\Publish-PSDevModule.ps1"
}

Describe 'Publish-PSDevModule' {
    BeforeAll {
        $rootModuleDirectoryPath = "$env:TEMP\TempPesterTestDirectory_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -Path $rootModuleDirectoryPath -ItemType Directory -ErrorAction SilentlyContinue

        Mock Get-PSDevLatestReleasedDevVersion {
            return [PSCustomObject]@{
                Year = 25
                Month = 10
                Iteration = 1
                FullVersion = 25.10.1
            }
        }
        Mock Test-Path { return $true }
        Mock Publish-Module {}
    }

    It 'Publish the latest version of a module to a repository' {
        Publish-PSDevModule -Name 'TestModule' -Path $rootModuleDirectoryPath -Repository 'CustomRepository'
    }

    AfterAll {
        Remove-Item -Path $rootModuleDirectoryPath -ErrorAction SilentlyContinue
    }
}