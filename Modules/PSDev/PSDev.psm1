foreach ($directoryName in @('Private', 'Public')) {
    $directoryPath = Join-Path -Path $PSScriptRoot -ChildPath $directoryName
    if (Test-Path -Path $directoryPath) {
        Get-ChildItem -Path (Join-Path -Path $directoryPath -ChildPath '*.ps1') | ForEach-Object { . $_.FullName }
    }
}