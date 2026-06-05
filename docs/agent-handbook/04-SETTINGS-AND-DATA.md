# Settings and data

## Storage locations

| Data | Location |
|---|---|
| Settings JSON | `%LOCALAPPDATA%\CoolTimer\settings.json` |
| Audit log | `%LOCALAPPDATA%\CoolTimer\actions.log` |
| Saved timer profiles | `SavedTimers` inside `settings.json` |
| Calendar source | Local ICS path or feed URL in settings |
| Desktop app files | `Desktop\Lights Out\` |

The `CoolTimer` folder name is legacy. Do not rename it casually because it would break existing user settings.

## Script paths

```powershell
$script:SettingsDir  = Join-Path $env:LOCALAPPDATA 'CoolTimer'
$script:SettingsPath = Join-Path $script:SettingsDir 'settings.json'
$script:AuditLogPath = Join-Path $script:SettingsDir 'actions.log'
```

## Persistence contract

- Settings survive deploys.
- Desktop reinstall must not wipe `%LOCALAPPDATA%\CoolTimer\`.
- New settings must have safe defaults in `Get-Settings`.
- Settings writes should be guarded until `$script:UiReady` when triggered by UI load-bound controls.
- Do not save while running unless the existing pattern explicitly supports it.
- Audit log is append-only and human-readable, not structured JSON.

## Settings schema

Defaults are defined in `Get-Settings`.

| Key | Default | Meaning |
|---|---:|---|
| `DefaultSeconds` | `1700` | Default lobby duration, about 28:20. |
| `Action` | `Shutdown` | Power action. |
| `TopMost` | `true` | Always-on-top window. |
| `WarnAt5Min` / `Warn5Min` | `true` | 5-minute warning compatibility. |
| `RunAtLogin` | `false` | Startup shortcut. |
| `MinimizeToTray` | `true` | Tray behavior on minimize. |
| `EmitLuxGridEvents` | `false` | Optional LuxGrid event output. |
| `GracefulShutdown` | `true` | Avoid forced shutdown by default. |
| `TimerMode` | `duration` | `duration`, `clock`, or `calendar`. |
| `ClockTime` | `23:30` | Bedtime clock target. |
| `ScheduledAt` | `''` | One-shot schedule datetime. |
| `CalendarSource` | `''` | Local ICS file path. |
| `CalendarEventUid` | `''` | Selected event UID. |
| `CalendarEventTitle` | `''` | Selected event display name. |
| `CalendarFeedUrl` | `''` | Remote ICS feed URL. |
| `CalendarFeedIntervalMin` | `30` | Feed poll interval. |
| `CalendarFeedAutoStart` | `false` | Start when event is due. |
| `CalendarFeedLastSync` | `''` | Last successful feed sync. |
| `WarnPowerBlockers` | `true` | Warn when blockers may prevent sleep/shutdown. |
| `QuickWarnPanel` | `true` | Show quick choices at warning moments. |
| `DimPhaseEnabled` | `true` | Dim UI near end of session. |
| `DimPhaseSeconds` | `90` | Dim phase length. |
| `PactEnabled` | `false` | Bedtime pact feature. |
| `PactTime` | `23:00` | Pact target clock. |
| `LastRitualId` | `''` | Last selected ritual. |
| `LastProfileId` | `''` | Last selected saved profile. |
| `SavedTimers` | `@()` | Saved named timer profiles. |
| `UiTheme` | `steam` | `steam` or `classic`. |
| `AutoStart` | `false` | Auto-play on app open. |
| `BigPictureOnStart` | `false` | Open Cinema when session starts. |
| `LastAchievementStreak` | `0` | Prevent duplicate achievement toasts. |
| `ConfirmAtEnd` | `true` | Final confirm; keep true on write. |

## Runtime-only state

| Variable | Notes |
|---|---|
| `$script:DefaultSec` | Mirrors `DefaultSeconds`. |
| `$script:TimerMode` | Active timer mode. |
| `$script:ScheduledAt` | Active schedule datetime. |
| `$script:CalendarSource` | Active local ICS/feed source. |
| `$script:DimPhaseSec` | Active dim duration. |
| `$script:LastRitualId` | Current UX memory. |
| `$script:LastProfileId` | Current UX memory. |
| `$script:AutoStartOnOpen` | Applied auto-start state. |

## Load and save flow

1. Startup calls `Get-Settings`.
2. Defaults fill missing keys.
3. Values are applied to `$script:*` and UI controls.
4. UI changes save through guarded handlers.
5. `Save-Settings` also syncs Run at Login through `Set-RunAtLogin`.

## Audit log

`Write-AuditLog` appends line-oriented events for transparency and debugging.

Examples:

- `app_start`
- `ritual_selected`
- `timer_start`
- `timer_pause`
- `timer_resume`
- `timer_cancel`
- `timer_completed`
- `power_action`

Rules:

- Do not parse it as JSON.
- Do not depend on a rigid schema unless one is later introduced.
- Do not log secrets, tokens, or full private calendar contents.
- Use it to verify behavior without reproducing shutdown.

## Minimum timer persistence

Production minimum is 60 seconds. Shorter values should clamp on load/save except explicit safe test/dry-run paths.

## Migration rules for new settings

When adding a setting:

1. Add a safe default in `Get-Settings`.
2. Document it here.
3. Ensure missing key does not crash older installs.
4. Avoid changing existing key names unless you also migrate old data.
5. Keep `ConfirmAtEnd` true unless user has explicitly requested different behavior and safety review allows it.
6. Update any UI save handlers carefully so initial control binding does not overwrite user settings before `$script:UiReady`.
