<# 
.SYNOPSIS
Gets your current WAN IP address.

.DESCRIPTION
This function queries a website for your current WAN IP address.

.INPUTS
None. You cannot pipe objects to this function.

.OUTPUTS
Outputs a string that contains the IP address.

.EXAMPLE
Get-WanIP
#>
function Get-WanIP {
    param(
        [ValidateNotNull()]
        [System.Uri]$Uri = 'https://api.ipify.org'
    )

    begin {
        $ipAddress = ''
    }

    process {
        $ipAddress = Invoke-RestMethod -Uri $Uri
    }

    end {
        $ipAddress
    }
}