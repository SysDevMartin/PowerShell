BeforeAll {
    $rootDirectoryPath = Split-Path -Path $PSScriptRoot -Parent
    . "$rootDirectoryPath\Public\New-PSDevModule.ps1"
}

Describe 'New-PSDevModule' {
    BeforeAll {
        $rootModuleDirectoryPath = "$env:TEMP\TempPesterTestDirectory_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -Path $rootModuleDirectoryPath -ItemType Directory -ErrorAction SilentlyContinue
    }

    It 'Create a new module' {
        New-PSDevModule -Name 'TestModule' -Description 'Test description' -Author 'My Name' -Path $rootModuleDirectoryPath
    }

    AfterAll {
        Remove-Item -Path $rootModuleDirectoryPath -Recurse -ErrorAction SilentlyContinue
    }
}