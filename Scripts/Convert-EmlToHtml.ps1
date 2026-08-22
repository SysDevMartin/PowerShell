<# 
.SYNOPSIS
Converts an EML file to an HTML file.

.DESCRIPTION
This functions converts an EML (Outlook message) file to an HTML file, and places the HTML file as a copy in the same folder as the EML file.

.INPUTS
System.String
    You can pipe a string that contains a file path.

.OUTPUTS
System.IO.FileInfo

.EXAMPLE
Convert-EmlToHtml -FilePath "$env:USERPROFILE\outlook_message.eml"
#>
function Convert-EmlToHtml {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Leaf) { return $true }
            else { throw [System.IO.FileNotFoundException] ('Cannot find the file "{0}".' -f $_) }
        })]
        [string]$FilePath
    )

    begin {}

    process {
        try {
            $stream = New-Object -ComObject 'ADODB.Stream'
            $stream.Open()
            $stream.LoadFromFile($FilePath)
            $message = New-Object -ComObject 'CDO.Message'
            $message.DataSource.OpenObject($stream, '_Stream')
        }
        catch {
            throw "Failed to load content from '$($FilePath)'. $($PSItem)"
        }
    
        $exportDirectoryPath = Split-Path -Path $FilePath -Parent
        $exportFilename = "$(Split-Path -Path $FilePath -LeafBase).html"
        $exportFilePath = Join-Path -Path $exportDirectoryPath -ChildPath $exportFilename
    
        $html = '<!DOCTYPE html>'
        $html += '<html>'
        $html += '<head>'
        $html += '<meta charset="utf-8">'
        $html += '<title>' + $message.Subject + '</title>'
        $html += '</head>'
        $html += '<body style="font-family: sans-serif; font-size: 11pt;">'
        $html += '<div style="margin-bottom: 1em;">'
        $html += '<strong>Subject:</strong> ' + $message.Subject + '<br>'
        $html += '<strong>Sent:</strong> ' + (Get-Date $message.SentOn -Format 'yyyy-MM-dd HH:mm:ss') + '<br>'
        $html += '<strong>From:</strong> ' + $message.From.Replace('<', '(').Replace('>', ')') + '<br>'
        $html += '<strong>To:</strong> ' + $message.To.Replace('<', '(').Replace('>', ')') + '<br>'
        if (![string]::IsNullOrEmpty($message.CC)) {
            $html += '<strong>CC:</strong> ' + $message.CC.Replace('<', '(').Replace('>', ')') + '<br>'
        }
        if (![string]::IsNullOrEmpty($message.BCC)) {
            $html += '<strong>BCC:</strong> ' + $message.BCC.Replace('<', '(').Replace('>', ')') + '<br>'
        }
        $html += '</div>'
        if (![string]::IsNullOrEmpty($message.HTMLBody)) {
            $html += '<div>'
            $html += $message.HTMLBody
            $html += '</div>'
        }
        else {
            $html += '<div>'
            $html += $message.TextBody
            $html += '</div>'
        }
        $html += '</body>'
        $html += '</html>'

        try {
            $html | Out-File -FilePath $exportFilePath
        }
        catch {
            throw ('Failed to save HTML file "{0}". {1}' -f $exportFilePath, $PSItem)
        }
    }

    end {
        Get-Item -Path $exportFilePath
    }
}