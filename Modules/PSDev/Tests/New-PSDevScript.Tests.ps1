BeforeAll {
    $rootDirectoryPath = Split-Path -Path $PSScriptRoot -Parent
    . "$rootDirectoryPath\Public\New-PSDevScript.ps1"
}

Describe 'New-PSDevScript' {
    BeforeAll {
        $rootScriptDirectoryPath = "$env:TEMP\TempPesterTestDirectory_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -Path $rootScriptDirectoryPath -ItemType Directory -ErrorAction SilentlyContinue
    }

    It 'Create a new script' {
        New-PSDevScript -Name 'TestScript' -Description 'Test description' -Author 'My Name' -Path $rootScriptDirectoryPath
    }

    AfterAll {
        Remove-Item -Path $rootScriptDirectoryPath -Recurse -ErrorAction SilentlyContinue
    }
}