# timesync

Keeps system clocks aligned across two Windows PCs used for livestream score bug display.

## Problem

The score bug runs in a browser and relies on the system clock. If the two PCs drift out of
sync the displayed time diverges. Windows time sync at startup often fails silently because
the network isn't ready yet. Running it manually later always fixes it.

## Solution

- Both PCs point at the same three NTP servers (Cloudflare, Microsoft, pool.ntp.org)
- A startup task re-applies the NTP config (in case Windows Update reset it) and forces
  a resync 2 minutes after boot, by which time the network is stable
- The config is re-applied on every startup, not just once at install time

## Usage

Run once on each PC (both the laptop and the display PC):

1. Copy `install-timesync.ps1` to the Desktop
2. Right-click > **Run as Administrator**
3. Done

That's it. The task registers itself and fires on every subsequent startup.

## What the installer does

| Step | Action |
|------|--------|
| 1 | Creates `C:\Scripts\` and `C:\Logs\` |
| 2 | Configures NTP peers: `time.cloudflare.com time.windows.com pool.ntp.org` |
| 3 | Writes `C:\Scripts\sync-time.ps1` |
| 4 | Registers Task Scheduler job `StartupTimeSync` (runs as SYSTEM at startup) |
| 5 | Runs an immediate sync so the clock is correct right now |

## Files created on the target PC

```
C:\Scripts\sync-time.ps1   -- the sync script (do not edit directly)
C:\Logs\timesync.log       -- log of every sync attempt with timestamp and status
```

## Checking the log

Open PowerShell and run:

```powershell
Get-Content C:\Logs\timesync.log
```

Or just open it in Notepad.

## Re-running / updating

If you need to change the NTP servers or delay, edit the variables at the top of
`install-timesync.ps1` and re-run it. The `-Force` flag on `Register-ScheduledTask`
means it will overwrite the existing task cleanly.

## Uninstalling

```powershell
Unregister-ScheduledTask -TaskName "StartupTimeSync" -Confirm:$false
Remove-Item "C:\Scripts\sync-time.ps1"
```
