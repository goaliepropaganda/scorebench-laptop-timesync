# install-timesync.ps1
# Run once as Administrator on each streaming PC
# Configures NTP servers and registers a startup task to force-resync after boot
#
# Usage:
#   Right-click > Run as Administrator
#   OR: powershell.exe -ExecutionPolicy Bypass -File "install-timesync.ps1"

$ErrorActionPreference = "Stop"

$scriptDir  = "C:\Scripts"
$scriptPath = "$scriptDir\sync-time.ps1"
$logDir     = "C:\Logs"
$logPath    = "$logDir\timesync.log"
$taskName   = "StartupTimeSync"
$ntpPeers   = "time.cloudflare.com time.windows.com pool.ntp.org"
$delaySecs  = 120   # seconds after startup before forcing resync

# ---------------------------------------------------------------------------
# 1. Create directories
# ---------------------------------------------------------------------------
Write-Host "[1/5] Creating directories..."
New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir    | Out-Null

# ---------------------------------------------------------------------------
# 2. Configure NTP servers
# ---------------------------------------------------------------------------
Write-Host "[2/5] Configuring NTP servers: $ntpPeers"
w32tm /config /manualpeerlist:"$ntpPeers" /syncfromflags:manual /reliable:YES /update
net stop w32tm  | Out-Null
net start w32tm | Out-Null

# ---------------------------------------------------------------------------
# 3. Write the sync script (runs at every startup via Task Scheduler)
#    It re-applies NTP config each time in case a Windows Update reset it,
#    then forces a resync after the network has had time to settle.
# ---------------------------------------------------------------------------
Write-Host "[3/5] Writing sync script to $scriptPath..."

$syncScript = @"
# sync-time.ps1
# Auto-installed by install-timesync.ps1
# Do not edit the NTP peer list here -- re-run install-timesync.ps1 instead

`$ntpPeers  = "$ntpPeers"
`$logPath   = "$logPath"
`$delaySecsVal = $delaySecs

# Re-apply NTP config in case Windows Update reset it
w32tm /config /manualpeerlist:"`$ntpPeers" /syncfromflags:manual /reliable:YES /update
net stop w32tm  | Out-Null
net start w32tm | Out-Null

# Wait for network to settle
Start-Sleep -Seconds `$delaySecsVal

# Force resync
w32tm /resync /force

# Log result
`$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
`$status    = w32tm /query /status
Add-Content -Path `$logPath -Value "`$timestamp``n`$status``n---"
"@

$syncScript | Out-File -FilePath $scriptPath -Encoding UTF8

# ---------------------------------------------------------------------------
# 4. Register (or replace) the scheduled task
# ---------------------------------------------------------------------------
Write-Host "[4/5] Registering scheduled task '$taskName'..."

$action   = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

$trigger  = New-ScheduledTaskTrigger -AtStartup

$settings = New-ScheduledTaskSettingsSet `
                -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
                -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask `
    -TaskName   $taskName `
    -Action     $action `
    -Trigger    $trigger `
    -Settings   $settings `
    -Principal  $principal `
    -Description "Re-applies NTP config and forces time resync $delaySecs seconds after startup" `
    -Force | Out-Null

# ---------------------------------------------------------------------------
# 5. Run an immediate sync so both clocks are correct right now
# ---------------------------------------------------------------------------
Write-Host "[5/5] Running immediate sync..."
w32tm /resync /force

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host ""
Write-Host "  NTP servers : $ntpPeers"
Write-Host "  Sync script : $scriptPath"
Write-Host "  Log file    : $logPath"
Write-Host "  Task name   : $taskName"
Write-Host "  Startup delay: $delaySecs seconds"
Write-Host ""
Write-Host "Restart to confirm the task fires, then check the log at:"
Write-Host "  $logPath"
Write-Host ""
Write-Host "Run this script again on the second PC." -ForegroundColor Yellow
