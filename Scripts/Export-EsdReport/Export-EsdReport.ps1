<#PSScriptInfo

.VERSION 1.0.0

.GUID 43f3828a-ee58-416c-8501-68ac79ce222b

.AUTHOR Martin Olsson

.COMPANYNAME Martin Olsson

.COPYRIGHT (c) Martin Olsson. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES ImportExcel

.RELEASENOTES


.PRIVATEDATA

#>

<#
.DESCRIPTION
Create an ESD report based on a list of Entra users, with option to send the report by email.

.EXAMPLE
Here's an example configuration file (Export-EsdReport-Config.psd1).

@{
    # Log settings.
    Log = @{
        DirectoryPath = '\\server\esd\logs'
        FileRetentionDays = 0 # 0 = unlimited.
    }

    # ESD data settings.
    Data = @{
        DirectoryPath = 'C:\Users\Username\Documents\Scripts\Export-EsdReport\data'
        City = 'City Name'
        ConvertAccessCardNumberToRfid = $true
        DatabaseFileRetentionCount = 10 # Number of exported database files to keep before deleting old ones. 0 = unlimited.
        UsersFileRetentionCount = 10 # Number of exported users files to keep before deleting old ones. 0 = unlimited.
    }

    # Microsoft 365 registered app settings.
    MailApp = @{
        TenantId = '11f1e7f7-da47-4c86-8bd6-6e662cbd770d'
        ClientId = '69963dab-127d-44d9-9d73-45bd068a7e61' # MsGraph-Mail
        CertificateThumbprint = 'D6A39E112D7D4CE7999E8F3D05DD4D86'
    }

    # Database settings.
    Database = @{
        FilePath = 'C:\dataterm\data\dataterm.db'
        SqliteExecutablePath = 'C:\sqlite\sqlite3.exe'
    }

    # Report settings.
    Report = @{
        DirectoryPath = '\\server\esd\reports'
        FileRetentionCount = 13 # Number of exported report files to keep before deleting old ones. 0 = unlimited.
        Title = 'ESD test report'
        DateFormat = 'yyyy-MM-dd'
        TemplatePaths = @{
            MainReportHeader = 'C:\Users\Username\Documents\Scripts\Export-EsdReport\templates\MainReportHeader.html'
            MainReportFooter = 'C:\Users\Username\Documents\Scripts\Export-EsdReport\templates\MainReportFooter.html'
            DepartmentReportHeader = 'C:\Users\Username\Documents\Scripts\Export-EsdReport\templates\DepartmentReportHeader.html'
            DepartmentReportFooter = 'C:\Users\Username\Documents\Scripts\Export-EsdReport\templates\DepartmentReportFooter.html'
        }
        SenderMailAddress = 'service.account@mydomain.com'
        MainRecipientMailAddress = 'esd.auditor@mydomain.com'
        DepartmentReports = @{
            Departments = @(
                @{ Name = 'Department A'; MailAddress = 'department.a@mydomain.com' }
                @{ Name = 'Department B'; MailAddress = 'department.b@mydomain.com' }
                @{ Name = 'Department C'; MailAddress = 'department.c@mydomain.com' }
            )
            ExcludedJobTitles = @('Department Head')
        }
    }
}
#>

#Requires -Version 7.0
#Requires -Modules ImportExcel, Microsoft.Graph.Users, Microsoft.Graph.Users.Actions

param(
    [ValidateScript({
        if (Test-Path -Path $_ -PathType Leaf) { return $true }
        else { throw [System.IO.FileNotFoundException] "Cannot find the file '$_'." }
    })]
    [string]$ConfigurationPath = (Join-Path -Path $PSScriptRoot -ChildPath 'Export-EsdReport-Config.psd1'),

    [ValidateNotNull()]
    [DateTime]$FromDate = (Get-Date).AddDays(-7).Date,

    [ValidateNotNull()]
    [DateTime]$ToDate = (Get-Date).AddDays(-1).Date,

    [switch]$SendMail,

    [switch]$Force
)

#region Functions

function Write-ScriptLogEntry {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Message,

        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Warning', 'Error', 'Critical')]
        [string]$Classification,

        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path (Split-Path -Path $_ -Parent) -PathType Container) { return $true }
            else { throw [System.IO.DirectoryNotFoundException] "Cannot find the parent directory of file '$_'." }
        })]
        [string]$FilePath
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = '[{0}] [{1}] {2}' -f $timestamp, $Classification.ToUpper(), $Message
    $logEntry | Out-File -Path $FilePath -Append -ErrorAction Continue

    switch ($Classification) {
        'Info' { Write-Verbose $Message }
        'Warning' { Write-Warning $Message }
        'Error' { Write-Error $Message }
        'Critical' { throw $Message }
    }
}

function ConvertTo-ScriptAccessCardRfid {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$CardNumber
    )

    # Settings.
    $cardLength = 10
    $rfidLength = 10
    $binaryNumberLength = 32
    $binaryPartBits = 4
    $binaryPartCount = ($binaryNumberLength / $binaryPartBits) # 8
    $binaryNumber = [Convert]::ToString($CardNumber, 2)
    $invertedBinaryPartsOrder = @(1, 0, 3, 2, 5, 4, 7, 6)

    # Lists.
    $binaryParts = New-Object -TypeName System.Collections.ArrayList
    $binaryPartsInverted = New-Object -TypeName System.Collections.ArrayList

    # Prefix the binary number with 0s to increase number length to 32.
    if ($binaryNumber.Length -lt $binaryNumberLength) {
        for ($i = 0; $i -le ($binaryNumberLength - $binaryNumber.Length); $i++) {
            $binaryNumber = '0' + $binaryNumber
        }
    }

    # Add binary parts to list.
    for ($i = 0; $i -lt ([Math]::Floor($binaryNumber.Length / $binaryPartBits)); $i++) {
        $binaryParts.Add($binaryNumber.Substring($i * $binaryPartBits, $binaryPartBits)) | Out-Null
    }

    # Prefix the binary part list with 0s to increase length to 8.
    if ($binaryParts.Count -lt $binaryPartCount) {
        for ($i = 0; $i -lt ($binaryPartCount - $binaryParts.Count); $i++) {
            $binaryParts.Insert(0, '0000')
        }
    }

    # Invert binary parts (example: 1010 0011 -> 0011 1010).
    foreach ($index in $invertedBinaryPartsOrder) {
        $binaryPartsInverted.Add($binaryParts[$index]) | Out-Null
    }

    # Invert binary bits (example: 1010 0011 -> 0101 1100).
    $processedBinaryNumber = ''
    for ($i = 0; $i -lt $binaryPartsInverted.Count; $i++) {
        $bin = $binaryPartsInverted[$i]
        $processedBinaryNumber += $bin[3]
        $processedBinaryNumber += $bin[2]
        $processedBinaryNumber += $bin[1]
        $processedBinaryNumber += $bin[0]
    }

    # Convert binary to decimal.
    $processedDecimalNumber = [Convert]::ToInt32($processedBinaryNumber, 2)

    # Convert decimal to HEX.
    $processedHexNumber = $processedDecimalNumber.ToString('X')

    # Prefix HEX number with 0s to increase length to 8.
    if ($processedHexNumber.Length -lt $binaryPartCount) {
        for ($i = 0; $i -lt ($binaryPartCount - $processedHexNumber.Length); $i++) {
            $processedHexNumber = '0' + $processedHexNumber
        }
    }

    # Prefix HEX with an RFID number to be able to use it for the ESD device.
    $defaultBeginningCardNumber = '3'
    $prefixHexNumber = ''
    if (($CardNumber.Length -ge $cardLength) -and (($CardNumber.StartsWith($defaultBeginningCardNumber)))) {
        $prefixHexNumber = '0F'
    }
    else {
        $prefixHexNumber = '01'
    }

    $processedHexNumber = $prefixHexNumber + $processedHexNumber
    $rfid = $processedHexNumber
    if ($rfid.Length -ne $rfidLength) {
        Write-Error "Invalid length $($rfid.Length) (should be $rfidLength) for RFID $rfid."
        $rfid = $null
    }

    return $rfid
}

function Export-ScriptEsdData {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path (Split-Path -Path $_) -PathType Container) { return $true }
            else { throw [System.IO.DirectoryNotFoundException] "Cannot find parent directory of the file '$($_)'." }
        })]
        [string]$ExportFilePath,

        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Leaf) { return $true }
            else { throw [System.IO.FileNotFoundException] "Cannot find the file '$($_)'." }
        })]
        [string]$DatabaseFilePath,

        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Leaf) { return $true }
            else { throw [System.IO.FileNotFoundException] "Cannot find the file '$($_)'." }
        })]
        [string]$DatabaseExecutablePath,

        [ValidateNotNull()]
        [string]$DatabaseQuery = 'SELECT * FROM measdata;',

        [ValidateNotNull()]
        [string]$DatabaseEncodingStandard = '65001'
    )

    # Export database to a CSV file.
    try {
        $commandString = 'chcp {0} && "{1}" -header -csv "{2}" "{3}" > {4}' -f $DatabaseEncodingStandard, $DatabaseExecutablePath, $DatabaseFilePath, $DatabaseQuery, $ExportFilePath
        cmd.exe /c $commandString | Out-Null
    }
    catch {
        throw "Failed to export database. $PSItem"
    }

    return $true
}

function Export-ScriptReportFile {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject[]]$UserTestResults,

        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path (Split-Path -Path $_ -Parent) -PathType Container) { return $true }
            else { throw [System.IO.DirectoryNotFoundException] "Cannot find parent directory of the file '$($_)'." }
        })]
        [string]$FilePath
    )

    begin {}

    process {
        try {
            # Set the cell style for worksheet 1.
            $params = @{
                Range = "A1:E$($($UserTestResults | Measure-Object).Count + 1)"
                BackgroundColor = ([System.Drawing.Color]::FromArgb(37, 120, 183))
                BorderColor = ([System.Drawing.Color]::FromArgb(175, 175, 175))
                BorderTop = 'Thin'
                BorderBottom = 'Thin'
                BorderLeft = 'Thin'
                BorderRight = 'Thin'
            }
            $style = New-ExcelStyle @params
            
            # Save user results (worksheet 1) to the report file.
            $properties = @(
                @{ Name = 'Name'; Expression = { $_.Name } }
                @{ Name = 'Department'; Expression = { $_.Department } }
                @{ Name = 'Title'; Expression = { $_.Title } }
                @{ Name = 'Successful days'; Expression = { $_.DaysPassed } }
                @{ Name = 'Total days'; Expression = { $_.DaysTested } }
            )
            $params = @{
                Path = $FilePath
                WorksheetName = 'Aggregation'
                TableName = 'Aggregation'
                AutoSize = $true
                BoldTopRow = $true
                Style = $style
            }
            $UserTestResults | Select-Object -Property $properties | Sort-Object -Property Namn, Avdelning | Export-Excel @params
            
            # Set the cell style for worksheet 2.
            $properties = @(
                @{ Name = 'Timestamp'; Expression = { Get-Date -Date $_.DateTime -Format "yyyy-MM-dd HH:mm:ss" } }
                @{ Name = 'Name'; Expression = { $_.Name } }
                @{ Name = 'Department'; Expression = { $_.Department } }
                @{ Name = 'ID'; Expression = { $_.ID } }
                @{ Name = 'Message'; Expression = { $_.Message } }
                @{ Name = 'Code'; Expression = { $_.Code } }
                @{ Name = 'Left shoe (MΩ)'; Expression = { [Math]::Round($_.LeftShoe / 1000, 2) } } # Convert to Mega-Ohm by dividing with 1000.
                @{ Name = 'Right shoe (MΩ)'; Expression = { [Math]::Round($_.RightShoe / 1000, 2) } } # Convert to Mega-Ohm by dividing with 1000.
                @{ Name = 'Wrist strap (MΩ)'; Expression = { [Math]::Round($_.WristStrap / 1000, 2) } } # Convert to Mega-Ohm by dividing with 1000.
            )
            $params = @{
                Range = "A1:I$(($UserTestResults.Results | Measure-Object).Count + 1)"
                BackgroundColor = ([System.Drawing.Color]::FromArgb(37, 120, 183))
                BorderColor = ([System.Drawing.Color]::FromArgb(175, 175, 175))
                BorderTop = 'Thin'
                BorderBottom = 'Thin'
                BorderLeft = 'Thin'
                BorderRight = 'Thin'
            }
            $style = New-ExcelStyle @params
        
            # Save test results (worksheet 2) to the report file.
            $params = @{
                Path = $FilePath
                WorksheetName = 'Test result'
                TableName = 'Test result'
                AutoSize = $true
                BoldTopRow = $true
                Style = $style
            }
            $UserTestResults.Results | Select-Object -Property $properties | Sort-Object -Property Tidpunkt | Export-Excel @params
            
            $excel = Open-ExcelPackage -Path $FilePath
        
            # Add conditional formatting to both worksheets.
            if (($UserTestResults | Measure-Object).Count -gt 0) {
                # No results.
                $params = @{
                    Worksheet = $excel.Workbook.Worksheets[1]
                    Range = "A2:E$(($UserTestResults | Measure-Object).Count + 1)"
                    ConditionValue = '=AND($A2<>"",$E2="")'
                    RuleType = 'Expression'
                    BackgroundColor = ([System.Drawing.Color]::FromArgb(224, 224, 224))
                }
                Add-ConditionalFormatting @params
        
                # Failed one or more days.
                $params = @{
                    Worksheet = $excel.Workbook.Worksheets[1]
                    Range = "A2:E$(($UserTestResults | Measure-Object).Count + 1)"
                    ConditionValue = '=$D2<$E2'
                    RuleType = 'Expression'
                    BackgroundColor = ([System.Drawing.Color]::FromArgb(255, 190, 190))
                }
                Add-ConditionalFormatting @params
        
                # Passed all days.
                $params = @{
                    Worksheet = $excel.Workbook.Worksheets[1]
                    Range = "A2:E$(($UserTestResults | Measure-Object).Count + 1)"
                    ConditionValue = '=$D2=$E2'
                    RuleType = 'Expression'
                    BackgroundColor = ([System.Drawing.Color]::FromArgb(169, 255, 167))
                }
                Add-ConditionalFormatting @params
                
                if (($UserTestResults.Results | Measure-Object).Count -gt 0) {
                    # Pass.
                    $params = @{
                        Worksheet = $excel.Workbook.Worksheets[2]
                        Range = "A2:I$(($UserTestResults.Results | Measure-Object).Count + 1)"
                        ConditionValue = '=$E2="OK"'
                        RuleType = 'Expression'
                        BackgroundColor = ([System.Drawing.Color]::FromArgb(169, 255, 167))
                    }
                    Add-ConditionalFormatting @params
        
                    # Fail.
                    $params = @{
                        Worksheet = $excel.Workbook.Worksheets[2]
                        Range = "A2:I$(($UserTestResults.Results | Measure-Object).Count + 1)"
                        ConditionValue = '=$E2<>"OK"'
                        RuleType = 'Expression'
                        BackgroundColor = ([System.Drawing.Color]::FromArgb(255, 190, 190))
                    }
                    Add-ConditionalFormatting @params
                }
            }
            
            $excel.Save()
        }
        catch {
            throw "Failed to export the report file '$FilePath'. $PSItem"
        }
    }

    end {
        return $FilePath
    }
}

function Get-ScriptEntraUsers {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$FilterCity,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [bool]$ConvertAccessCardNumberToRfid
    )

    $returnUserList = [PSCustomObject]@()

    try {
        $properties = @(
            'DisplayName'
            'Department'
            'JobTitle'
            'City'
            'AccountEnabled'
            'CustomSecurityAttributes'
        )
        $userList = Get-MgUser -Filter "City eq '$($FilterCity)'" -Property $properties -ErrorAction Stop | Where-Object { $_.AccountEnabled -eq $true }
    }
    catch {
        throw "Failed to get users. $PSItem"
    }

    $userList | ForEach-Object {
        try {
            $accessCardNumber = $_.CustomSecurityAttributes.AdditionalProperties.AccessControl.AccessCardNumber
            
            if (-not [string]::IsNullOrWhiteSpace($accessCardNumber)) {
                if ($ConvertAccessCardNumberToRfid -eq $true) {
                    $accessCardNumber = ConvertTo-ScriptAccessCardRfid -CardNumber $accessCardNumber
                }

                $returnUserList += [PSCustomObject][Ordered]@{
                    'ID' = $accessCardNumber
                    'Name' = $_.DisplayName
                    'Department' = $_.Department
                    'Title' = $_.JobTitle
                }
            }
        }
        catch {
            Write-Error "Failed to add ESD user to list. $PSItem"
        }
    }

    return $returnUserList
}

function Get-ScriptUserTestResults {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Leaf) { return $true }
            else { throw [System.IO.FileNotFoundException] "Cannot find the file '$($_)'." }
        })]
        [string]$TestDataFilePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject[]]$UserList,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [DateTime]$StartDate,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [DateTime]$EndDate
    )

    begin {
        $esdData = Import-Csv -Path $TestDataFilePath -Delimiter ',' | Where-Object { (Get-Date -Date $_.datetime).Date -ge $StartDate -and (Get-Date -Date $_.datetime).Date -lt $EndDate }
        $groupedEsdData = $esdData | Where-Object { -not [string]::IsNullOrEmpty($_.userid) } | Group-Object -Property userid
        $returnResults = [PSCustomObject]@()
    }

    process {
        foreach ($userData in $groupedEsdData) {
            $userId = $userData.Name
            $user = ($UserList | Where-Object { $_.ID -eq $userId })
        
            if (-not [string]::IsNullOrEmpty($user.ID)) {
                # Total pass/fail count.
                $passCount = ($userData | Select-Object -ExpandProperty Group | Select-Object -Property msg | Where-Object { $_.msg -eq 'OK' } | Measure-Object).Count
                $failCount = ($userData | Select-Object -ExpandProperty Group | Select-Object -Property msg | Where-Object { $_.msg -ne 'OK' } | Measure-Object).Count
        
                # Get unique test result dates.
                $uniqueDates = (
                    $userData |
                    Select-Object -ExpandProperty Group |
                    Select-Object -Property @{ Name = 'DateTime'; Expression = { Get-Date -Date $_.datetime -Format 'yyyy-MM-dd' } } -Unique
                )
        
                # For each day, count the number of times the last test was a failure.
                $passDayCount = 0
                $failDayCount = 0
                $daysTested = 0
                foreach ($date in $uniqueDates) {
                    $daysTested++
                    $testResults = (
                        $userData |
                        Select-Object -ExpandProperty Group |
                        Select-Object -Property msg, datetime |
                        Where-Object { (Get-Date -Date $_.datetime -Format 'yyyy-MM-dd') -eq $date.DateTime }
                    )
                    $lastTestResult = $testResults | Sort-Object $_.datetime -Bottom 1
                    $isLastTestResultPass = ($lastTestResult.msg -eq 'OK')
                    if ($isLastTestResultPass -eq $true) {
                        $passDayCount++
                    }
                    else {
                        $failDayCount++
                    }
                }
        
                # Build the user test results object.
                $userTestResults = [PSCustomObject]@()
                $userData | Select-Object -ExpandProperty Group | ForEach-Object {
                    $userTestResults += [PSCustomObject]@{
                        'DateTime' = $_.datetime
                        'Name' = $_.username
                        'Department' = $user.Department
                        'ID' = $_.userid
                        'Message' = $_.msg
                        'Code' = $_.erg
                        'LeftShoe' = $_.rsl # Kilo-Ohm
                        'RightShoe' = $_.rsr # Kilo-Ohm
                        'WristStrap' = $_.rhg # Kilo-Ohm
                        'FootWearSeries' = $_.rsg
                        'Humidity' = $_.hum
                    }
                }
        
                # Add the user to the return results.
                $returnResults += [PSCustomObject]@{
                    ID = $user.ID
                    Name = $user.Name
                    Department = $user.Department
                    Title = $user.Title
                    DaysPassed = $passDayCount
                    DaysFailed = $failDayCount
                    DaysTested = $daysTested
                    TotalPassedTests = $passCount
                    TotalFailedTests = $failCount
                    Results = $userTestResults
                }
            }
        }
        
        # Also add users without test results to the return results.
        foreach ($user in $UserList) {
            $userExistsInReturnResults = ($returnResults | Where-Object { $_.ID -eq $user.ID } | Measure-Object).Count -gt 0
            if ($userExistsInReturnResults -eq $false) {
                $returnResults += [PSCustomObject]@{
                    ID = $user.ID
                    Name = $user.Name
                    Department = $user.Department
                    Title = $user.Title
                    DaysFailed = $null
                    FailedDays = $null
                    DaysTested = $null
                    TotalPassedTests = $null
                    TotalFailedTests = $null
                    Results = $null
                }
            }
        }
    }

    end {
        return $returnResults
    }
}

function Send-ScriptMail {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$EntraTenantId,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$EntraAppClientId,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$EntraAppCertificateThumbprint,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$SenderMailAddress,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$RecipientMailAddress,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Subject,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$BodyContent,

        [string[]]$AttachmentFilePath
    )

    begin {
        $recipientParams = @()
        $attachmentParams = @()
    }

    process {
        # Add recipients.
        $RecipientMailAddress | ForEach-Object {
            if (-not [string]::IsNullOrWhiteSpace($_)) {
                $recipientParams += @{ EmailAddress = @{ Address = $_ } }
            }
        }
    
        if (($recipientParams | Measure-Object).Count -gt 0) {
            # Include attachments.
            try {
                foreach ($filePath in $AttachmentFilePath) {
                    if (Test-Path -Path $filePath -PathType Leaf) {
                        $encodedAttachment = [Convert]::ToBase64String((Get-Content -Path $filePath -AsByteStream))
                        $attachmentParams = @(
                            @{
                                "@odata.type" = "#microsoft.graph.fileAttachment"
                                Name = (Split-Path -Path $filePath -Leaf)
                                ContentBytes = $encodedAttachment
                            }
                        )
                    }
                    else {
                        Write-Error ('Unable to find attachment file path "{0}".' -f $filePath)
                    }
                }
            }
            catch {
                throw "Failed to attach files. $PSItem"
            }
        
            # Send mail.
            try {
                $params = @{
                    Message = @{
                        Subject = $Subject
                        Body = @{
                            ContentType = 'HTML'
                            Content = $BodyContent
                        }
                        ToRecipients = $recipientParams
                        Attachments = $attachmentParams
                    }
                    SaveToSentItems = 'false'
                }
                if (Send-MgUserMail -UserId $SenderMailAddress -BodyParameter $params) {
                    Write-Verbose ('Sent report mail to "{0}".' -f $params.ToRecipients)
                }
            }
            catch {
                throw "Failed to send mail. $PSItem"
            }
        }
    }

    end {
        return $true
    }
}

function Get-DepartmentResults {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$DepartmentList
    )

    $resultList = [PSCustomObject]@()

    foreach ($department in $DepartmentList) {
        $testedPeopleCount = 0
        $successfulPeopleCount = 0
        $successfulTestDays = 0
        $totalTestDays = 0
        $departmentResults = $userTestResults | Where-Object { $_.Department -eq $department }
        $testedPeople = $departmentResults | Select-Object -Property Name -Unique
        $testedPeopleCount = ($departmentResults | Where-Object { $_.DaysTested -gt 0 } | Select-Object -Property Name -Unique | Measure-Object).Count
        $totalPeopleCount = ($testedPeople | Measure-Object).Count

        foreach ($person in $testedPeople.Name) {
            foreach ($result in ($departmentResults | Where-Object { $_.Name -eq $person })) {
                if ($result.DaysTested -gt 0 -and $result.DaysFailed -eq 0) {
                    $successfulPeopleCount += 1
                }
                $successfulTestDays += $result.DaysPassed
                $totalTestDays += $result.DaysTested
            }
        }

        $successfulTestDaysPercentage = 0
        if ($totalTestDays -gt 0) {
            $successfulTestDaysPercentage = [Math]::Round((($successfulTestDays / $totalTestDays * 100)), 1)
        }

        $resultList += [PSCustomObject]@{
            Department = $department
            TestedPeopleCount = $testedPeopleCount
            SuccessfulPeopleCount = $successfulPeopleCount
            SuccessfulTestDaysPercentage = $successfulTestDaysPercentage
            TotalPeopleCount = $totalPeopleCount
        }
    }

    return $resultList
}

function Get-MainReportHtml {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Results,

        $DepartmentReportConfiguration,

        [string]$HeaderHtmlFilePath,

        [string]$FooterHtmlFilePath
    )

    $reportHtml = [System.String]""
    $fromDateString = (Get-Date -Date $FromDate).ToShortDateString()
    $toDateString = (Get-Date -Date $ToDate).ToShortDateString()
    $weekNumber = (Get-Date -Date $FromDate -UFormat '%V') -as [int]

    # Header.
    if ((-not [string]::IsNullOrEmpty($HeaderHtmlFilePath)) -and (Test-Path -Path $HeaderHtmlFilePath)) {
        $fileContent = Get-Content -Path $HeaderHtmlFilePath
        $reportHtml += ($fileContent -f $weekNumber, $fromDateString, $toDateString)
    }

    # Build the table HTML.
    $tableHtml = @"
<style>
table { border: solid; border-width: 1px; border-collapse: collapse; }
tr { border: solid; border-width: 1px; border-color: #000000; }
th { padding: 3px; background-color: #f3f3f3; border: solid; border-width: 1px; border-color: #000000; }
td { padding: 3px; background-color: #fefefe; border: solid; border-width: 1px; border-color: #000000; }
.passed { color: #00aa00; font-weight: bold; }
.failed { color: #ff0000; font-weight: bold; }
.nodata { color: #777777; }
.sendmail-yes { color: #000000; font-weight: normal; }
.sendmail-no { color: #777777; font-weight: normal; }
</style>
"@

    $tableHtml += "<table><th>Department</th><th>People with test results</th><th>Successful days</th><th>Send mail</th>"

    $properties = @(
        @{ Name = 'Department'; Expression = { $_.Department } }
        @{ Name = 'People with test results'; Expression = { '{0} / {1}' -f $_.TestedPeopleCount, $_.TotalPeopleCount } }
        @{ Name = 'Successful days'; Expression = { if ($_.TestedPeopleCount -gt 0) { '{0} %' -f $_.SuccessfulTestDaysPercentage } else { '-' } } }
    )

    foreach ($row in $Results | Select-Object -Property $properties) {
        $department = $row.'Department'
        $peopleWithResults = $row.'People with test results'
        $daysPassedPercentage = $row.'Successful days'
        $sendMailToDepartment = -not [string]::IsNullOrEmpty(($DepartmentReportConfiguration.Departments | Where-Object { $_.Name -eq $row.'Department' }).MailAddress)

        $className = ''
        if ($daysPassedPercentage -eq '-') {
            $className = 'nodata'
        }
        elseif ($daysPassedPercentage -eq '100 %') {
            $className = 'passed'
        }
        else {
            $className = 'failed'
        }

        $sendMailHtml = ''
        if ($sendMailToDepartment -eq $true) {
            $sendMailHtml = '<td class="sendmail-yes">Yes</td>'
        }
        else {
            $sendMailHtml = '<td class="sendmail-no">-</td>'
        }

        $tableHtml += '<tr class="{0}"><td>{1}</td><td>{2}</td><td>{3}</td>{4}</tr>' -f $className, $department, $peopleWithResults, $daysPassedPercentage, $sendMailHtml
    }

    $tableHtml += "</table>"
    
    # Table.
    $reportHtml += $tableHtml
    
    # Footer.
    if ((-not [string]::IsNullOrEmpty($FooterHtmlFilePath)) -and (Test-Path -Path $FooterHtmlFilePath)) {
        $fileContent = Get-Content -Path $FooterHtmlFilePath
        $reportHtml += $fileContent
    }

    return $reportHtml
}

function Get-DepartmentReportHtml {
    param(
        [Parameter(Mandatory)]
        $ReportData,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$DepartmentName,

        [string[]]$ExcludedJobTitles,

        [string]$HeaderHtmlFilePath,

        [string]$FooterHtmlFilePath
    )

    $reportHtml = [System.String]""
    $weekNumber = (Get-Date -Date $FromDate -UFormat '%V') -as [int]

    # Header.
    if ((-not [string]::IsNullOrEmpty($HeaderHtmlFilePath)) -and (Test-Path -Path $HeaderHtmlFilePath)) {
        $fileContent = Get-Content -Path $HeaderHtmlFilePath
        $reportHtml += ($fileContent -f $DepartmentName, $weekNumber)
    }

    # Build table HTML.
    $tableHtml = @"
<style>
table { border: solid; border-width: 1px; border-collapse: collapse; }
tr { border: solid; border-width: 1px; border-color: #000000; }
th { padding: 3px; background-color: #f3f3f3; border: solid; border-width: 1px; border-color: #000000; }
td { padding: 3px; background-color: #fefefe; border: solid; border-width: 1px; border-color: #000000; }
.passed { color: #00aa00; font-weight: bold; }
.failed { color: #ff0000; font-weight: bold; }
.nodata { color: #777777; }
</style>
"@
    $tableHtml += "<table><th>Name</th><th>Successful days</th><th>Total days</th>"

    $departmentReportData = $exportedEsdReport | Where-Object { $_.'Avdelning' -eq $departmentName }
    $departmentReportData = $departmentReportData | Where-Object { $_.'Titel' -notin $ExcludedJobTitles }
    
    foreach ($row in $departmentReportData) {
        $name = $row.'Name'
        $daysPassed = $row.'Successful days'
        $totalDays = $row.'Total days'

        $className = ''
        if (($null -eq $totalDays) -or ($totalDays -eq 0)) {
            $className = 'nodata'
        }
        elseif ($daysPassed -eq $totalDays) {
            $className = 'passed'
        }
        elseif ($daysPassed -lt $totalDays) {
            $className = 'failed'
        }

        $tableHtml += '<tr class="{0}">' -f $className
        $tableHtml += '<td>{0}</td><td>{1}</td><td>{2}</td>' -f $name, $daysPassed, $totalDays
        $tableHtml += "</tr>"
    }

    $tableHtml += "</table>"

    # Table.
    $reportHtml += $tableHtml

    # Footer.
    if ((-not [string]::IsNullOrEmpty($FooterHtmlFilePath)) -and (Test-Path -Path $FooterHtmlFilePath)) {
        $fileContent = Get-Content -Path $FooterHtmlFilePath
        $reportHtml += $fileContent
    }

    return $reportHtml
}

#endregion

# Validate that the FromDate parameter date is less than or equal to ToDate parameter date.
if ($FromDate -gt $ToDate) {
    $logMessage = ('FromDate parameter date ({0}) cannot be greater than ToDate parameter date ({1}).' -f $FromDate.ToShortDateString(), $ToDate.ToShortDateString())
    Write-ScriptLogEntry -Message $logMessage -Classification Critical @logParams
}

# Validate that the FromDate parameter date is on a Monday.
if (((Get-Date -Date $FromDate).DayOfWeek -ne 'Monday') -and (-not $Force)) {
    Write-ScriptLogEntry -Message ('FromDate parameter date ({0}) must be on a Monday.' -f $FromDate.ToShortDateString()) -Classification Critical
}

# Load configuration file.
$Configuration = Import-PowerShellDataFile -Path $ConfigurationPath -ErrorAction Stop

# Log settings.
$logParams = @{ FilePath = Join-Path -Path $Configuration.Log.DirectoryPath -ChildPath ('{0}.log' -f (Get-Date -Format 'yyyy-MM-dd_HHmmss')) }

# Create required folders if they don't already exist.
if (-not (Test-Path -Path $Configuration.Log.DirectoryPath)) {
    try {
        New-Item -Path $Configuration.Log.DirectoryPath -ItemType Directory
        Write-ScriptLogEntry -Message ('Created log directory "{0}".' -f $Configuration.Log.DirectoryPath) -Classification Info @logParams
    }
    catch {
        throw "Failed to create log directory. $PSItem"
    }
}
if (-not (Test-Path -Path $Configuration.Data.DirectoryPath)) {
    try {
        New-Item -Path $Configuration.Data.DirectoryPath -ItemType Directory
        Write-ScriptLogEntry -Message ('Created data directory "{0}".' -f $Configuration.Data.DirectoryPath) -Classification Info @logParams
    }
    catch {
        Write-ScriptLogEntry -Message "Failed to create data directory. $PSItem" -Classification Critical @logParams
    }
}
if (-not (Test-Path -Path $Configuration.Report.DirectoryPath)) {
    try {
        New-Item -Path $Configuration.Report.DirectoryPath -ItemType Directory
        Write-ScriptLogEntry -Message ('Created report directory "{0}".' -f $Configuration.Report.DirectoryPath) -Classification Info @logParams
    }
    catch {
        Write-ScriptLogEntry -Message "Failed to create report directory. $PSItem" -Classification Critical @logParams
    }
}

try {
    $params = @{
        TenantId = $Configuration.MailApp.TenantId
        ClientId = $Configuration.MailApp.ClientId
        CertificateThumbprint = $Configuration.MailApp.CertificateThumbprint
        NoWelcome = $true
        ErrorAction = 'Stop'
    }
    Connect-MgGraph @params
}
catch {
    Write-ScriptLogEntry -Message "Failed to connect to Microsoft Graph. $PSItem" -Classification Error @logParams
}

# Export ESD database data.
try {
    $databaseExportFilename = '{0}_{1}.csv' -f 'results', (Get-Date -Format 'yyyy-MM-dd')
    $databaseExportFilePath = Join-Path -Path $Configuration.Data.DirectoryPath -ChildPath $databaseExportFilename

    Write-Verbose ('Exporting ESD data from the database to "{0}".' -f $databaseExportFilePath)
    $params = @{
        ExportFilePath = $databaseExportFilePath
        DatabaseFilePath = $Configuration.Database.FilePath
        DatabaseExecutablePath = $Configuration.Database.SqliteExecutablePath
    }
    if (Export-ScriptEsdData @params) {
        Write-ScriptLogEntry -Message ('Exported ESD data from the database to file "{0}".' -f $databaseExportFilePath) -Classification Info @logParams
    }
}
catch {
    Write-ScriptLogEntry -Message "Failed to export ESD data. $PSItem" -Classification Critical @logParams
}

# Clean up old database export files.
$databaseFiles = Get-ChildItem -Path (Join-Path -Path $Configuration.Data.DirectoryPath -ChildPath 'results_*.csv') | Sort-Object -Property 'CreationTime' -Descending
if (($Configuration.Data.DatabaseFileRetentionCount -gt 0) -and (($databaseFiles | Measure-Object).Count -gt $Configuration.Data.DatabaseFileRetentionCount)) {
    $currentFileIndex = 0
    foreach ($file in $databaseFiles) {
        if ($currentFileIndex -ge $Configuration.Data.DatabaseFileRetentionCount) {
            try {
                $file | Remove-Item -ErrorAction Stop
                Write-ScriptLogEntry -Message ('Deleted database export file "{0}" due to retention configuration.' -f $file.FullName) -Classification Info @logParams
            }
            catch {
                Write-ScriptLogEntry -Message "Failed to delete old database export file. $PSItem" -Classification Warning @logParams
            }
        }
        $currentFileIndex += 1
    }
}

# Generate user list from Microsoft Entra.
$userList = $null
try {
    $userList = Get-ScriptEntraUsers -FilterCity $Configuration.Data.City -ConvertAccessCardNumberToRfid $Configuration.Data.ConvertAccessCardNumberToRfid
}
catch {
    Write-ScriptLogEntry -Message "Failed to get user list from Microsoft Entra. $PSItem" -Classification Critical @logParams
}

# Clean up old users export files.
$usersFiles = Get-ChildItem -Path (Join-Path -Path $Configuration.Data.DirectoryPath -ChildPath 'users_*.csv') | Sort-Object -Property 'CreationTime' -Descending
if (($Configuration.Data.DatabaseFileRetentionCount -gt 0) -and (($usersFiles | Measure-Object).Count -gt $Configuration.Data.DatabaseFileRetentionCount)) {
    $currentFileIndex = 0
    foreach ($file in $usersFiles) {
        if ($currentFileIndex -ge $Configuration.Data.UsersFileRetentionCount) {
            try {
                $file | Remove-Item -ErrorAction Stop
                Write-ScriptLogEntry -Message ('Deleted user export file "{0}" based on retention settings.' -f $file.FullName) -Classification Info @logParams
            }
            catch {
                Write-ScriptLogEntry -Message "Failed to delete old user export file. $PSItem" -Classification Warning @logParams
            }
        }
        $currentFileIndex += 1
    }
}

# Export user list file.
$usersExportFilename = '{0}_{1}.csv' -f 'users', (Get-Date -Format 'yyyy-MM-dd')
$usersExportFilePath = Join-Path -Path $Configuration.Data.DirectoryPath -ChildPath $usersExportFilename
if (($null -ne $userList) -and (($userList | Measure-Object).Count -gt 0)) {
    try {
        $userList | Sort-Object -Property Name | Export-Csv -Path $usersExportFilePath -Delimiter ';' -UseQuotes AsNeeded -ErrorAction Stop
        Write-ScriptLogEntry -Message ('Exported Entra users to file "{0}".' -f $usersExportFilePath) -Classification Info @logParams
    }
    catch {
        Write-ScriptLogEntry -Message ('Failed to export Entra users. {0}' -f $usersExportFilePath, $PSItem) -Classification Critical @logParams
    }
}
else {
    Write-ScriptLogEntry -Message 'User list is empty. The script may have failed to fetch users from Microsoft Entra.' -Classification Critical @logParams
}

try {
    # Import user list file.
    if (Test-Path -Path $usersExportFilePath) {
        try {
            $importedUserList = Import-Csv -Path $usersExportFilePath -Delimiter ';'
            if (($importedUserList | Measure-Object).Count -gt 0) {
                $userList = $importedUserList
            }
        }
        catch {
            Write-ScriptLogEntry -Message ('Failed to import user list file "{0}". {1}' -f $usersExportFilePath, $PSItem) -Classification Critical @logParams
        }
    }

    # Validate user list.
    if (($userList | Measure-Object).Count -eq 0) {
        Write-ScriptLogEntry -Message "Found no users in the user list. Perhaps the user file wasn't correctly saved." -Classification Critical @logParams
    }

    # Build the report file path.
    $reportFilenameStartDate = Get-Date -Date $FromDate -Format $Configuration.Report.DateFormat
    $reportFilenameEndDate = Get-Date -Date $ToDate -Format $Configuration.Report.DateFormat
    $reportFilename = '{0} ({1} - {2}).xlsx' -f $Configuration.Report.Title, $reportFilenameStartDate, $reportFilenameEndDate
    $reportFilePath = Join-Path -Path $Configuration.Report.DirectoryPath -ChildPath $reportFilename

    # Get the test results.
    try {
        $params = @{
            TestDataFilePath = $databaseExportFilePath
            UserList = $userList
            StartDate = $FromDate
            EndDate = $ToDate
        }
        $userTestResults = Get-ScriptUserTestResults @params
    }
    catch {
        Write-ScriptLogEntry -Message "Failed to get test results. $PSItem" -Classification Error @logParams
    }
    
    # Delete report file if it exists from a previous run.
    if (Test-Path -Path $reportFilePath -PathType Leaf) {
        try {
            Remove-Item -Path $reportFilePath
            Write-ScriptLogEntry ('Deleted report file "{0}" from a previous run.' -f $reportFilePath) -Classification Info @logParams
        }
        catch {
            Write-ScriptLogEntry -Message ('Failed to delete existing report file "{0}". {1}' -f $reportFilePath, $PSItem) -Classification Error @logParams
        }
    }
    
    # Export the report file.
    try {
        if ($exportedReportFile = Export-ScriptReportFile -UserTestResults $userTestResults -FilePath $reportFilePath) {
            Write-ScriptLogEntry -Message ('Exported ESD report to file "{0}".' -f $exportedReportFile) -Classification Info @logParams
        }
    }
    catch {
        Write-ScriptLogEntry -Message "Failed to generate the ESD report file. $PSItem" -Classification Error @logParams
    }

    # Clean up old report files.
    $reportFiles = Get-ChildItem -Path (Join-Path -Path $Configuration.Report.DirectoryPath -ChildPath '*.xlsx') | Sort-Object -Property 'CreationTime' -Descending
    if (($Configuration.Report.FileRetentionCount -gt 0) -and (($reportFiles | Measure-Object).Count -gt $Configuration.Report.FileRetentionCount)) {
        $currentFileIndex = 0
        foreach ($file in $reportFiles) {
            if ($currentFileIndex -ge $Configuration.Report.FileRetentionCount) {
                try {
                    $file | Remove-Item -ErrorAction Stop
                    Write-ScriptLogEntry -Message ('Deleted report file "{0}" based on retention settings.' -f $file.FullName) -Classification Info @logParams
                }
                catch {
                    Write-ScriptLogEntry -Message "Failed to delete old report file. $PSItem" -Classification Warning @logParams
                }
            }
            $currentFileIndex += 1
        }
    }

    # Build department result list.
    try {
        $departmentList = ($userTestResults | Group-Object -Property Department).Name
        $resultList = Get-DepartmentResults -DepartmentList $departmentList
    }
    catch {
        Write-ScriptLogEntry -Message "Failed to get department results. $PSItem" -Classification Critical @logParams
    }

    # Build main HTML report.
    $params = @{
        Results = $resultList
        DepartmentReportConfiguration = $Configuration.Report.DepartmentReports
        HeaderHtmlFilePath = $Configuration.Report.TemplatePaths.MainReportHeader
        FooterHtmlFilePath = $Configuration.Report.TemplatePaths.MainReportFooter
    }
    $mainReportHtml = Get-MainReportHtml @params
    # $mainReportHtml | Out-File -Path (Join-Path -Path $Configuration.Report.DirectoryPath -ChildPath 'MainReport.html') # For debugging.

    # Send report mail to each configured department.
    if ($SendMail -eq $true) {
        $weekNumber = (Get-Date -Date $FromDate -UFormat '%V') -as [int]
        $departmentMailSubject = 'ESD test results w. {0}' -f $weekNumber
        $exportedEsdReport = Import-Excel -Path $exportedReportFile
        foreach ($department in $Configuration.Report.DepartmentReports.Departments) {
            try {
                $params = @{
                    ReportData = $exportedEsdReport
                    DepartmentName = $department.Name
                    ExcludedJobTitles = $Configuration.Report.DepartmentReports.ExcludedJobTitles
                    HeaderHtmlFilePath = $Configuration.Report.TemplatePaths.DepartmentReportHeader
                    FooterHtmlFilePath = $Configuration.Report.TemplatePaths.DepartmentReportFooter
                }
                $departmentReportHtml = Get-DepartmentReportHtml @params
            }
            catch {
                Write-ScriptLogEntry -Message "Failed to get department report HTML. $PSItem" -Classification Error @logParams
            }
            
            # Send mail to department report recipient.
            try {
                $params = @{
                    EntraTenantId = $Configuration.MailApp.TenantId
                    EntraAppClientId = $Configuration.MailApp.ClientId
                    EntraAppCertificateThumbprint = $Configuration.MailApp.CertificateThumbprint
                    SenderMailAddress = $Configuration.Report.SenderMailAddress
                    RecipientMailAddress = $department.MailAddress
                    Subject = $departmentMailSubject
                    BodyContent = $departmentReportHtml
                }
                if (Send-ScriptMail @params) {
                    Write-ScriptLogEntry -Message ('Sent {0} department report mail "{1}" to "{2}".' -f $department.Name, $params.Subject, $params.RecipientMailAddress) -Classification Info @logParams
                }
            }
            catch {
                Write-ScriptLogEntry -Message "Failed to send department report mail. $PSItem" -Classification Error @logParams
            }
        }
    }

    # Send mail to main report recipient.
    if ($SendMail -eq $true) {
        try {
            $fromDateString = Get-Date -Date $FromDate -Format 'd\/M'
            $toDateString = Get-Date -Date $ToDate -Format 'd\/M'
            $weekNumber = (Get-Date -Date $FromDate -UFormat '%V') -as [int]
            $mainMailSubject = "ESD test report w. $weekNumber ($fromDateString - $toDateString)"
            $params = @{
                EntraTenantId = $Configuration.MailApp.TenantId
                EntraAppClientId = $Configuration.MailApp.ClientId
                EntraAppCertificateThumbprint = $Configuration.MailApp.CertificateThumbprint
                SenderMailAddress = $Configuration.Report.SenderMailAddress
                RecipientMailAddress = $Configuration.Report.MainRecipientMailAddress
                Subject = $mainMailSubject
                BodyContent = $mainReportHtml
                AttachmentFilePath = $exportedReportFile
            }
            if (Send-ScriptMail @params) {
                Write-ScriptLogEntry -Message ('Sent main report mail "{0}" to "{1}".' -f $params.Subject, $params.RecipientMailAddress) -Classification Info @logParams
            }
        }
        catch {
            Write-ScriptLogEntry -Message "Failed to send main report mail. $PSItem" -Classification Error @logParams
        }
    }
}
catch {
    Write-ScriptLogEntry -Message "A general error occurred. $PSItem" -Classification Critical @logParams
}
finally {
    try {
        Disconnect-MgGraph | Out-Null
    }
    catch {
        Write-ScriptLogEntry -Message "Failed to disconnect from Microsoft Graph. $PSItem" -Classification Warning @logParams
    }

    # Clean up old log files.
    if ($ConfigurationPath.Log.FileRetentionDays -gt 0) {
        $logFiles = (
            Get-ChildItem -Path (Join-Path -Path $Configuration.Log.DirectoryPath -ChildPath '*.log') |
                Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-($Configuration.Log.FileRetentionDays)) }
        )
        foreach ($file in $logFiles) {
            try {
                $file | Remove-Item -ErrorAction Stop
                Write-ScriptLogEntry -Message ('Deleted log file "{0}" based on retention settings.' -f $file.FullName) -Classification Info @logParams
            }
            catch {
                Write-ScriptLogEntry -Message "Failed to delete old log file. $PSItem" -Classification Warning @logParams
            }
        }
    }
}