<#PSScriptInfo

.VERSION 1.0.0

.GUID 165e2197-898d-4e04-bea2-dfe84a58a0b6

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

.DESCRIPTION 
 Add a new WiFi profile to the computer. 

#> 
param(
    # [Parameter(Mandatory)]
    [ValidateNotNull()]
    [string]$SSID,

    # [Parameter(Mandatory)]
    [ValidateNotNull()]
    [string]$Password,

    [ValidateNotNull()]
    [string]$Authentication = 'WPA2PSK'
)

function Test-InstalledWifiProfile {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$SSID
    )

    $wifiProfileList = (netsh.exe wlan show profiles) -match ':\s+'
    $ssidList = @()
    foreach ($wifiProfile in $wifiProfileList) {
        $wifiProfileSSID = $wifiProfile.Substring($wifiProfile.IndexOf(':')).Replace(':', '').Trim()
        $ssidList += $wifiProfileSSID
    }

    return ($ssidList -ccontains $SSID)
}

function New-WifiProfile {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$SSID,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Password,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Authentication
    )

    $ssidHex = (Format-Hex -InputObject $SSID).HexBytes.Replace(' ', '')

    $profileContent = @'
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>{0}</name>
    <SSIDConfig>
        <SSID>
            <hex>{1}</hex>
            <name>{2}</name>
        </SSID>
        <nonBroadcast>false</nonBroadcast>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>{3}</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>{4}</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
    <MacRandomization xmlns="http://www.microsoft.com/networking/WLAN/profile/v3">
        <enableRandomization>false</enableRandomization>
    </MacRandomization>
</WLANProfile>
'@ -f $SSID, $ssidHex, $SSID, $Authentication, $Password

    $path = Join-Path -Path $env:TEMP -ChildPath ('WifiProfile_{0}.xml' -f $SSID)
    $profileContent | Out-File -FilePath $path -Force

    return $path
}

('Test: {0}' -f (Get-Date)) | Out-File -FilePath (Join-Path -Path $env:TEMP -ChildPath ('Test_{0}.txt' -f (Get-Date -Format 'yyyy-MM-dd_HHmmss')))
exit

Start-Sleep -Seconds 10

if ((Test-InstalledWifiProfile -SSID $SSID) -eq $false) {
    try {
        $ssidFilePath = New-WifiProfile -SSID $SSID -Password $Password -Authentication $Authentication
        Write-Verbose ('Created "{0}" WiFi profile XML file "{1}".' -f $SSID, $ssidFilePath)
    }
    catch {
        throw "Failed to create WiFi profile XML file. $PSItem"
    }

    try {
        Invoke-Expression ('netsh wlan add profile filename="{0}"' -f $ssidFilePath) -ErrorAction 'Stop'
        Write-Verbose ('Added "{0}" WiFi profile from XML file "{1}".' -f $SSID, $ssidFilePath)
    }
    catch {
        throw "Failed to add WiFi profile. $PSItem"
    }

    try {
        Remove-Item -Path $ssidFilePath -ErrorAction 'Stop'
        Write-Verbose ('Removed WiFi profile XML file "{0}".' -f $ssidFilePath)
    }
    catch {
        Write-Error ('Failed to remove WiFi Profile XML file "{0}". {1}' -f $ssidFilePath, $PSItem)
    }
}
else {
    Write-Warning ('WiFi profile "{0}" is already added.' -f $SSID)
}