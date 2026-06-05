# Lights Out PC

**Bedtime Mode for Windows** — a local-only Windows sleep timer and PC shutdown timer with final confirm and emergency cancel.

| | |
|---|---|
| **Display name** | Lights Out PC |
| **Exe (compat)** | `SleepTimer.exe` |
| **Version** | 5.2.0 (see [`VERSION`](VERSION)) |
| **Source** | `SleepTimer-Tonight.ps1` |
| **Desktop** | `Desktop\Lights Out\SleepTimer.exe` |
| **Settings** | `%LOCALAPPDATA%\CoolTimer\settings.json` |
| **Audit log** | `%LOCALAPPDATA%\CoolTimer\actions.log` |

## One-line pitch

Lights Out PC is a local-only bedtime timer for Windows. Set a countdown, choose Shutdown/Sleep/Restart/Hibernate/Lock, and start a safe nightly run with final confirm and emergency cancel.

**Tagline:** Set the timer. End the session. Sleep without leaving your PC glowing all night.

---

## Two experiences

| Mode | CLI | Use |
|------|-----|-----|
| **Classic UI / Simple Timer** | `-ClassicUi -NoAutoStart` | Default real bedtime path — timer amount first |
| **Night Lobby / Steam UI** | `-SteamUi -NoAutoStart` | Premium — Tonight Preview, cards, Last Light, Morning Proof |
| **Demo** | `-Demo -NoAutoStart` | Screenshots only (implies DryRun) |

Default launcher: `Desktop\Lights Out\Lights Out.bat` → **Classic UI, live, no auto-start**.

---

## Fast start

```powershell
# Deploy
.\scripts\Deploy-SleepTimer-Desktop.ps1

# Tonight
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -NoAutoStart

# 23-minute shutdown
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -Minutes 23 -Action Shutdown -Start

# Safe preview
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-DryRun','-NoAutoStart'
```

---

## Core features

- Countdown timer with analog-style ring (digital time + end-time hand + progress arc)
- Shutdown / Sleep / Restart / Hibernate / Lock
- Final confirm, pause/resume, snooze, **Ctrl+Shift+S** emergency cancel
- Clock and calendar scheduling (optional; Classic UI defaults to duration)
- **Last Light** session finale, **Morning Proof**, **Sleep Clearance** (Night Lobby)
- LuxGrid RGB bridge (optional, off by default)

Docs: [`docs/lights-out/`](docs/lights-out/) · Agent: [`docs/agent-handbook/AGENT-QUICKSTART.md`](docs/agent-handbook/AGENT-QUICKSTART.md)

---

## Safety

- **60s minimum** in production
- **Test-NoPowerAction** blocks power in DryRun, Demo, and CI
- **Do-PowerAction** unchanged — always consults safety gates
- No cloud, no telemetry, no medical claims

---

## Build

```powershell
.\scripts\Test-AgentSafety.ps1
.\scripts\Test-SleepTimer.ps1
.\scripts\CI-Local.ps1
.\scripts\Deploy-SleepTimer-Desktop.ps1
```

Dogfood: [`DOGFOOD.md`](DOGFOOD.md)

---

## Screenshots and visual reference

North-star UI mockups for agents and polish work: [`docs/lights-out/UI-REFERENCE.md`](docs/lights-out/UI-REFERENCE.md)

Assets: [`docs/assets/lights-out/`](docs/assets/lights-out/)

| Caption | File | What it guides |
|---------|------|----------------|
| **Classic UI — simple timer** | `classic-simple-timer-reference.png` | Duration-first layout, ring, chips, START — keep minimal |
| **Night Lobby — premium dashboard** | `night-lobby-reference.png` | Header, hero, trust badges, ring placement, premium dark shell |
| **Morning Proof — session result** | `morning-proof-reference.png` | Proof card, stats rows, readable dark result layout |
| **Last Light — shutdown finale** | `last-light-reference.png` | Exit the Grid overlay, countdown drama, full-screen finale |

These are visual targets for the canonical app (`SleepTimer-Tonight.ps1`), not a redesign brief. Classic stays simple; Night Lobby gets premium treatment.
