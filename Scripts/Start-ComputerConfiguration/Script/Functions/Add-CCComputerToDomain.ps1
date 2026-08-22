function Add-CCComputerToDomain {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$DomainName,

        [string]$OUPath,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]$Credential
    )

    begin {
        $attemptDomainJoin = $true
    }

    process {
        Write-Verbose ('Adding computer to the "{0}" domain...' -f $DomainName)

        if ($DomainName -eq $env:USERDOMAIN) {
            throw ('The computer is already a member of the "{0}" domain.' -f $env:USERDOMAIN)
        }

        while ($attemptDomainJoin) {
            try {
                $params = @{
                    DomainName = $DomainName
                    Credential = $Credential
                    Restart = $true
                    Confirm = $true
                    ErrorAction = 'Stop'
                }

                if (-not [string]::IsNullOrEmpty($OUPath)) {
                    $params += @{
                        OUPath = $OUPath
                    }
                }

                Add-Computer @params
                $attemptDomainJoin = $false
            }
            catch {
                Write-Error "Failed to add computer to the domain. $PSItem"
                Read-Host 'Press <Enter> to try again or <Ctrl+C> to cancel'
            }
        }
    }

    end {}
}