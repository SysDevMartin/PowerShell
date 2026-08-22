<#PSScriptInfo

.VERSION 1.0.0

.GUID d5ee42b9-a7be-440b-a2a1-c0d6c70feecf

.AUTHOR Martin Olsson

.COMPANYNAME Martin Olsson

.COPYRIGHT (c) Martin Olsson. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 
.SYNOPSIS
Compresses files to multiple archive files.

.DESCRIPTION 
This script takes filtered files from a folder and compresses them to multiple output archive files (with limited size or file count per output archive).
Set FileSizeByteLimit to 0 for infinite file size per archive. Set FileSizeCountLimit to 0 for infinite file count per archive.

.INPUTS
None

.OUTPUTS
.None

.EXAMPLE
Compress-ToMultipleArchiveFiles -Path "$env:USERPROFILE\Downloads" -Filter "*.pdf" -Destination "$env:USERPROFILE\Desktop" -FileSizeByteLimit 100000 -FileSizeCountLimit 10

#>
param(
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    $Path,

    [ValidateNotNull()]
    $Filter = '*.*',

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    $DestinationPath,

    [ValidateNotNull()]
    $FileSizeByteLimit = 0,

    [ValidateNotNull()]
    $FileSizeCountLimit = 0
)

# Loop through the files and compress them.
$sourceFiles = Get-ChildItem -Path $Path -Filter $Filter | Sort-Object -Property Name
$totalSourceFileCount = ($sourceFiles | Measure-Object).Count
Write-Verbose ('Total source files: {0}' -f $totalSourceFileCount)

$tempOutputFiles = @()
$tempFileSizeSum = 0
$tempFileCount = 0
$tempTotalFileCount = 0
$tempOutputFileSets = @()

foreach ($file in $sourceFiles) {
    $tempOutputFiles += $file
    $tempFileSizeSum += $file.Length
    $tempFileCount += 1
    $tempTotalFileCount += 1

    if (
        (($tempFileSizeSum -ge $FileSizeLimit) -and ($FileSizeLimit -gt 0)) -or
        (($tempFileCount -ge $FileCountLimit) -and ($FileCountLimit -gt 0)) -or
        ($tempTotalFileCount -eq $totalSourceFileCount)
    ) {
        $tempOutputFileSets += @{
            Files = $tempOutputFiles
            TotalBytes = $tempFileSizeSum
        }
        $tempOutputFiles = @()
        $tempFileSizeSum = 0
        $tempFileCount = 0
    }
}

$tempOutputFileNumber = 0
Write-Verbose "Output file sets: $($tempOutputFileSets.Count)"
foreach ($fileSet in $tempOutputFileSets) {
    $tempOutputFileNumber += 1

    # Compress the files, then move on to the next set of files.
    $outputFilePath = Join-Path -Path $DestinationPath -ChildPath "output_file_$($tempOutputFileNumber).zip"
    if ((Test-Path -Path $outputFilePath) -eq $false) {
        Write-Output ('Compressing {0} files ({1} MB) to "{2}".' -f ($fileSet.Files | Measure-Object).Count, [Math]::Round($fileSet.TotalBytes / 1MB, 2), $outputFilePath)
        $fileSet.Files.FullName | Compress-Archive -DestinationPath $outputFilePath
    }
    else {
        Write-Warning ('Output file "{0}" already exists.' -f $outputFilePath)
    }
}