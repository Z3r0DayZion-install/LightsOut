# LuxGrid integration

LuxGrid is optional. Lights Out must work fully without it.

Use this integration only as an RGB/event bridge for sleep rituals. Do not make LuxGrid a dependency of the core timer, tests, deploy, or app launch.

## Product relationship

| Lights Out | LuxGrid |
|---|---|
| Bedtime shutdown/sleep timer. | RGB/event visualization system. |
| Canonical app is `SleepTimer.exe`. | Separate stack under `luxgrid/`. |
| Owns countdown and power actions. | Reacts to emitted events. |
| Works alone. | Optional enhancement. |

## User flow

1. Optional setup: run `scripts\Install-LuxGrid-LightsOut.ps1`.
2. LuxGrid Studio: choose **Sleep Ritual** profile and start watching.
3. Lights Out: enable **LuxGrid RGB** checkbox.
4. Start a timer/ritual.
5. LuxGrid reacts to timer events.

## Event pipeline

```text
SleepTimer.exe
  -> if EmitLuxGridEvents is enabled
  -> %LOCALAPPDATA%\LuxGrid\events\inbox\
  -> LuxGrid Studio EventBridge
  -> Sleep Ritual profile / OpenRGB
```

Settings key:

```text
EmitLuxGridEvents
```

User-facing checkbox:

```text
LuxGrid RGB
```

## Event types

| Event | When |
|---|---|
| `timer.start` | Countdown begins. |
| `timer.tick` | Periodic tick, typically every 30 seconds. |
| `timer.warning` | Warning moments such as 5m, 60s, 30s. |
| `lights.out` | Timer reaches zero / punch moment. |
| `timer.completed` | Completion path around final/power action. |
| `timer.cancelled` | Cancel or emergency cancel. |

Common fields:

- `sourceApp`: `LightsOut`.
- `channel`: `sleep`.

## Ritual pairing

| Ritual | Typical RGB behavior |
|---|---|
| Weeknight | Slow progress lighting. |
| Classic 28:20 | Familiar countdown ambiance. |
| Movie | Dim/ambient sleep fade. |
| Bedtime | Clock target and final punch. |

## Agent rules

- Do not require LuxGrid for `Test-SleepTimer.ps1`.
- Do not bundle LuxGrid into `SleepTimer.exe`.
- Do not edit LuxGrid internals for a Lights Out task unless explicitly asked.
- Use demo/simulated events to test the bridge when possible.
- Keep checkbox off by default unless user changes setting.
- Do not fail the core timer if LuxGrid folders are missing.

## Deploy commands

Lights Out only:

```powershell
.\scripts\Deploy-SleepTimer-Desktop.ps1
```

Optional LuxGrid bridge setup:

```powershell
.\scripts\Install-LuxGrid-LightsOut.ps1
```

## Troubleshooting

If RGB does nothing:

1. Confirm `EmitLuxGridEvents` / LuxGrid RGB is enabled.
2. Confirm LuxGrid inbox folders exist.
3. Confirm LuxGrid Studio is watching.
4. Confirm event files are being written.
5. Use Studio demo mode before launching the timer.

Deep dive: `LUXGRID-LIGHTSOUT.md`.
