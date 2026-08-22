function Set-CCPowerSettings {
    param(
        [ValidateNotNull()]
        [int]$MonitorTimeoutOnPowerSupply,

        [ValidateNotNull()]
        [int]$MonitorTimeoutOnBattery,

        [ValidateNotNull()]
        [int]$StandbyTimeoutOnPowerSupply,

        [ValidateNotNull()]
        [int]$StandbyTimeoutOnBattery,

        [switch]$DoNothingOnLidClose
    )

    Write-Verbose 'Configuring monitor timeout...'
    try {
        powercfg /Change /monitor-timeout-ac $MonitorTimeoutOnPowerSupply
        powercfg /Change /monitor-timeout-dc $MonitorTimeoutOnBattery
        Write-Output 'Configured monitor timeout.'
    }
    catch {
        Write-Error "Failed to set monitor timeout. $PSItem"
    }

    Write-Verbose 'Configuring standby/sleep timeout...'
    try {
        powercfg /Change /standby-timeout-ac $StandbyTimeoutOnPowerSupply
        powercfg /Change /standby-timeout-dc $StandbyTimeoutOnBattery
        Write-Output 'Configured standby/sleep timeout.'
    }
    catch {
        Write-Error "Failed to set standby/sleep timeout. $PSItem"
    }

    if ($DoNothingOnLidClose) {
        Write-Verbose 'Configuring device to do nothing when closing the lid...'
        try {
            powercfg -setacvalueindex 381b4222-f694-41f0-9685-ff5bb260df2e 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0
            Write-Output 'Configured lid-closing action to do nothing.'
        }
        catch {
            Write-Error "Failed to configure lid-closing action. $PSItem"
        }
    }
}