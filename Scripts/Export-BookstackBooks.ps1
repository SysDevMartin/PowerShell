<#PSScriptInfo

.VERSION 1.0.0

.GUID e78e00dc-a88f-47e4-8f52-acc4b4853f9f

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

.DESCRIPTION
Export books from BookStack.

.EXAMPLE
$params = @{
    BaseUrl = 'https://bookstack.domain.com:6875'
    ApiToken = '4f2fbd65-d68d-451a-ab23-27c79969313d'
    ApiSecret = (Read-Host 'API secret' -AsSecureString)
    DestinationDirectoryPath = 'C:\Backup\Bookstack'
}
Export-BookstackBooks.ps1 @params

Export all books to a compressed zip file in the destination directory.

.EXAMPLE
$params = @{
    BaseUrl = 'https://bookstack.domain.com:6875'
    ApiToken = '4f2fbd65-d68d-451a-ab23-27c79969313d'
    ApiSecret = (Read-Host 'API secret' -AsSecureString)
    DestinationDirectoryPath = 'C:\Backup\Bookstack'
    RetentionDays = 90
}
Export-BookstackBooks.ps1 @params

Export all books to a compressed zip file in the destination directory, then delete exported zip files that are older than 90 days from the destination directory.
#> 
param(
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [string]$BaseUrl,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [string]$ApiToken,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [SecureString]$ApiSecret,

    [ValidateScript({
        if (Test-Path -Path $_ -PathType Container) { return $true }
        else { throw [System.IO.DirectoryNotFoundException] "Cannot find the directory '$_'." }
    })]
    [string]$DestinationDirectoryPath,

    [ValidateRange(0, 3650)]
    [int]$RetentionDays = 0
)

function Get-BookstackBooks {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$BaseUrl,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$ApiToken,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [SecureString]$ApiSecret
    )

    $books = @()

    try {
        $params = @{
            Uri = ('{0}/api/books' -f $BaseUrl)
            Headers = @{
                'Content-Type' = 'application/json'
                'Authorization' = ('Token {0}:{1}' -f $ApiToken, (ConvertFrom-SecureString -SecureString $ApiSecret -AsPlainText))
            }
        }
        $response = Invoke-WebRequest @params | ConvertFrom-Json
        $books = $response.Data
    }
    catch {
        throw "Failed to get books. $PSItem"
    }

    return $books
}

function Export-BookstackBook {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$BaseUrl,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$ApiToken,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [SecureString]$ApiSecret,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [int]$Id,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [ValidateSet('html', 'pdf', 'plaintext', 'markdown')]
        [string]$FileType
    )

    $response = $null

    Write-Verbose ('Exporting book ID {0} as {1}...' -f $Id, $FileType)

    try {
        $params = @{
            Uri = ('{0}/api/books/{1}/export/{2}' -f $BaseUrl, $Id, $FileType.ToLower())
            Headers = @{
                'Content-Type' = 'application/json'
                'Authorization' = ('Token {0}:{1}' -f $ApiToken, (ConvertFrom-SecureString -SecureString $ApiSecret -AsPlainText))
            }
        }
        $response = Invoke-WebRequest @params

        try {
            Set-Content -Path $FilePath -Value $response.Content -AsByteStream
        }
        catch {
            throw "Failed to get book data. $($PSItem)"
        }
    }
    catch {
        throw ('Failed to export book with ID {0} as {1}. {2}' -f $Id, $FileType.ToLower(), $PSItem)
    }
}

# Create temporary book directory.
$TempOutputDirectoryPath = (Join-Path -Path $env:TEMP -ChildPath "TempBookstackBooks_$(Get-Date -Format 'yyyyMMddHHmmss')")
if (-not (Test-Path -Path $TempOutputDirectoryPath -PathType Container)) {
    Write-Verbose "Creating temp directory '$TempOutputDirectoryPath'..."
    New-Item -Path $TempOutputDirectoryPath -ItemType Directory -ErrorAction Stop | Out-Null
}

# Get all books.
Write-Verbose 'Getting all books...'
$params = @{
    BaseUrl = $BaseUrl
    ApiToken = $ApiToken
    ApiSecret = $ApiSecret
}
$allBooks = Get-BookstackBooks @params

# Export all books.
Write-Verbose 'Exporting all books...'
@('html', 'pdf', 'plaintext', 'markdown') | ForEach-Object {
    $fileType = $_
    Write-Verbose "Exporting books as $fileType..."

    $tempDestinationDirectoryPath = Join-Path -Path $TempOutputDirectoryPath -ChildPath $fileType
    New-Item -Path $tempDestinationDirectoryPath -ItemType Directory -ErrorAction Stop | Out-Null

    switch ($fileType) {
        'html' { $fileExtension = 'html' }
        'pdf' { $fileExtension = 'pdf' }
        'plaintext' { $fileExtension = 'txt' }
        'markdown' { $fileExtension = 'md' }
    }

    foreach ($book in $allBooks) {
        try {
            $params = @{
                BaseUrl = $BaseUrl
                ApiToken = $ApiToken
                ApiSecret = $ApiSecret
                Id = $book.id
                FilePath = Join-Path -Path $tempDestinationDirectoryPath -ChildPath ('{0}.{1}' -f $book.slug, $fileExtension)
                FileType = $fileType
            }
            Export-BookstackBook @params
        }
        catch {
            Write-Warning "Failed to export book with ID $($params.Id) as $fileType."
        }
    }
}

# Build the compression path list for each file type.
$compressionDirectoryPaths = @()
@('html', 'pdf', 'plaintext', 'markdown') | ForEach-Object {
    $fileType = $_
    $tempPath = Join-Path -Path $TempOutputDirectoryPath -ChildPath $fileType
    if (Test-Path -Path $tempPath -PathType Container) {
        $compressionDirectoryPaths += $tempPath
    }
}

# Compress the directories.
$baseExportFilename = 'BookStack books'
$date = Get-Date
$compressionFilename = '{0} ({1}).zip' -f $baseExportFilename, (Get-Date $date -Format 'yyyy-MM-dd HH-mm-ss')
$compressionDestinationFilePath = Join-Path -Path $DestinationDirectoryPath -ChildPath $compressionFilename
Write-Verbose "Compressing directories to zip file '$compressionDestinationFilePath'..."
Compress-Archive -Path $compressionDirectoryPaths -DestinationPath $compressionDestinationFilePath -ErrorAction Stop

# Clean up temporary files and directories.
if (Test-Path -Path $TempOutputDirectoryPath -PathType Container) {
    Write-Verbose 'Cleaning up temporary files and directories...'
    $TempOutputDirectoryPath | Remove-Item -Recurse
}

# Validate the exported file.
Write-Verbose 'Validating the exported file...'
$fileSize = (Get-Item -Path $compressionDestinationFilePath).Length
if ($fileSize -eq 0) {
    Write-Error 'The exported zip file '$compressionDestinationFilePath' is empty.'
}

# Clean up old exported files.
if ($RetentionDays -gt 0) {
    Write-Verbose "Cleaning up old exported files in '$DestinationDirectoryPath'..."
    Get-ChildItem -Path $DestinationDirectoryPath -Filter "$($baseExportFilename) (*).zip" -File | Where-Object {
        $_.CreationTime -lt (Get-Date).AddDays(-($RetentionDays))
    } | Remove-Item
}

# Return the compressed file.
Get-Item -Path $compressionDestinationFilePath