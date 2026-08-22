BeforeAll {
    $rootDirectoryPath = Split-Path -Path $PSScriptRoot -Parent
    . "$rootDirectoryPath\Public\Get-PSDevLatestReleasedDevVersion.ps1"
}

Describe 'Get-PSDevLatestReleasedDevVersion' {
    BeforeAll {
        $devRootPath = "$env:TEMP\TempPesterTestDirectory_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -Path $devRootPath -ItemType Directory -ErrorAction SilentlyContinue

        Mock Get-ChildItem {
            return [PSCustomObject]@(
                [PSCustomObject]@{ BaseName = '25.5.20' }
                [PSCustomObject]@{ BaseName = '25.10.3' }
                [PSCustomObject]@{ BaseName = '25.1.1' }
            )
        }
    }

    It 'Get latest script or module version in a directory' {
        $latestVersion = Get-PSDevLatestReleasedDevVersion -Path $devRootPath
        $latestVersion.Year | Should -BeExactly 25
        $latestVersion.Month | Should -BeExactly 10
        $latestVersion.Iteration | Should -BeExactly 3
        $latestVersion.FullVersion | Should -BeExactly 25.10.3
    }

    AfterAll {
        Remove-Item -Path $devRootPath -ErrorAction SilentlyContinue
    }
}