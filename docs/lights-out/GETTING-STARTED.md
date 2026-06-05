# Getting started with Lights Out PC

**Lights Out PC — Bedtime Mode for Windows**

Canonical app: `SleepTimer-Tonight.ps1` → `Desktop\Lights Out\SleepTimer.exe`

---

## Install / open

### First-time deploy (from repo)

```powershell
cd windsurf-project
.\scripts\Deploy-SleepTimer-Desktop.ps1
```

This builds `SleepTimer.exe` and copies it to `Desktop\Lights Out\` with modules, icon, and launchers. Deploy does **not** auto-launch the app.

### Open tonight (normal path)

Double-click one of:

| Launcher | UI | Mode |
|----------|-----|------|
| `Desktop\Lights Out.lnk` | Classic | **Live** |
| `Desktop\Lights Out\Lights Out.bat` | Classic | **Live** |

Or:

```powershell
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -NoAutoStart
```

### Premium preview (not for live bedtime)

Double-click **`Desktop\Lights Out Premium Preview.bat`** for Night Lobby / Steam UI in safe DryRun mode.

```powershell
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-SteamUi','-DryRun','-NoAutoStart'
```

**Do not use Premium Preview for real shutdown tonight.** It always runs with `-DryRun`.

---

## First-night walkthrough (Classic UI)

1. **Open** — double-click `Lights Out.bat` (Classic UI opens, timer does not auto-start).
2. **Set timer amount** — use `-`/`+`, spinner, or quick chips (10m, 15m, **23m**, 30m, 45m, 60m).
3. **Pick action** — Shutdown, Sleep, Restart, Hibernate, or Lock.
4. **START** — button shows `START · N min`; countdown begins.
5. **Tray** — app minimizes to tray; ring shows progress.
6. **At zero** — 5-second final confirm dialog: snooze or proceed.
7. **Power action** — PC shuts down / sleeps / restarts per your choice.
8. **Emergency cancel** — press `Ctrl+Shift+S` anytime to stop.

---

## 23-minute shutdown example

```powershell
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -Minutes 23 -Action Shutdown -Start
```

This opens Classic UI, arms a 23-minute countdown, and starts immediately.

---

## Cancel

| Method | When |
|--------|------|
| **`Ctrl+Shift+S`** | Anytime during countdown, confirm, or Last Light |
| **Pause → stop** | From the app UI |
| **Tray → Exit** | Before countdown ends |
| **`shutdown /a`** | Windows fallback if a `shutdown /s /t` was armed outside the app |

---

## What to expect at timer end

1. **Warnings** — optional alerts at 5 minutes, 60 seconds, 30 seconds.
2. **Dim phase** — optional 90-second wind-down (if enabled in settings).
3. **Last Light** — optional cinematic finale (Night Lobby / Steam mode).
4. **Final confirm** — 5-second dialog: snooze (+5/+10 min) or proceed.
5. **Power action** — `Do-PowerAction` runs Shutdown/Sleep/Restart/Hibernate/Lock.
6. **Morning Proof** — on next launch (Night Lobby), a session summary may appear.

In **DryRun** or **Demo**, steps 1–4 play normally but step 5 is blocked by `Test-NoPowerAction`.

---

## Safe preview before first live run

```powershell
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-DryRun','-NoAutoStart'
```

Walk through the UI, start a short countdown, and confirm no real power action occurs.

---

## Related docs

- [`SIMPLE-TIMER.md`](SIMPLE-TIMER.md) — Classic UI contract
- [`CLI.md`](CLI.md) — all flags
- [`SAFETY-MODEL.md`](SAFETY-MODEL.md) — power gates
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — common issues
