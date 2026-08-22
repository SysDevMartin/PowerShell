<#PSScriptInfo

.VERSION 1.0.0

.GUID 6ac4ad2a-7367-498e-aaef-1b73c8bb2ee1

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
Get a list of inactive users from Microsoft Entra.

.DESCRIPTION
This function fetches and filters inactive users from Microsoft Entra.

.INPUTS
None.

.OUTPUTS
This function returns a list of inactive users.

.EXAMPLE
Get-M365InactiveUsers.ps1 -MinimumInactiveDays 60

Get a list of all M365 accounts that haven't logged in for at least 60 days.
#>
param(
    [ValidateRange(0, 10000)]
    [int]$MinimumInactiveDays = 30,

    [switch]$OnlyRealUsers,

    [switch]$OnlyEnabled,

    [switch]$ShowTable
)

#region Functions

function Get-ScriptM365UserLogons {
    param(
        [ValidateRange(0, 3650)]
        [int]$InactiveDays = 0,

        [switch]$OnlyRealUsers
    )

    $graphProperties = @(
        'Id'
        'DisplayName'
        'SignInActivity'
        'UserPrincipalName'
        'UserType'
        'CompanyName'
        'Country'
        'City'
        'Department'
        'JobTitle'
        'AccountEnabled'
    )

    $displayProperties = @(
        'DisplayName'
        'UserPrincipalName'
        'CompanyName'
        'Country'
        'City'
        'Department'
        'JobTitle'
        @{ Name = 'LastSignIn'; Expression = { $_.SignInActivity.LastSignInDateTime } }
        @{ Name = 'LastNonInteractiveSignIn'; Expression = { $_.SignInActivity.LastNonInteractiveSignInDateTime } }
        'AccountEnabled'
        'UserType'
        'Id'
    )

    $inactivityDate = (Get-Date).AddDays(-($InactiveDays))

    if ($OnlyRealUsers) {
        $users = Get-MgUser -All -Property $graphProperties | Where-Object {
            (-not [string]::IsNullOrEmpty($_.CompanyName)) -and
            ($null -ne $_.SignInActivity.LastSignInDateTime) -and
            ($null -ne $_.SignInActivity.LastNonInteractiveSignInDateTime) -and
            ($_.SignInActivity.LastSignInDateTime -le $inactivityDate) -and
            ($_.SignInActivity.LastNonInteractiveSignInDateTime -le $inactivityDate)
        } | Select-Object -Property $displayProperties | Sort-Object -Property DisplayName | Where-Object {
            ((Get-MgUserLicenseDetail -UserId $_.Id) | Measure-Object).Count -gt 0
        }
    }
    else {
        $users = Get-MgUser -All -Property $graphProperties | Where-Object {
            ($_.SignInActivity.LastSignInDateTime -le $inactivityDate) -and
            ($_.SignInActivity.LastNonInteractiveSignInDateTime -le $inactivityDate)
        } | Select-Object -Property $displayProperties | Sort-Object -Property DisplayName
    }

    return $users
}

#endregion

Connect-MgGraph -Scopes 'User.Read.All', 'AuditLog.Read.All' -NoWelcome -ErrorAction Stop

$userList = [System.Collections.Generic.List[PSCustomObject]]::New()

# Get inactive Microsoft 365 users.
$inactiveM365Users = Get-ScriptM365UserLogons -InactiveDays $MinimumInactiveDays -OnlyRealUsers:$OnlyRealUsers
if (($inactiveM365Users | Measure-Object).Count -gt 0) {
    $properties = @(
        @{ Name = 'Name'; Expression = { $_.DisplayName } }
        'UserPrincipalName'
        @{ Name = 'Company'; Expression = { $_.CompanyName } }
        'Country'
        @{ Name = 'LastSignIn'; Expression = { if ($_.LastSignIn -ge $_.LastNonInteractiveSignIn) { $_.LastSignIn } else { $_.LastNonInteractiveSignIn } } }
        @{ Name = 'Enabled'; Expression = { $_.AccountEnabled } }
        'Id'
    )

    if ($OnlyEnabled -eq $true) {
        $userList += $inactiveM365Users | Select-Object -Property $properties | Where-Object { $_.Enabled -eq $true }
    }
    else {
        $userList += $inactiveM365Users | Select-Object -Property $properties
    }
}

$userList = $userList | Sort-Object -Property LastSignIn -Descending

if ($ShowTable) {
    $userList | Format-Table
}
else {
    $userList
}