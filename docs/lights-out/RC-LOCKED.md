# RC locked — internal nightly 5.2.0

**Status:** LOCKED (2026-06-04)  
**Do not change code before tonight unless Classic UI fails in real use.**

## QA verdict

```text
Static safety:  PASS
CI:             PASS
Desktop deploy: PASS
Classic launcher: PASS
Dry-run smoke:  PASS
Docs/SEO:       PASS
No real shutdown in automated QA: PASS
```

## Product state (locked)

```text
Classic UI = real bedtime timer (default)
Steam UI   = optional premium Night Lobby
```

North star: open → choose the run → press START/PLAY → PC performs the power action safely.

Safety: automated tests never launch real shutdown; power stays behind `Test-NoPowerAction`, `-DryRun`, and CI gates.

## Canonical build

| Item | Path |
|------|------|
| Desktop exe | `C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe` |
| SHA256 (2026-06-04 deploy) | `788700694E2584DC5032CD7CE307942630A9CE8EAFD93E25748D0B330584CE74` |
| Source | `SleepTimer-Tonight.ps1` |
| Version | `5.2.0` |

## Launchers

**Live user path** (real power when START is pressed):

```text
Desktop\Lights Out\Lights Out.bat
Desktop\Lights Out.bat
→ SleepTimer.exe -ClassicUi -NoAutoStart
```

**Safe preview only:**

```powershell
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-DryRun','-NoAutoStart'
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-SteamUi','-DryRun','-NoAutoStart'
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-Demo','-NoAutoStart'
```

## Tonight

```powershell
# Real UI
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -NoAutoStart

# Real 23-minute shutdown
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -Minutes 23 -Action Shutdown -Start

# Cancel Windows fallback
shutdown /a
```

## Remaining manual checks (human only)

1. Classic `-ClassicUi -DryRun -NoAutoStart` — timer amount, chips, analog ring, START
2. Steam `-SteamUi -DryRun -NoAutoStart` — premium lobby
3. Optional Last Light dry-run preview

## Agent rules until next RC

- **No new features**
- **No redesign**
- **No live shutdown** unless user explicitly requests
- **No code changes** unless Classic UI fails in real bedtime use
- Tomorrow's work = only what actually failed or felt annoying in real use

## Regression guards

```powershell
.\scripts\Test-AgentSafety.ps1
.\scripts\Test-SleepTimer.ps1
.\scripts\CI-Local.ps1
```

See also: [`SIMPLE-TIMER.md`](SIMPLE-TIMER.md), [`AGENT-QUICKSTART.md`](../agent-handbook/AGENT-QUICKSTART.md)
