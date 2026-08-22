# What this script does
The script configures baseline settings for a Windows device (including optional wifi profile in the Resources folder) and joins it to a local AD domain. It also installs software defined in subfolders that exist in the Software folder.

# What's included
- Resources folder that contains the wifi profile XML file. An example file is included.
- Script folder that contains the PS script file (including a Functions folder that the script depends on).
- Software folder that contains subfolders with installation files and a settings CSV file (to filter installation depending on manufacturer type and to add install arguments). Example subfolders are included.

# How to use
1. Copy all content to a USB drive. Do not change the file/folder structure (except subfolders in the Software folders).
1. Edit "Configure computer.bat" and set correct values for the variables **DOMAIN_NAME**, **DOMAIN_JOIN_ACCOUNT**, **DESKTOP_OU_PATH** and **LAPTOP_OU_PATH**.
1. Edit the wifi profile (WifiProfile.xml) if you want to add a wifi profile to laptops.
1. Insert the USB drive into a freshly installed Windows device and launch "Configure computer.bat" (directly from the USB drive).
1. Follow the script and answer its prompts to configure the device.

# Generate SSID HEX for wifi profile XML file
```powershell
([System.Text.Encoding]::UTF8.GetBytes('INSERT_SSID_HERE') | % { [System.String]::Format("{0:X2}", $_) }) -join ''
```