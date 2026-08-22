function Get-ADInactiveUsers {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$OUPath,

        [ValidateRange(0, 365)]
        [int]$InactiveDays = 45,
        
        [string[]]$Server
    )

    $userList = [System.Collections.Generic.List[PSCustomObject]]::New()

    # Get a list of inactive users.
    if (($Server | Measure-Object).Count -gt 0) {
        # Specific servers.
        foreach ($srv in $Server) {
            Write-Host "--- $($srv) ---" -ForegroundColor Cyan
            $tempUserList = (
                Get-ADUser -SearchBase $OUPath -Server $srv -Filter { Enabled -eq $true } -Properties LastLogonDate, LastLogonTimestamp | Where-Object {
                    $_.LastLogonDate -lt (Get-Date).AddDays(-($InactiveDays))
                }
            )
            $properties = @(
                Name
                SamAccountName
                LastLogonDate
                @{ Name = 'LastLogonTime'; Expression = { [DateTime]::FromFileTime($_.LastLogonTimestamp).ToString('yyyy-MM-dd HH:mm:ss') } }
                DistinguishedName
                ObjectGUID
            )
            $tempUserList = $tempUserList | Select-Object -Property $properties | Sort-Object -Property Name
            $userList += $tempUserList
        }
    }
    else {
        # No specific server.
        $tempUserList = (
            Get-ADUser -SearchBase $OUPath -Filter { Enabled -eq $true } -Properties LastLogonDate, LastLogonTimestamp | Where-Object {
                ($_.LastLogonDate -lt (Get-Date).AddDays(-($InactiveDays))) -and ($null -ne $_.LastLogonDate)
            }
        )
        $properties = @(
            Name
            SamAccountName
            LastLogonDate
            @{ Name = 'LastLogonTime'; Expression = { [DateTime]::FromFileTime($_.LastLogonTimestamp).ToString('yyyy-MM-dd HH:mm:ss') } }
            DistinguishedName
            ObjectGUID
        )
        $tempUserList = $tempUserList | Select-Object -Property $properties | Sort-Object -Property Name
        $userList += $tempUserList
    }

    return $userList
}