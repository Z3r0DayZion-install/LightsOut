# Simple Timer (Classic UI)

**Status:** Default desktop path (locked RC — see [`RC-LOCKED.md`](RC-LOCKED.md))  
**Rule:** Simple Timer first. Night Lobby second.

```text
Classic UI = duration timer first
Steam UI   = premium Night Lobby (optional)
```

Canonical source: `SleepTimer-Tonight.ps1` → `Desktop\Lights Out\SleepTimer.exe`.

## Classic UI bedtime fix (locked — do not redesign)

Stale saved settings (`TimerMode: clock`, `UiTheme: steam`) must **not** override the bedtime path.

| Rule | Behavior |
|------|----------|
| Default theme | Classic unless `-SteamUi` is passed |
| Timer mode | Classic forces **duration** (minutes countdown) |
| First control | **Timer amount** visible immediately on open |
| Quick chips | `10m 15m 23m 24m 30m 45m 60m` |
| START label | Shows current amount (`START · 23 min`) |
| Steam / Night Lobby | Optional only (`-SteamUi`) |
| Safety | `Do-PowerAction`, `Test-NoPowerAction`, final confirm, 60s min — unchanged |

**Acceptance:** Open with `-ClassicUi -DryRun -NoAutoStart` and see **Timer amount** + spinner + chips before anything else matters.

## Default launcher

`Desktop\Lights Out\Lights Out.bat` opens:

```powershell
SleepTimer.exe -ClassicUi -NoAutoStart
```

Live. Not DryRun. Not Demo.

## Expected flow

```text
Set minutes -> pick action -> START -> PC shuts down/sleeps when the timer ends
```

## UI (Classic)

```text
Lights Out PC / Sleep Timer

Timer amount
[ - ] [ 23 ] minutes [ + ]
10m  15m  23m  24m  30m  45m  60m

[ countdown ring ]

Shutdown  Sleep  Restart  Hibernate  Lock

START · 23 min
```

Options (Dim phase, Last Light, etc.) are collapsed behind **Options**.

## CLI

| Use | Command |
|-----|---------|
| Normal open | `SleepTimer.exe -ClassicUi -NoAutoStart` |
| Live run now | `SleepTimer.exe -ClassicUi -Minutes 23 -Action Shutdown -Start` |
| Safe test | `SleepTimer.exe -ClassicUi -DryRun -NoAutoStart` |
| Night Lobby | `SleepTimer.exe -SteamUi -NoAutoStart` |
| Demo / screenshots | `SleepTimer.exe -Demo -NoAutoStart` |

## Safety (unchanged)

- 60s minimum in production
- 5s final confirm before power action
- `Ctrl+Shift+S` emergency cancel
- `Test-NoPowerAction` / `Do-PowerAction` unchanged

## Windows fallback

If the app fails:

```powershell
shutdown /s /t 1380 /f /c "Force shutdown in 23 minutes. Cancel: shutdown /a"
shutdown /a   # cancel
```

## Related

| Doc | Use |
|-----|-----|
| [`COHESION-ROADMAP.md`](COHESION-ROADMAP.md) | Premium loop |
| [`DEMO-MODE.md`](DEMO-MODE.md) | Marketing preview |
| [`AGENT-QUICKSTART.md`](../agent-handbook/AGENT-QUICKSTART.md) | Agent safety |
