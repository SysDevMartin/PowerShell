<# 
.SYNOPSIS
Gets details about one or more IP addresses.

.DESCRIPTION
This function returns information about an end-point, such as MAC-address and reachable state. The difference between this function and Get-NetNeighbor is that this function automatically tries to collect information about the connection if there is not cached data for the endpoint.

.INPUTS
None. You cannot pipe objects to this function.

.OUTPUTS
Outputs a list of neighbors.

.EXAMPLE
Get-NetNeighborWithTestConnection 10.0.0.1

.EXAMPLE
Get-NetNeighborWithTestConnection 10.0.0.1, 10.0.0.2, 10.0.0.3
#>
function Get-NetNeighborWithTestConnection {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$IPAddress
    )

    begin {
        $neighbors = [PSCustomObject]@()
    }

    process {
        foreach ($ip in $IPAddress) {
            $netNeighborInfo = Get-NetNeighbor -IPAddress $ip -ErrorAction SilentlyContinue

            if ($null -eq $netNeighborInfo) {
                Test-NetConnection -ComputerName $ip -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
                $netNeighborInfo = Get-NetNeighbor -IPAddress $ip -ErrorAction SilentlyContinue
            }

            if ($null -ne $netNeighborInfo) {
                $neighbors += $netNeighborInfo
            }
            else {
                Write-Error "Failed to get details for IP address $ip."
            }
        }
    }

    end {
        $neighbors
    }
}