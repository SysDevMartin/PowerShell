BeforeAll {
    $rootDirectoryPath = Split-Path -Path $PSScriptRoot -Parent
    . "$rootDirectoryPath\Public\Get-PSDevLatestReleasedDevVersion.ps1"
    . "$rootDirectoryPath\Public\Publish-PSDevScript.ps1"
}

Describe 'Publish-PSDevScript' {
    BeforeAll {
        $rootScriptDirectoryPath = "$env:TEMP\TempPesterTestDirectory_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -Path $rootScriptDirectoryPath -ItemType Directory -ErrorAction SilentlyContinue

        Mock Get-PSDevLatestReleasedDevVersion {
            return [PSCustomObject]@{
                Year = 25
                Month = 10
                Iteration = 1
                FullVersion = 25.10.1
            }
        }
        Mock Test-Path { return $true }
        Mock Publish-Script {}
    }

    It 'Publish the latest version of a script to a repository' {
        Publish-PSDevScript -Name 'TestScript' -Path $rootScriptDirectoryPath -Repository 'CustomRepository'
    }

    AfterAll {
        Remove-Item -Path $rootScriptDirectoryPath -ErrorAction SilentlyContinue
    }
}