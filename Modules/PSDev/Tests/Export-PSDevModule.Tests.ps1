BeforeAll {
    $rootDirectoryPath = Split-Path -Path $PSScriptRoot -Parent
    . "$rootDirectoryPath\Public\Export-PSDevModule.ps1"
}

Describe 'Export-PSDevModule' {
    BeforeAll {
        $moduleRootDirectoryPath = "$env:TEMP\TempPesterTestDirectory_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -Path $moduleRootDirectoryPath -ItemType Directory -ErrorAction SilentlyContinue
        $moduleDirectoryPath = Join-Path -Path $moduleRootDirectoryPath -ChildPath 'TestModule'
        New-Item -Path $moduleDirectoryPath -ItemType Directory -ErrorAction SilentlyContinue
        $developmentDirectoryPath = Join-Path -Path $moduleDirectoryPath -ChildPath 'Development'
        New-Item -Path $developmentDirectoryPath -ItemType Directory -ErrorAction SilentlyContinue
        New-Item -Path (Join-Path -Path $developmentDirectoryPath -ChildPath 'Private') -ItemType Directory -ErrorAction SilentlyContinue
        New-Item -Path (Join-Path -Path $developmentDirectoryPath -ChildPath 'Public') -ItemType Directory -ErrorAction SilentlyContinue
        New-Item -Path (Join-Path -Path $developmentDirectoryPath -ChildPath 'Tests') -ItemType Directory -ErrorAction SilentlyContinue

        Mock Copy-Item {}
        Mock Get-Content { return "ModuleVersion = '25.10.1'" }
        Mock Import-PowerShellDataFile { return '' }
        Mock New-Item {}
        Mock Set-Location {}
    }

    It 'Export new version of a module' {
        Export-PSDevModule -Name 'TestModule' -Path $moduleRootDirectoryPath -SkipVersionCheck -SkipTests
    }

    AfterAll {
        Remove-Item -Path $moduleRootDirectoryPath -Recurse -ErrorAction SilentlyContinue
    }
}