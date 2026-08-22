<# 
.SYNOPSIS
Gets your current LAN IP address.

.DESCRIPTION
This function automatically fetches your current LAN IP address.

.INPUTS
None.

.OUTPUTS
Outputs a string that contains the IP address.

.EXAMPLE
Get-LanIP
#>
function Get-LanIP {
    param()

    begin {
        $ipAddress = ''
    }

    process {
        $ipAddress = (Get-NetIPConfiguration | Where-Object {
            ($null -ne $_.IPv4DefaultGateway) -and
            ($_.NetAdapter.Status -ne 'Disconnected')
        }).IPv4Address.IPAddress
    }

    end {
        $ipAddress
    }
}