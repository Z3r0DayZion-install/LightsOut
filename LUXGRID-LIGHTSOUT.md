# Lights Out + LuxGrid — full integration

## Nightly ritual (your stack)

```
Lights Out (SleepTimer.exe)          LuxGrid Studio
        │                                    │
        │  JSON events (optional)             │  EventBridge watches inbox
        └──────────► %LOCALAPPDATA%/LuxGrid/events/inbox/
                                              │
                                              ▼
                                    Sleep Ritual profile
                                    QWERTY drain · warn row · punch flash
                                              │
                                              ▼
                                    OpenRGB / HID keyboard + mouse
```

## Lights Out side (v3.9+)

1. Check **LuxGrid RGB** in the settings card (off by default).
2. Start countdown as usual.
3. Events use `sourceApp: "LightsOut"` on channel `sleep`.

| Event | When |
|-------|------|
| `timer.start` | Countdown begins |
| `timer.tick` | Every 30s |
| `timer.warning` | 5m / 60s / 30s |
| `lights.out` | Punch animation at zero |
| `timer.completed` | After confirm → power action |
| `timer.cancelled` | Pause / emergency cancel |

## LuxGrid side

1. Run `scripts/Install-LuxGrid-LightsOut.ps1` once (creates inbox dirs).
2. Open **LuxGrid Studio**.
3. **Sleep Ritual** profile — QWERTY progress, 1–0 warnings, punch keys, ambient WASD breath.
4. **Event Monitor → Start Watching** (or start **Live** with Sleep Ritual — watching auto-starts).
5. Optional: **Live** mode drives real Roccat HID when connected.

## Safe testing

```powershell
# Never launches shutdown timer
.\scripts\Test-SleepTimer.ps1

# Dry-run UI only
.\scripts\Test-Daytime.ps1 -Launch -UseExe -Seconds 60

# LuxGrid inbox setup
.\scripts\Install-LuxGrid-LightsOut.ps1
```

In Studio: **Lights Out Demo** simulates the full event sequence without the timer app.

## Deploy both

```powershell
.\scripts\Deploy-SleepTimer-Desktop.ps1
.\scripts\Install-LuxGrid-LightsOut.ps1
# LuxGrid Studio: cd luxgrid && pnpm build (or use installed Studio)
```
