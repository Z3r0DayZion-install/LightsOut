# CoolTimer — UI experiment (not canonical)

> **Agents:** read [`docs/agent-handbook/AGENT-QUICKSTART.md`](docs/agent-handbook/AGENT-QUICKSTART.md) first.  
> **Canonical app:** `SleepTimer-Tonight.ps1` → `Desktop\Lights Out\SleepTimer.exe` via `scripts\Deploy-SleepTimer-Desktop.ps1`.  
> This file documents the **`CoolTimer.ps1`** experiment and legacy paths — do not deploy it as the nightly app.

| What you run (canonical) | Path |
|--------------|------|
| Desktop | `C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe` |
| Source | `SleepTimer-Tonight.ps1` |
| Settings | `%LOCALAPPDATA%\CoolTimer\settings.json` |

## Behavior

- **Auto-starts** countdown on open
- **Shutdown / Restart / Sleep** (dropdown)
- **+5** and **+10 min** snooze
- **Stop** to pause; **Start** to resume
- **5-second confirm** before power action
- **Always on top** and **warn at 5 min** toggles
- Last **30 seconds**: red countdown

## v3.4 — tray + login

- **Tray icon** with live countdown in tooltip
- **Minimize** while running → hides to tray (balloon tip)
- **Double-click tray** or right-click **Show**
- **Run at login** checkbox → Startup shortcut
- Close while running: **Yes** = tray, **No** = exit, **Cancel** = stay

## Rebuild Desktop

```powershell
cd windsurf-project
.\scripts\Deploy-SleepTimer-Desktop.ps1
```

Deploy **preserves your settings** (duration, action) — does not reset to 28:20.

## Release build + installer

```powershell
.\scripts\Build-Release.ps1
# dist\Release\SleepTimer.exe
# installer\output\SleepTimer-Setup-3.3.0.exe  (needs Inno Setup 6)

# Install to Program Files (admin)
.\scripts\Install-Nightfall.ps1
```

## v3.3 fixes

- Timer tick scoping fix (countdown no longer freezes)
- Sleep action added
- Custom icon on exe
- Release pipeline uses this source (not Nightfall bundle)
