<# 
.SYNOPSIS
Gets the latest released version of a custom PowerShell script or module.

.DESCRIPTION
This function takes the path of a PowerShell script or module in development, and finds the latest released version.

.INPUTS
System.String
    You can pipe a string that contains a script or module path.

.OUTPUTS
Outputs an object that contains the script or module version.

.EXAMPLE
Get-PSDevLatestReleasedDevVersion -Path "$env:USERPROFILE\PSDevScriptsAndModules\MyScriptOrModule"
#>
function Get-PSDevLatestReleasedDevVersion {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Container) { return $true }
            else { throw [System.IO.DirectoryNotFoundException] ('Cannot find the directory "{0}".' -f $_) }
        })]
        [string]$Path
    )

    begin {}

    process {
        try {
            $projectDirectory = Get-Item -Path $Path
            $releaseDirectoryPath = Join-Path -Path $projectDirectory.FullName -ChildPath $projectDirectory.Name
        }
        catch {
            throw "Failed to get project directory. $($PSItem)"
        }
    
        $projectVersions = (
            Get-ChildItem -Path $releaseDirectoryPath -Directory |
            Where-Object { $_.BaseName -match '^(\d{2}|\d{4})\.(\d{1,2})\.(\d+)$' }
        ).BaseName
    
        $maxYear = 0
        $maxMonth = 0
        $maxIteration = 0
    
        # Latest year.
        $projectVersions | ForEach-Object {
            if ($_ -match '^(\d{2}|\d{4})\.(\d{1,2})\.(\d+)$') {
                $tempYear = [int]$Matches.1
    
                if ($tempYear -gt $maxYear) {
                    $maxYear = $tempYear
                }
            }
        }
        $latestYearProjectVersions = $projectVersions | Where-Object {
            $_ -match "^($($maxYear))\.(\d{1,2})\.(\d+)$"
        }
    
        # Latest month.
        $latestYearProjectVersions | ForEach-Object {
            if ($_ -match '^(\d{2}|\d{4})\.(\d{1,2})\.(\d+)$') {
                $tempMonth = [int]$Matches.2
    
                if ($tempMonth -gt $maxMonth) {
                    $maxMonth = $tempMonth
                }
            }
        }
        $latestMonthProjectVersions = $latestYearProjectVersions | Where-Object {
            $_ -match "^(\d{2}|\d{4})\.($($maxMonth))\.(\d+)$"
        }
    
        # Latest iteration.
        $latestMonthProjectVersions | ForEach-Object {
            if ($_ -match '^(\d{2}|\d{4})\.(\d{1,2})\.(\d+)$') {
                $tempIteration = [int]$Matches.3
    
                if ($tempIteration -gt $maxIteration) {
                    $maxIteration = $tempIteration
                }
            }
        }
    
        $latestVersion = '{0}.{1}.{2}' -f $maxYear, $maxMonth, $maxIteration
    }

    end {
        [PSCustomObject]@{
            Year = $maxYear
            Month = $maxMonth
            Iteration = $maxIteration
            FullVersion = $latestVersion
        }
    }
}