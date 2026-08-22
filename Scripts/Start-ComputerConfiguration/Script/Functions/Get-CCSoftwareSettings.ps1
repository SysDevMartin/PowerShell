function Get-CCSoftwareSettings {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Path
    )

    begin {
        $data = $null
        $softwareName = Split-Path -Path (Split-Path -Path $Path -Parent) -Leaf
        Write-Verbose 'Importing software settings...'
    }

    process {
        try {
            $importedSettings = Import-Csv -Path $Path -Delimiter ';' -ErrorAction 'Stop'
        }
        catch {
            throw ('Failed to load settings for software "{0}". {1}' -f $softwareName, $PSItem)
        }

        if ($null -ne $importedSettings) {
            $data = [PSCustomObject]@{
                Name = $softwareName
                Manufacturer = $importedSettings.Manufacturer
                DirectoryPath = Split-Path -Path $Path -Parent
                File = $importedSettings.File
                Argument = $importedSettings.Argument
                InstallValidationPath = $importedSettings.InstallValidationPath
                InstallOrder = $importedSettings.InstallOrder -as [int]
            }

            if ($null -eq $data.InstallOrder) {
                $data.InstallOrder = 0
            }
        }
    }

    end {
        return $data
    }
}