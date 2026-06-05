# Which app is which?

Quick map so agents do not replace your nightly timer with repo experiments.

## Canonical (use every night)

| App | Location | Technology |
|-----|----------|------------|
| **Lights Out** | `Desktop\Lights Out\SleepTimer.exe` | PS2EXE from `SleepTimer-Tonight.ps1` (see `VERSION`) |
| Source + docs | `SleepTimer-Tonight.ps1`, `PRODUCT.md`, `LUXGRID-LIGHTSOUT.md` | PowerShell WinForms |

## Rebuild

```powershell
cd windsurf-project

# Quick: Desktop only
.\scripts\Deploy-SleepTimer-Desktop.ps1

# Full release: dist\Release + Desktop + installer (if Inno Setup installed)
.\scripts\Build-Release.ps1
```

## Repo experiments (not nightly unless you choose)

| App | Entry | Notes |
|-----|-------|-------|
| Nightfall UI | `CoolTimer.ps1` | Larger UI, LuxGrid events — not current Desktop build |
| Sleep Timer Pro (full) | `SleepTimer.bat` → `SleepTimer.ps1` | ~1400 lines, tray, profiles |
| Electron UI | `SleepTimer-Electron/` | Separate product skin |
| LuxGrid | `luxgrid/` | RGB platform; Lights Out v3.9+ emits optional events |

## Run without compiling

```powershell
.\SleepTimer-Tonight.ps1
.\SleepTimer-Tonight.ps1 -NoAutoStart   # configure first
```
