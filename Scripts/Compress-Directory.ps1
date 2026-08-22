<# 
.SYNOPSIS
Creates a compressed archive from a specified directory.

.DESCRIPTION
This functions compresses a directory into an archive. The function includes hidden files and folders. Use the -Force parameter to overwrite an existing destination file.

.INPUTS
System.String
    You can pipe a string that contains a directory path.

.OUTPUTS
Outputs the compressed archive file.

.EXAMPLE
Compress-Directory "$env:USERPROFILE\MyDirectory"

Output the archive file in the same location as the compressed directory.

.EXAMPLE
Compress-Directory -Path "$env:USERPROFILE\MyDirectory" -DestinationFilePath "env:USERPROFILE\MyCompressedArchiveFile.zip"

Output the archive file to a specific destination file.

.EXAMPLE
Compress-Directory -Path "$env:USERPROFILE\MyDirectory" -DestinationFilePath "env:USERPROFILE\MyCompressedArchiveFile.zip" -CompressionLevel Fastest -Force

Set the compression level and force the destination file to overwritten.
#>
function Compress-Directory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Container) { return $true }
            else { throw [System.IO.DirectoryNotFoundException] ('Cannot find the directory "{0}".' -f $_) }
        })]
        [string]$Path,

        [Parameter(Position = 1)]
        [ValidateScript({
            if (Test-Path -Path (Split-Path -Path $_ -Parent) -PathType Container) { return $true }
            else { throw [System.IO.DirectoryNotFoundException] ('Cannot find the parent directory for "{0}".' -f $_) }
        })]
        [string]$DestinationFilePath,

        [ValidateSet('Optimal', 'Fastest', 'NoCompression', 'SmallestSize')]
        [string]$CompressionLevel = 'Optimal',

        [switch]$Force
    )

    begin {
        $outputFile = $null
    }

    process {
        switch ($CompressionLevel) {
            'Optimal' {
                $compressionLevelNumber = 0
            }
            'Fastest' {
                $compressionLevelNumber = 1
            }
            'NoCompression' {
                $compressionLevelNumber = 2
            }
            'SmallestSize' {
                $compressionLevelNumber = 3
            }
        }
    
        if ($PSBoundParameters.ContainsKey('DestinationFilePath')) {
            # Use the provided destination file path if it's specified.
            $actualDestinationFilePath = $DestinationFilePath
        }
        else {
            # Use the source directory to automatically build the destination file path if it's not specified.
            $directoryPath = Split-Path -Path $Path
            $filename = '{0}.zip' -f (Split-Path -Path $Path -Leaf)
            $actualDestinationFilePath = Join-Path -Path $directoryPath -ChildPath $filename
        }
    
        if ($Force -and (Test-Path -Path $actualDestinationFilePath -PathType Leaf)) {
            Remove-Item -Path $actualDestinationFilePath -ErrorAction Continue
        }
    
        try {
            [System.IO.Compression.ZipFile]::CreateFromDirectory($Path, $actualDestinationFilePath, $compressionLevelNumber, $false)
            $outputFile = Get-Item -Path $actualDestinationFilePath
        }
        catch {
            Write-Error ('Failed to archive "{0}". {1}' -f $Path, $PSItem)
        }
    }

    end {
        return $outputFile
    }
}