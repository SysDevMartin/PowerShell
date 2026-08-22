# WhatToDo
A PowerShell to-do list module that uses the **todo.txt** format (https://github.com/todotxt/todo.txt).

![WhatToDo](whattodo.png)

----

### Get started ###
1. Create a folder called `WhatToDo` in your PowerShell modules folder. You can find all your module folder paths by running the following PS command: `$env:PSModulePath -split ';'`
1. Copy the two files (`WhatToDo.psd1` and `WhatToDo.psm1`) from the `Module` folder into the newly created folder.
1. Create a new folder that will store the configuration and task list files. This folder can exist wherever you want, but you'll need to refer to it when running the WhatToDo functions.
1. Add `Import-Module -Name 'path\to\WhatToDo\WhatToDo.psm1'` to your PowerShell profile (`$PROFILE`), then reload your profile or start a new session.
1. Run `Initialize-WhatToDo -DirectoryPath 'path\to\WhatToDo'`. Set the **DirectoryPath** value to the directory that should store your configuration and task list files.
1. Run `Start-WhatToDo -ConfigurationPath 'path\to\WhatToDo\WhatToDo-Config.psd1'`. Set the **ConfigurationPath** value to the configuration file that was created in the WhatToDo directory.
1. Run the **help** command in the WhatToDo prompt to show all available commands.

```powershell
Import-Module -Name 'path\to\WhatToDo\WhatToDo.psm1'
```

```powershell
Initialize-WhatToDo -DirectoryPath 'path\to\WhatToDo'
```

```powershell
Start-WhatToDo -ConfigurationPath 'path\to\WhatToDo\WhatToDo-Config.psd1'
```

----

### Bonus: Set default parameter value to auto-include configuration file for Start-WhatToDo ###
1. Edit your PS profile (`$PROFILE`).
1. Add the default parameter value somewhere in the profile.

```powershell
$PSDefaultParameterValues['Start-WhatToDo:ConfigurationPath'] = 'path\to\WhatToDo\WhatToDo-Config.psd1'
```

Now you can run `Start-WhatToDo` without the **ConfigurationPath** parameter.
```powershell
Start-WhatToDo
```

----

### Bonus: Create shortcut to standalone session
Create a shortcut in Windows to launch WhatToDo in a standalone session. This will allow the **Start-WhatToDo** function to act as a standalone application.

Target: `C:\Windows\System32\conhost.exe pwsh.exe -Command "Start-WhatToDo -ConfigurationPath 'path\to\WhatToDo\WhatToDo-Config.psd1'"`