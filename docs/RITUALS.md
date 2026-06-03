# Lights Out — Rituals

One-tap bedtime presets. Each ritual sets duration (or clock time), action, and **starts** the countdown.

| Ritual | What it does |
|--------|----------------|
| **Weeknight** | 24 minutes → shutdown |
| **28:20** | Classic shutdown ritual (~28 min) |
| **Movie** | 45 minutes → sleep (display stays warm) |
| **Bedtime** | Shutdown at **11:30 PM** tonight (rolls to tomorrow if past) |

## LuxGrid pairing (optional)

1. `.\scripts\Install-LuxGrid-LightsOut.ps1`
2. LuxGrid Studio → **Sleep Ritual** → **Start Watching**
3. Lights Out → **LuxGrid RGB** ON → tap **Movie** or **Weeknight**

Keyboard zones react to `timer.tick`, warnings, and the **lights.out** punch event.

## Audit log

Ritual picks are logged as `ritual_selected` in `%LOCALAPPDATA%\CoolTimer\actions.log`.
