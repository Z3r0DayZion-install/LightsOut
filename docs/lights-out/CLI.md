# Lights Out CLI reference

Canonical binary: `Desktop\Lights Out\SleepTimer.exe`  
Source: `SleepTimer-Tonight.ps1`

---

## UI mode flags

| Flag | Alias | Effect |
|------|-------|--------|
| `-ClassicUi` | `-Classic`, `-Simple` | Simple timer layout — **default live path** |
| `-SteamUi` | `-Steam` | Night Lobby premium UI — use with `-DryRun` for preview |

CLI theme flags win over saved `settings.json` `UiTheme`.

```text
Normal launcher     →  -ClassicUi -NoAutoStart  (live)
Premium Preview     →  -SteamUi -DryRun -NoAutoStart  (safe preview)
```

---

## Safety flags

| Flag | Effect |
|------|--------|
| `-DryRun` | Safe mode — `Test-NoPowerAction` blocks all power actions |
| `-Demo` | Marketing loop — implies DryRun; skips settings/log writes |
| `-NoAutoStart` | Open in lobby without starting countdown |
| `-Start` | Start countdown on launch |

---

## Timer flags

| Flag | Alias | Effect |
|------|-------|--------|
| `-Minutes` | `-m`, `-mins` | Countdown length in minutes |
| `-Seconds` | `-sec`, `-s` | Countdown length in seconds |
| `-Action` | `-a` | Power action: Shutdown, Sleep, Restart, Hibernate, Lock |
| `-ScheduleAt` | `-schedule` | Calendar schedule datetime |
| `-At` | `-time` | Clock target (e.g. `-At 23:30`) |
| `-IcsPath` | `-calendar`, `-ics` | Import `.ics` calendar file |

---

## Other flags

| Flag | Effect |
|------|--------|
| `-Help` | Show CLI help and exit |
| `-Minimized` | `-min`, `-tray` — start minimized to tray |
| `-LastLightSequence` | Preview a Last Light sequence (use with Demo/DryRun) |

---

## Environment variables

| Variable | Effect |
|----------|--------|
| `SLEEPTIMER_MINUTES` | Default minutes |
| `SLEEPTIMER_ACTION` | Default power action |
| `SLEEPTIMER_DRY_RUN=1` | Enable DryRun |
| `SLEEPTIMER_DEMO=1` | Enable Demo mode |
| `SLEEPTIMER_CI=1` | CI gate — blocks power |
| `SLEEPTIMER_NO_AUTOSTART=1` | Force lobby on open |

---

## Examples — live use (human only)

```powershell
# Open Classic UI without starting
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -NoAutoStart

# 23-minute shutdown now
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -Minutes 23 -Action Shutdown -Start

# Sleep in 45 minutes
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -Minutes 45 -Action Sleep -Start
```

---

## Examples — safe previews (agents / CI)

```powershell
# Classic UI dry-run
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-DryRun','-NoAutoStart'

# Night Lobby dry-run (Premium Preview launcher uses this)
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-SteamUi','-DryRun','-NoAutoStart'

# Demo full loop
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-Demo','-NoAutoStart'

# Last Light finale preview
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-Demo','-LastLightSequence','ExitTheGrid'

# Short dry-run countdown
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-DryRun','-Seconds','90','-Start'
```

---

## Help

```powershell
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -Help
```

---

## Related docs

- [`GETTING-STARTED.md`](GETTING-STARTED.md) — first-night walkthrough
- [`SAFETY-MODEL.md`](SAFETY-MODEL.md) — power gates
- [`SIMPLE-TIMER.md`](SIMPLE-TIMER.md) — Classic UI contract
- [`../agent-handbook/10-CLI-AND-AUTOMATION.md`](../agent-handbook/10-CLI-AND-AUTOMATION.md) — automation rules
