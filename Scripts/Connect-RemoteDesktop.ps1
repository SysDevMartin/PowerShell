function Connect-RemoteDesktop {
    param(
        [Parameter(Position = 0)]
        [ValidateSet('Server1', 'Server2', 'Server3')]
        [string]$Endpoint
    )

    switch ($Endpoint) {
        'Server1' { Start-Process -FilePath 'C:\WINDOWS\system32\mstsc.exe' -ArgumentList @('/v:10.0.0.10') }
        'Server2' { Start-Process -FilePath 'C:\WINDOWS\system32\mstsc.exe' -ArgumentList @('/v:10.0.0.15') }
        'Server3' { Start-Process -FilePath 'C:\WINDOWS\system32\mstsc.exe' -ArgumentList @('/v:10.0.0.20') }
        default { Start-Process -FilePath 'C:\WINDOWS\system32\mstsc.exe' }
    }
}