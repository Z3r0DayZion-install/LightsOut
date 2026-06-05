# Features shipped

This file tells agents what already exists. Do not rebuild shipped features unless the user asks for a rewrite or you verified the current implementation is broken.

Version context: v5.2.0 local/canonical docs. Public release tags may lag.

## Canonical local binary

`Desktop\Lights Out\SleepTimer.exe`

## Core timer

- Countdown timer with 1-second tick.
- Pause, resume, cancel, and snooze.
- Power actions: Shutdown, Sleep, Restart, Hibernate, Lock.
- Final confirmation before real power action.
- Emergency cancel through tray and `Ctrl+Shift+S`.
- Single instance mutex: `Global\SleepTimerTonight`.
- Production minimum duration: 60 seconds.
- Dry-run and CI gates through `Test-NoPowerAction`.

## CLI and automation

Implemented:

- `-Minutes`, `-Seconds`, `-Action`.
- `-Start`, `-NoAutoStart`, `-Minimized`.
- `-DryRun`, `-Help`.
- `-ScheduleAt`, `-IcsPath`.
- `-SteamUi`, `-ClassicUi`.
- `SLEEPTIMER_*` environment variable mirrors.
- Slash-style startup argument parsing for selected flags.

Details: `10-CLI-AND-AUTOMATION.md`.

## Schedule modes

| Mode | Shipped behavior |
|---|---|
| Duration | Slider/presets/default seconds. |
| Clock | Target a time tonight; rolls forward when needed. |
| Calendar | Load ICS file and choose upcoming event. |
| Calendar feed | Remote ICS URL polling and optional auto-start. |

## One-tap rituals

| Ritual | Behavior |
|---|---|
| Weeknight | 24 minutes -> Shutdown. |
| Classic 28:20 | About 1700 seconds -> Shutdown. |
| Movie | 45 minutes -> Sleep. |
| Bedtime | Clock 11:30 PM -> Shutdown. |

User-facing ritual details live in `docs/lights-out/RITUALS.md`.

## Steam UI / UX

Shipped:

- Steam theme default.
- LIB / SCH / SET navigation.
- Lobby-first open.
- Ring shows target time in Lobby for clock/calendar.
- No fake running arc in Lobby.
- Full-width PLAY in Lobby.
- Pause/snooze hidden when idle.
- Collapsed Options area for secondary checkboxes.
- STATS link to visual sleep ledger dialog.
- Session toasts.
- Cinema mode fullscreen countdown.
- Achievement toasts at 3/7/14/30-night streaks.
- Theme palette hardening through `Get-UiColor` and fallback palette.

## Tray and warnings

Shipped:

- Minimize to tray.
- Live tray progress icon.
- 5-minute, 60-second, and 30-second warnings.
- Configurable 5-minute warning toggle.
- Quick warning panel.
- Power blocker warning.
- Dim phase near the end.

## Novel/social module

Shipped through `LightsOut.Novel.psm1`:

- Sleep ledger stats.
- Bedtime pact helpers.
- Household sync helpers.

## Saved profiles

Shipped through `LightsOut.Profiles.psm1`:

- Saved timer profile conversion.
- Saved profile hints.
- Deserialize saved profiles from settings JSON.

## Calendar module

Shipped through `LightsOut.Calendar.psm1`:

- ICS content parsing.
- Local ICS import.
- Remote feed import.
- Upcoming event listing.
- URL validation helper.

## LuxGrid bridge

Shipped but optional:

- Checkbox: LuxGrid RGB / `EmitLuxGridEvents`.
- Event output to `%LOCALAPPDATA%\LuxGrid\events\inbox\`.
- Event types: `timer.start`, `timer.tick`, `timer.warning`, `lights.out`, `timer.completed`, `timer.cancelled`.
- Installer helper: `scripts\Install-LuxGrid-LightsOut.ps1`.

LuxGrid is not required for core timer use.

## Safety and ops

Shipped:

- Audit log.
- Graceful shutdown toggle, no force by default.
- Run-at-login shortcut handling.
- Desktop deploy script.
- Module copy on deploy.
- `scripts\Test-SleepTimer.ps1` safe static/parse tests.
- `scripts\CI-Local.ps1` validate/build pipeline.

## Branding

- Product name: Lights Out.
- Executable name: `SleepTimer.exe`.
- Window title uses Lights Out.
- Steam header shows version.
- Legacy settings folder remains `CoolTimer`.

## Known shipped-but-not-public-trust-complete

These do not block local use but matter for public release:

- Production Authenticode signing not complete.
- Public GitHub Release/tag may lag local `VERSION`.
- Winget/package distribution may not be fully merged/live.
- Screenshots/landing/trust docs may need polish.

## Agent warning

If a shipped feature looks missing, first verify the canonical file and modules. Do not re-implement from memory or from an old experiment.
