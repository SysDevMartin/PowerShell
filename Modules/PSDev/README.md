# PSDev
A PowerShell module that is used to create and publish custom modules to an internal repository.

## What can this module do?
The module allows you to create new scripts and modules with a pre-defined file and folder structure. It allows you to then export released versions of your development state, and also publish the latest release to a PowerShell repository for easy distribution.

When exporting a new version of a module, Pester tests that you have created in the Tests folder will automatically be run. If all tests pass, the module will be exported. If any test fails, the export will be aborted.
Automatic testing currently only works for modules, not scripts.

## Example commands
Create a new script.
```powershell
New-PSDevScript -Name 'MyScript' -Description 'This is a description of my script.' -Author 'Firstname Lastname' -Path 'root/path/to/development/modules'
```

Release/export a script to prepare it for publishing.
```powershell
Export-PSDevScript -Name 'MyScript' -Path 'root/path/to/development/modules'
```

Publish a script to a PowerShell repository.
```powershell
Publish-PSDevScript -Name 'MyScript' -Path 'root/path/to/development/modules' -Repository 'MyRepository'
```