set ROOT_PATH=%~dp0
set SCRIPT_PATH="%~dp0Script\Start-ComputerConfiguration.ps1"

set DOMAIN_NAME="mydomain.local"
set DOMAIN_JOIN_ACCOUNT="mydomain\MyDomainJoinServiceAccount"

set DESKTOP_OU_PATH="OU=Desktops,OU=Computers,DC=mydomain,DC=local"
set LAPTOP_OU_PATH="OU=Laptops,OU=Computers,DC=mydomain,DC=local"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoExit -ExecutionPolicy Bypass -File ""%SCRIPT_PATH%"" -RootDirectoryPath ""%ROOT_PATH%"" -DomainName ""%DOMAIN_NAME%"" -DomainJoinAccountUsername ""%DOMAIN_JOIN_ACCOUNT%"" -DesktopOUPath ""%DESKTOP_OU_PATH%"" -LaptopOUPath ""%LAPTOP_OU_PATH%""' -Verb RunAs"