BeforeAll {
    $rootDirectoryPath = Split-Path -Path $PSScriptRoot -Parent
    . "$rootDirectoryPath\Public\Export-PSDevScript.ps1"
}

Describe 'Export-PSDevScript' {
    BeforeAll {
        $scriptRootDirectoryPath = "$env:TEMP\TempPesterTestDirectory_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -Path $scriptRootDirectoryPath -ItemType Directory -ErrorAction SilentlyContinue
        $scriptDirectoryPath = Join-Path -Path $scriptRootDirectoryPath -ChildPath 'TestScript'
        New-Item -Path $scriptDirectoryPath -ItemType Directory -ErrorAction SilentlyContinue
        New-Item -Path (Join-Path -Path $scriptDirectoryPath -ChildPath 'Development') -ItemType Directory -ErrorAction SilentlyContinue

        Mock Copy-Item {}
        Mock Get-Content { return ".VERSION 25.10.1" }
        Mock New-Item {}
        Mock Set-Location {}
    }

    It 'Export new version of a script' {
        Export-PSDevScript -Name 'TestScript' -Path $scriptRootDirectoryPath -SkipVersionCheck
    }

    AfterAll {
        Remove-Item -Path $scriptRootDirectoryPath -Recurse -ErrorAction SilentlyContinue
    }
}