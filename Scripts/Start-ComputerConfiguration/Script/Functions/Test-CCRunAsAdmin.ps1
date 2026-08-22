function Test-CCRunAsAdmin {
    $WindowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $WindowsPrincipal = [Security.Principal.WindowsPrincipal]$WindowsIdentity
    $AdminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    return $WindowsPrincipal.IsInRole($AdminRole)
}