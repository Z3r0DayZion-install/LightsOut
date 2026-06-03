# Lights Out

**The bedtime shutdown timer for Windows** — open it, tap a ritual, the countdown runs, your PC shuts down when you're done.

| | |
|---|---|
| **Display name** | Lights Out |
| **Exe (compat)** | `SleepTimer.exe` |
| **Version** | 5.1.0 |
| **Source** | `SleepTimer-Tonight.ps1` |
| **Desktop folder** | `Desktop\Lights Out\` |
| **Settings** | `%LOCALAPPDATA%\CoolTimer\settings.json` |
| **Audit log** | `%LOCALAPPDATA%\CoolTimer\actions.log` |

## Download

| Method | Link |
|--------|------|
| **Portable zip** | [LightsOut-portable-5.1.0.zip](https://github.com/Z3r0DayZion-install/ForgeCore_OS/releases/download/v5.1.0/LightsOut-portable-5.1.0.zip) |
| **Portable exe** | [SleepTimer.exe](https://github.com/Z3r0DayZion-install/ForgeCore_OS/releases/download/v5.1.0/SleepTimer.exe) |
| **Installer** | [LightsOut-Setup-5.1.0.exe](https://github.com/Z3r0DayZion-install/ForgeCore_OS/releases/download/v5.1.0/LightsOut-Setup-5.1.0.exe) |
| **GitHub Release** | [v5.1.0](https://github.com/Z3r0DayZion-install/ForgeCore_OS/releases/tag/v5.1.0) |
| **Product repo** | [Z3r0DayZion-install/LightsOut](https://github.com/Z3r0DayZion-install/LightsOut) |
| **WinGet** | `winget install KickA.LightsOut` |
| **Sales page** | [README.md](README.md) |

### Portable (recommended)

```powershell
cd windsurf-project
.\scripts\Deploy-SleepTimer-Desktop.ps1
# -> Desktop\Lights Out\SleepTimer.exe
```

Double-click **Lights Out.bat**. No admin required.

### WinGet

```powershell
winget install KickA.LightsOut
```

---

## Features

### One-tap rituals (v5.0)
- **Weeknight** — 24m shutdown
- **28:20** — classic shutdown ritual
- **Movie** — 45m sleep
- **Bedtime** — shutdown at 11:30 PM

See [`docs/lights-out/RITUALS.md`](docs/lights-out/RITUALS.md).

### Core timer
- Auto-start, shutdown / sleep / restart / hibernate / lock
- Clock-time mode ("at 11:30 PM")
- Pause / resume with remaining time preserved
- End-time clock, tray ring, punch animation, 5s confirm
- **Ctrl+Shift+S** emergency cancel
- **Blocker warn** — `powercfg /requests` before start
- CLI: `-Minutes`, `-At`, `-Action`, `-Minimized`, etc.

### Optional: LuxGrid RGB
- **LuxGrid RGB** checkbox (off by default)
- Sleep Ritual pack: `.\scripts\Export-LuxGrid-SleepRitualPack.ps1`
- See [`LUXGRID-LIGHTSOUT.md`](LUXGRID-LIGHTSOUT.md)

---

## Safety

- Production builds enforce a **60-second minimum** timer
- **Ctrl+Shift+S** cancels any running countdown
- Power actions blocked in dry-run / CI (`Test-NoPowerAction`)
- Local audit log only — **no telemetry**

---

## Build from source

```powershell
.\scripts\CI-Local.ps1
.\scripts\Deploy-SleepTimer-Desktop.ps1
.\scripts\Publish-GitHubRelease.ps1   # when ready to ship
```

Dogfood tracker: [`DOGFOOD.md`](DOGFOOD.md)
