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
        Title = 'ESD-rapport'
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