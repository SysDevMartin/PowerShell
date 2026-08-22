rem Start a PowerShell script from the current directory. Replace the script name in the SCRIPT variable (%~dp0 means the current directory plus a backslash).
set SCRIPT="%~dp0PowershellScript.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoExit -ExecutionPolicy Bypass -File ""%SCRIPT%""' -Verb RunAs"