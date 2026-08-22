<# 
.SYNOPSIS
Gets the expiration date and time for a web certificate.

.DESCRIPTION
This function takes a URI and returns a DateTime object for the website's certificate expiration.

.INPUTS
None.

.OUTPUTS
Outputs a DateTime object for the certificate expiration.

.EXAMPLE
Get-WebCertificateExpiration -Uri 'https://wwww.google.com'
#>
function Get-WebCertificateExpiration {
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [System.Uri]$Uri
    )

    begin {
        $certificateExpirationDate = $null
    }

    process {
        $command = [ScriptBlock]{
            $requestUrl = $Args[0]
            $connection = [System.Net.HttpWebRequest]::Create($requestUrl)
            $response = $connection.GetResponse()
            $response.Dispose()
            $certificate = $connection.ServicePoint.Certificate
            $certificate.GetExpirationDateString()
        }
    
        try {
            $certificateExpiration = (powershell.exe -Command $command -Args $Uri)

            if ($null -ne $certificateExpiration) {
                $certificateExpirationDate = Get-Date -Date $certificateExpiration
            }
        }
        catch {
            throw "Failed to get certificate expiration date. $PSItem"
        }
    }

    end {
        $certificateExpirationDate
    }
}