# Troubleshooting — Lights Out PC

**Product:** Local-only Windows sleep timer / shutdown timer  
**App:** `Desktop\Lights Out\SleepTimer.exe`  
**Source:** `SleepTimer-Tonight.ps1`

---

## App won't start

| Symptom | Fix |
|---------|-----|
| "Already running" | Check system tray; exit existing instance or use **Ctrl+Shift+S** to cancel a session |
| Missing modules error | Run from `Desktop\Lights Out\` (folder must contain `modules\LightsOut.*.psm1`) |
| Crash on open | Redeploy: `.\scripts\Deploy-SleepTimer-Desktop.ps1` from `windsurf-project` |

---

## Wrong UI on open (clock mode, no timer amount)

**Cause:** Old settings had `TimerMode: clock` or `UiTheme: steam`.

**Fix:** Use the default launcher (`Lights Out.bat`) or `-ClassicUi`. Classic UI forces **duration mode** and shows **Timer amount** first.

```powershell
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-NoAutoStart'
```

See [`SIMPLE-TIMER.md`](SIMPLE-TIMER.md).

---

## Safe testing vs live use

| Goal | Command |
|------|---------|
| Live tonight | `Lights Out.bat` or `-ClassicUi -NoAutoStart` |
| Safe preview | `-ClassicUi -DryRun -NoAutoStart` |
| Premium preview | `-SteamUi -DryRun -NoAutoStart` |
| Demo/screenshots | `-Demo -NoAutoStart` (implies DryRun) |

DryRun and Demo **never** perform real shutdown/sleep/restart.

---

## Timer did not shut down PC

- Confirm you did not use `-DryRun` or `-Demo`
- Confirm final confirm dialog was accepted (5-second countdown)
- **Ctrl+Shift+S** cancels any armed session
- Windows fallback: `shutdown /s /t 900` — cancel with `shutdown /a`

---

## Hotkey failed in log

`hotkey_failed RegisterHotKey failed` — another app may hold **Ctrl+Shift+S**. Emergency cancel may still work from the app UI; tray and Pause/Cancel remain available.

---

## LuxGrid

Optional. Not required for bedtime timer. See [`LUXGRID-LIGHTSOUT.md`](../../LUXGRID-LIGHTSOUT.md).

---

## Related

| Doc | Use |
|-----|-----|
| [`SIMPLE-TIMER.md`](SIMPLE-TIMER.md) | Classic UI spec |
| [`DEMO-MODE.md`](DEMO-MODE.md) | Demo safety |
| [`AGENT-QUICKSTART.md`](../agent-handbook/AGENT-QUICKSTART.md) | Agent safe commands |
