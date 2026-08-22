<#PSScriptInfo

.VERSION 1.0.0

.GUID bee081ca-9128-4dd0-ba23-f4f954b9a91d

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
Onboard a new user in Microsoft 365.

.DESCRIPTION
This script generates credentials and creates M365 accounts for new users.

.EXAMPLE
New-M365User.ps1 -ConfigurationPath 'C:\HR\Onboarding-Config.psd1'
#>
param(
    [string]$Organization,

    [string]$TenantId,

    [string]$AppClientId,

    [string]$AppCertificateThumbprint,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [string]$FirstName,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [string]$LastName,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [string]$UserPrincipalName,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [SecureString]$SecurePassword,

    [string]$Department,

    [string]$JobTitle,

    [string]$OfficeLocation,

    [string]$StreetAddress,

    [string]$PostalCode,

    [string]$City,

    [string]$Country,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [string]$UsageLocation,

    [string]$Company,

    [ValidateNotNull()]
    [bool]$ForcePasswordChange = $false,

    [ValidateNotNull()]
    [bool]$Enabled = $true,

    [string]$ManagerId,

    [string[]]$LicenseId,

    [string[]]$SecurityGroupId,

    [string[]]$DistributionGroupMail,

    [string[]]$TeamsGroupId,

    [string[]]$MailboxAccessWithSendPermission
)

#region Functions

function New-RandomString {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [int]$Length,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$AllowedCharacters,
        
        [ValidateNotNull()]
        [switch]$PreventDuplicateCharacters
    )

    # Prevent the function from getting stuck in an infinite loop if there are
    # not enough allowed characters to be able to prevent duplicate characeters.
    if ($AllowedCharacters.Length -le 1) {
        $PreventDuplicateCharacters = $false
    }

    # Generate characters.
    $characterString = ''
    for ($i = 0; $i -lt $Length; $i++) {
        $characterIndex = Get-Random -Minimum 0 -Maximum $AllowedCharacters.Length
        $character = $AllowedCharacters.Substring($characterIndex, 1)

        # Prevent duplicate side-by-side characters.
        if ($PreventDuplicateCharacters -and ($i -gt 0)) {
            while ($characterString.Substring($i - 1, 1) -ceq $character) {
                $characterIndex = Get-Random -Minimum 0 -Maximum $AllowedCharacters.Length
                $character = $AllowedCharacters.Substring($characterIndex, 1)
            }
        }

        $characterString += $character
    }

    return $characterString
}

function New-RandomPassword {
    [CmdletBinding(DefaultParameterSetName = 'SecureString')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'SecureString')]
        [Parameter(Position = 0, ParameterSetName = 'Clipboard')]
        [ValidateSet('User', 'PIN', 'Secure', 'SuperSecure')]
        [string]$Type = 'User',

        [Parameter(Position = 1, ParameterSetName = 'SecureString')]
        [Parameter(Position = 1, ParameterSetName = 'Clipboard')]
        [ValidateRange(1, 10000)]
        [int]$Length,

        [Parameter(ParameterSetName = 'SecureString')]
        [switch]$AsSecureString,

        [Parameter(ParameterSetName = 'Clipboard')]
        [switch]$CopyToClipboard
    )

    $password = ''

    switch ($Type) {
        'User' {
            $minLength = 5
            $tempLength = if ($Length) { $Length } else { 12 }
            if ($tempLength -lt $minLength) {
                $tempLength = $minLength
            }
            $password += New-RandomString -Length 1 -AllowedCharacters 'ABCDEFGHJKLMNPQRSTUVWZYX'
            $password += New-RandomString -Length ($tempLength - $minLength) -AllowedCharacters 'abcdefghjkmnpqrstuvwxyz' -PreventDuplicateCharacters
            $password += New-RandomString -Length 4 -AllowedCharacters '0123456789' -PreventDuplicateCharacters
        }

        'PIN' {
            $tempLength = if ($Length) { $Length } else { 4 }
            $password += New-RandomString -Length $tempLength -AllowedCharacters '0123456789'
        }

        'Secure' {
            $tempLength = if ($Length) { $Length } else { 30 }
            $password += New-RandomString -Length $tempLength -AllowedCharacters 'ABCDEFGHIJKLMNOPQRSTUVWZYXabcdefghijklmnopqrstuvwxyz0123456789'
        }

        'SuperSecure' {
            $tempLength = if ($Length) { $Length } else { 60 }
            $password += New-RandomString -Length $tempLength -AllowedCharacters 'ABCDEFGHIJKLMNOPQRSTUVWZYXabcdefghijklmnopqrstuvwxyz0123456789_-+.,:;=@^<>|(){}[]$%?!&#'
        }
    }

    if ($CopyToClipboard) {
        Set-Clipboard -Value $password
    }

    if ($AsSecureString) {
        $password = ConvertTo-SecureString -String $password -AsPlainText
    }

    if (-not $CopyToClipboard) {
        $password
    }
}

function ConvertTo-SanitizedString {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [string]$String
    )

    $replacementCharacters = @{
        'ä' = 'a'; 'æ' = 'a'; 'á' = 'a'; 'à' = 'a'; 'â' = 'a'; 'ã' = 'a'; 'å' = 'a'
        'ö' = 'o'; 'ø' = 'o'; 'ó' = 'o'; 'ò' = 'o'; 'ô' = 'o'; 'õ' = 'o'
        'ë' = 'e'; 'é' = 'e'; 'è' = 'e'; 'ê' = 'e'
        'ï' = 'i'; 'í' = 'i'; 'ì' = 'i'; 'î' = 'i'
        'ü' = 'u'; 'ú' = 'u'; 'ù' = 'u'; 'û' = 'u'
        'ÿ' = 'y'; 'ý' = 'y'
        'ñ' = 'n'
    }

    $sanitizedString = $String

    foreach ($key in $replacementCharacters.Keys) {
        $sanitizedString = $sanitizedString -Replace($key, $replacementCharacters.($key))
    }

    return $sanitizedString
}

function Convert-NameToMailAddress {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [string]$Name,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [string]$Domain
    )

    $replacementCharacters = @{
        ' ' = '.'
        '-' = ''
        '_' = ''
    }

    $mailNickname = (ConvertTo-SanitizedString -String $Name).ToLower()
    foreach ($key in $replacementCharacters.Keys) {
        $mailNickname = $mailNickname -Replace($key, $replacementCharacters.($key))
    }
    $mailAddress = '{0}@{1}' -f $mailNickname, $Domain
    
    return $mailAddress
}

function Set-M365UserManager {
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$ManagerId
    )

    try {
        $managerData = @{ '@odata.id' = ('https://graph.microsoft.com/v1.0/users/{0}' -f $ManagerId) }
        Set-MgUserManagerByRef -UserId $UserId -BodyParameter $managerData -ErrorAction Stop
    }
    catch {
        throw "Failed to set manager. $PSItem"
    }
}

function Add-M365UserLicense {
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [string]$UserId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$LicenseId
    )

    $newLicenses = @()

    try {
        $currentLicenses = Get-MgUserLicenseDetail -UserId $UserId -ErrorAction Stop
    }
    catch {
        throw "Failed to get current licenses. $PSItem"
    }

    foreach ($id in $LicenseId) {
        $assignedLicense = $currentLicenses | Where-Object { $_.SkuId -ceq $id }
        if (($assignedLicense | Measure-Object).Count -eq 0) {
            $newLicenses += @{ SkuId = $id }
        }
    }

    if (($newLicenses | Measure-Object).Count -gt 0) {
        try {
            Set-MgUserLicense -UserId $UserId -AddLicenses $newLicenses -RemoveLicenses @() -ErrorAction Stop | Out-Null
        }
        catch {
            throw "Failed to assign license(s). $PSItem"
        }
    }
}

function Add-M365GroupMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$UserId,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string[]]$GroupId,

        [Parameter(Mandatory)]
        [ValidateSet('SecurityGroup', 'TeamsGroup', 'DistributionGroup')]
        [string]$GroupType
    )

    switch ($GroupType) {
        'SecurityGroup' {
            foreach ($id in $GroupId) {
                try {
                    New-MgGroupMember -GroupId $id -DirectoryObjectId $UserId -ErrorAction Stop
                }
                catch {
                    Write-Error "Failed to add member '$UserId' to security group '$id'. $PSItem"
                }
            }
        }

        'TeamsGroup' {
            foreach ($id in $GroupId) {
                try {
                    New-MgGroupMember -GroupId $id -DirectoryObjectId $UserId -ErrorAction Stop
                }
                catch {
                    Write-Error "Failed to add member '$UserId' to Teams group '$id'. $PSItem"
                }
            }
        }

        'DistributionGroup' {
            foreach ($id in $GroupId) {
                try {
                    Add-DistributionGroupMember -Identity $id -Member $UserId -ErrorAction Stop
                }
                catch {
                    Write-Error "Failed to add member '$UserId' to distribution group '$id'. $PSItem"
                }
            }
        }
    }
}

function Add-M365MailboxPermission {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$UserPrincipalName,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$MailboxId,

        [Parameter(Mandatory)]
        [bool]$SendAsPermission,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [bool]$AutoMapping,

        [ValidateNotNull()]
        [string]$AccessRights = 'FullAccess',

        [ValidateNotNull()]
        [string]$InheritanceType = 'All'
    )

    $mailbox = Get-EXOMailbox -Identity $MailboxId -ErrorAction Stop
    $mailboxPermissions = Get-EXOMailboxPermission -Identity $mailbox.UserPrincipalName | Where-Object { $_.User -eq $UserPrincipalName }
    if (($mailboxPermissions | Measure-Object).Count -eq 0) {
        try {
            $params = @{
                Identity = $mailbox.PrimarySmtpAddress
                User = $UserPrincipalName
                AccessRights = $AccessRights
                InheritanceType = $InheritanceType
                AutoMapping = $AutoMapping
            }
            Add-MailboxPermission @params | Out-Null
        }
        catch {
            throw "Failed to add access permission for $($mailbox.PrimarySmtpAddress). $PSItem"
        }
    }

    if ($SendAsPermission) {
        $recipientPermissions = Get-RecipientPermission -Identity $mailbox.UserPrincipalName -Trustee $UserPrincipalName
        if (($recipientPermissions | Measure-Object).Count -eq 0) {
            try {
                $params = @{
                    Identity = $mailbox.PrimarySmtpAddress
                    Trustee = $UserPrincipalName
                    AccessRights = 'SendAs'
                    Confirm = $false
                }
                Add-RecipientPermission @params | Out-Null
            }
            catch {
                throw "Failed to add send permission for $($mailbox.PrimarySmtpAddress)."
            }
        }
    }
}

function Get-UserMailbox {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$UserPrincipalName,

        [ValidateRange(1, 100)]
        [int]$MaximumAttempts = 3,

        [ValidateRange(1, 600)]
        [int]$RetryIntervalSeconds = 60
    )

    $userMailbox = $null
    $currentAttempt = 0
    
    while ($null -eq $userMailbox) {
        try {
            $userMailbox = Get-EXOMailbox -Identity $UserPrincipalName -ErrorAction SilentlyContinue
        }
        catch {
            $userMailbox = $null
        }

        if (($userMailbox | Measure-Object).Count -gt 1) {
            throw 'Found more than one mailbox.'
        }

        if ($null -eq $userMailbox) {
            Write-Warning "Cannot find mailbox $($UserPrincipalName)."

            if ($currentAttempt -lt $MaximumAttempts) {
                Write-Verbose "Retrying in $($RetryIntervalSeconds) seconds..."
                Write-Verbose "[$($MaximumAttempts - $currentAttempt) more attempt(s) before timing out]"
                $currentAttempt++
                Start-Sleep -Seconds $RetryIntervalSeconds
            }
            else {
                Write-Warning 'The attempts timed out. Could not find user mailbox.'
                Read-Host 'Press <Enter> to try again or <Ctrl+C> to cancel'
                $currentAttempt = 0
            }
        }
    }

    return $userMailbox
}

function New-Microsoft365User {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$FirstName,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$LastName,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Department,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Company,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$OfficeLocation,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Country,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$UsageLocation,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$City,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$StreetAddress,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$PostalCode,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$UserPrincipalName,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [SecureString]$SecurePassword,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [bool]$ForcePasswordChange,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [bool]$ForcePasswordChangeWithMfa,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [bool]$AccountEnabled,

        [string]$ManagerId = '',

        [string[]]$LicenseId = @(),

        [string[]]$SecurityGroupId = @(),

        [string[]]$DistributionGroupMail = @(),

        [string[]]$TeamsGroupId = @(),

        [string[]]$MailboxAccessWithSendPermission = @()
    )

    Write-Verbose 'Checking if user exists...'
    try {
        $userAccount = Get-MgUser -Filter "UserPrincipalName eq '$($UserPrincipalName)'"
    }
    catch {
        Write-Error "Failed to get user. $($PSItem)"
    }
    if (($userAccount | Measure-Object).Count -gt 1) {
        throw 'Found more than one user.'
    }

    if ($null -eq $userAccount) {
        Write-Verbose "Did not find existing user $($UserPrincipalName)."
    }
    else {
        Write-Warning "Found existing user $($userAccount.UserPrincipalName) ($($userAccount.DisplayName))."
        Read-Host 'Press <Enter> to continue with user configuration or <Ctrl+C> to cancel'
    }

    if ($null -eq $userAccount) {
        Write-Verbose 'Creating user...'
        try {
            $params = @{
                GivenName = $FirstName.Trim()
                Surname = $LastName.Trim()
                DisplayName = ('{0} {1}' -f $FirstName.Trim(), $LastName.Trim())
                Country = $Country.Trim()
                UsageLocation = $UsageLocation.Trim()
                Company = $Company.Trim()
                Department = $Department.Trim()
                JobTitle = $Title.Trim()
                City = $City.Trim()
                PostalCode = $PostalCode.Trim()
                StreetAddress = $StreetAddress.Trim()
                OfficeLocation = $OfficeLocation.Trim()
                MailNickname = $UserPrincipalName.Trim().Split('@')[0]
                UserPrincipalName = $UserPrincipalName.Trim()
                PasswordProfile = @{
                    ForceChangePasswordNextSignIn = $ForcePasswordChange
                    ForceChangePasswordNextSignInWithMfa = $ForcePasswordChange
                    Password = (ConvertFrom-SecureString -SecureString $SecurePassword -AsPlainText)
                }
                AccountEnabled = $Enabled
            }
            New-MgUser @params | Out-Null
        }
        catch {
            throw "Failed to create user. $($PSItem)"
        }

        Start-Sleep -Seconds 5

        try {
            $userAccount = Get-MgUser -Filter "UserPrincipalName eq '$($UserPrincipalName)'"
        }
        catch {
            throw "Failed to get user. $($PSItem)"
        }

        if (($userAccount | Measure-Object).Count -gt 1) {
            throw 'Found more than one user.'
        }
    }

    if (($null -ne $userAccount) -and ($userAccount.UserPrincipalName -eq $UserPrincipalName)) {
        if ([string]::IsNullOrEmpty($ManagerId) -eq $false) {
            Write-Verbose 'Assigning manager...'
            try {
                Set-M365UserManager -UserId $userAccount.Id -ManagerId $ManagerId
            }
            catch {
                Write-Error "Failed to set manager. $($PSItem)"
            }
        }

        if (($LicenseId | Measure-Object).Count -gt 0) {
            Write-Verbose 'Assigning licenses...'
            try {
                Add-M365UserLicense -UserId $userAccount.Id -LicenseId $LicenseId
            }
            catch {
                Write-Error "Failed to assign licenses to user. $($PSItem)"
                Read-Host 'Press <Enter> to continue or <Ctrl+C> to cancel'
            }
        }

        if (($SecurityGroupId | Measure-Object).Count -gt 0) {
            Write-Verbose 'Adding to security groups...'
            try {
                Add-M365GroupMember -UserId $userAccount.Id -GroupId $SecurityGroupId -GroupType 'SecurityGroup'
            }
            catch {
                Write-Error "Failed to add user to security groups. $($PSItem)"
            }
        }

        if ((($DistributionGroupMail | Measure-Object).Count -gt 0) -or
            (($MailboxAccessWithSendPermission | Measure-Object).Count -gt 0)) {
            Write-Verbose 'Fetching user mailbox...'
            try {
                $params = @{
                    UserPrincipalName = $userAccount.UserPrincipalName
                    MaximumAttempts = 3
                    RetryIntervalSeconds = 60
                }
                $userMailbox = Get-UserMailbox @params
            }
            catch {
                throw "Failed to get user mailbox. $($PSItem)"
            }
        }

        if (($DistributionGroupMail | Measure-Object).Count -gt 0) {
            Write-Verbose 'Adding to distribution groups...'
            try {
                Add-M365GroupMember -UserId $userMailbox.Id -GroupId $DistributionGroupMail -GroupType 'DistributionGroup'
            }
            catch {
                Write-Error $PSItem
            }
        }

        if (($TeamsGroupId | Measure-Object).Count -gt 0) {
            Write-Verbose 'Adding to Teams groups...'
            try {
                Add-M365GroupMember -UserId $userAccount.Id -GroupId $TeamsGroupId -GroupType 'TeamsGroup'
            }
            catch {
                Write-Error "Failed to add user to Teams groups. $($PSItem)"
            }
        }
        
        if (($MailboxAccessWithSendPermission | Measure-Object).Count -gt 0) {
            Write-Verbose 'Assigning mailbox permissions...'
            try {
                $MailboxAccessWithSendPermission | ForEach-Object {
                    $params = @{
                        UserPrincipalName = $userAccount.UserPrincipalName
                        MailboxId = $_
                        SendAsPermission = $true
                        AutoMapping = $true
                    }
                    Add-M365MailboxPermission @params
                }
            }
            catch {
                Write-Error "Failed to assign mailbox permissions for user. $($PSItem)"
            }
        }
    }
    else {
        Write-Error "Cannot find user $($UserPrincipalName)."
        Read-Host 'Press <Enter> to continue anyway or <Ctrl+C> to cancel'
    }
}

#endregion

Import-Module -Name 'Microsoft.Graph.Users', 'Microsoft.Graph.Sites' -ErrorAction Stop

# Connect to online services.
Write-Verbose 'Connecting to online services...'
if (($null -ne $Organization) -and ($null -ne $TenantId) -and ($null -ne $AppClientId) -and ($null -ne $AppCertificateThumbprint)) {
    # Connect to Microsoft online services using a registered Entra app.
    try {
        $params = @{
            TenantId = $TenantId
            ClientId = $AppClientId
            CertificateThumbprint = $AppCertificateThumbprint
            NoWelcome = $true
        }
        Connect-MgGraph @params
    }
    catch {
        throw "Failed to connect to Microsoft Graph. $PSItem"
    }

    try {
        $params = @{
            Organization = $Organization
            AppId = $AppClientId
            CertificateThumbprint = $AppCertificateThumbprint
            ShowBanner = $false
        }
        Connect-ExchangeOnline @params
    }
    catch {
        throw "Failed to connect to Exchange Online. $PSItem"
    }
}
else {
    Write-Warning "Not using Entra app to authenticate because Organization, TenantId, AppClientId, or AppCertificateThumbprint are null. Using interactive sign-in instead."

    # Connect to Microsoft online services using interactive sign-in.
    try {
        Connect-MgGraph -NoWelcome
    }
    catch {
        throw "Failed to connect to Microsoft Graph. $PSItem"
    }
    try {
        Connect-ExchangeOnline -ShowBanner:$false
    }
    catch {
        throw "Failed to connect to Exchange Online. $PSItem"
    }
}

$newUserParams = @{
    FirstName = $FirstName
    LastName = $LastName
    Department = $Department
    Title = $JobTitle
    Company = $Company
    OfficeLocation = $OfficeLocation
    Country = $Country
    UsageLocation = $UsageLocation
    City = $City
    StreetAddress = $StreetAddress
    PostalCode = $PostalCode
    UserPrincipalName = $UserPrincipalName
    SecurePassword = (ConvertTo-SecureString -String $SecurePassword -AsPlainText)
    ForcePasswordChange = $ForcePasswordChange
    ForcePasswordChangeWithMfa = $ForcePasswordChangeWithMfa
    AccountEnabled = $Enabled
    ManagerId = $ManagerId
    LicenseId = $LicenseId
    SecurityGroupId = $SecurityGroupId
    DistributionGroupMail = $DistributionGroupMail
    TeamsGroupId = $TeamsGroupId
    MailboxAccessWithSendPermission = $MailboxAccessWithSendPermission
}
$newUserParams | Format-List
Read-Host ('Press <Enter> to begin user creation/configuration for "{0}" or <Ctrl+C> to cancel' -f $UserPrincipalName)

if ($null -ne $userSettings.Microsoft365) {
    New-Microsoft365User @newUserParams
}

Write-Verbose 'Disconnecting from MS Graph...'
try {
    Disconnect-MgGraph | Out-Null
}
catch {
    Write-Error "Failed to disconnect from Microsoft Graph. $PSItem"
}

Write-Verbose 'Disconnecting from Exchange Online...'
try {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}
catch {
    Write-Error "Failed to disconnect from Exchange Online. $PSItem"
}