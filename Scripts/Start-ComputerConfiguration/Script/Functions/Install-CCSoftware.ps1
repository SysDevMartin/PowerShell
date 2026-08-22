function Install-CCSoftware {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Container) { return $true }
            else { throw [System.IO.DirectoryNotFoundException] "Cannot find the directory '$_'." }
        })]
        [string]$DirectoryPath,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Filter,

        [string]$Argument
    )

    begin {
        $directoryName = Split-Path -Path $DirectoryPath -Leaf
        $Argument = if ([string]::IsNullOrEmpty($Argument)) { $null } else { $Argument.Replace('%DIR%', $DirectoryPath) }
        Write-Output ('Installing "{0}"...' -f $directoryName)
    }

    process {
        $fileList = Get-ChildItem -Path $DirectoryPath -Filter $Filter -File -Recurse
        foreach ($file in $fileList) {
            switch ($file.Extension) {
                '.exe' {
                    try {
                        if ([string]::IsNullOrEmpty($Argument)) {
                            Start-Process -FilePath $file.FullName -Wait -ErrorAction 'Stop'
                        }
                        else {
                            Start-Process -FilePath $file.FullName -ArgumentList @($Argument) -Wait -ErrorAction 'Stop'
                        }
                    }
                    catch {
                        throw ('Failed to install "{0}". {1}' -f $file.Name, $PSItem)
                    }
                }

                '.msi' {
                    try {
                        if ([string]::IsNullOrEmpty($Argument)) {
                            Start-Process -FilePath $file.FullName -Wait -ErrorAction 'Stop'
                        }
                        else {
                            Start-Process -FilePath $file.FullName -ArgumentList @($Argument) -Wait -ErrorAction 'Stop'
                        }
                    }
                    catch {
                        throw ('Failed to install "{0}". {1}' -f $file.Name, $PSItem)
                    }
                }

                '.inf' {
                    try {
                        if ([string]::IsNullOrEmpty($Argument)) {
                            Start-Process -FilePath 'pnputil.exe' -ArgumentList @('/add-driver "{0}" /install' -f $file.FullName) -Wait -ErrorAction 'Stop'
                        }
                        else {
                            Start-Process -FilePath 'pnputil.exe' -ArgumentList @($Argument) -Wait -ErrorAction 'Stop'
                        }
                    }
                    catch {
                        throw ('Failed to install "{0}". {1}' -f $file.Name, $PSItem)
                    }
                }

                default {
                    throw 'Invalid file type. Allowed file types: [exe, msi, inf].'
                }
            }
        }
    }

    end {}
}