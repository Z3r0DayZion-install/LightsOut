# Changelog

## [5.2.0] — 2026-06-02

### Classic UI (bedtime path)
- **Simple Timer default** — Classic UI unless `-SteamUi`; forces duration mode over stale clock settings
- **Timer amount first** — label, `-`/`+`, spinner, quick chips (10m–60m including 23m), START shows selected minutes
- **Analog countdown ring** — hour ticks, target end-time hand, digital center time, progress arc

### UI polish
- Refined dark palette, elevated schedule card, section labels
- **Start** button uses action color (amber/mint/blue/violet)
- Mode tabs: Countdown / Tonight / Calendar (mint when calendar active)
- Schedule block groups rituals, my timers, and presets
- Tooltips on schedule modes; clearer status and calendar feed line

### My timers and live calendar
- **Saved named timers** — save current duration / at-time / calendar setup; one-tap start from **My timers**
- **+ Save** and **Edit** — up to 24 custom profiles in `settings.json`
- **Live calendar feed** — paste Google/Outlook/Apple **https** iCal URL; auto-refresh (5–240 min) and schedule next event
- Tray: **Save current timer...**, **Calendar live feed...**
- Module: `LightsOut.Profiles.psm1`

## [5.1.0] — 2026-06-02

### Never-before-in-a-timer-app
- **Lights Dim Phase** — 90s progressive darkening ritual after countdown (before final confirm)
- **Sleep Ledger** — local streak/habit tracker from audit log (no cloud)
- **Bedtime Pact** — pledge time; snooze past pact warns and locks after 2 breaks
- **Household Harmony** — export/import plan to sync two PCs within 15 minutes

### Schedule and UX
- **Calendar mode** — import `.ics` from Google/Outlook/Apple; pick event date/time
- **Quick choice panels** at 5m / 1m / 30s warnings (snooze, change action, cancel)
- **Urgency ring colors** — calm → amber → rose as time runs out
- **Global hotkey** loads at startup (Ctrl+Shift+S from tray)
- CLI: `-Calendar path.ics`, `-At "2026-12-31 23:30"`

## [5.0.0] — 2026-06-02

### Lights Out 1.0 — ritual moat
- **One-tap rituals** — Weeknight (24m shutdown), 28:20, Movie (45m sleep), Bedtime (11:30 PM)
- Rituals set action + mode and auto-start; violet highlight for last ritual
- **Sleep Ritual LuxGrid pack** — `packaging/luxgrid/Sleep-Ritual-Pack.json` + `Export-LuxGrid-SleepRitualPack.ps1`
- Docs: [`docs/lights-out/RITUALS.md`](docs/lights-out/RITUALS.md), refreshed `PRODUCT.md` / roadmap

### Shipped in 4.x (now in one product story)
- CLI automation, graceful shutdown, clock schedule, pause/resume, Hibernate/Lock, `powercfg` blocker warn, LuxGrid bridge

## [4.4.0] — 2026-06-02

### Sleep blocker warning (Phase 7.2)
- **`powercfg /requests` check** before starting — warns if apps block sleep/shutdown
- Lists process names and reasons (e.g. video wake lock, playing audio)
- **Blocker warn** checkbox (on by default) — turn off to skip the prompt
- Audit log records blocker count and whether you continued or cancelled

## [4.3.0] — 2026-06-02

### Pause / resume
- **Resume** keeps your remaining time (Start no longer resets the countdown after pause)
- Clear **Paused** UI: subtitle, tray label `PAUSED mm:ss`, tray menu toggles Pause/Resume
- **Cancel** clears a paused countdown without a full emergency stop

### Hibernate and Lock
- **Hibernate** and **Lock** action pills (plus CLI `-Action hibernate|lock`)
- Graceful exit applies only to shutdown/restart (grayed out for lock)

## [4.2.0] — 2026-06-02

### Clock-time schedule
- **At time mode** — shut down at 11:30 PM (not just a countdown duration)
- **Time picker** + bedtime presets (10:30 PM, 11:00 PM, 11:30 PM, midnight)
- **CLI** — `-At 23:30` or `/at 11:30 PM`; env `SLEEPTIMER_AT`
- Rolls to tomorrow if the time already passed today

## [4.1.0] — 2026-06-02

### CLI automation
- **Command-line args** — `-Minutes`, `-Seconds`, `-Action`, `-Start`, `-NoAutoStart`, `-Minimized`, `-DryRun`, `-Help`
- **Slash aliases** — `/minutes 28 /action shutdown /start /min` (Shutdown Timer Classic style)
- **Environment** — `SLEEPTIMER_MINUTES`, `SLEEPTIMER_ACTION`, `SLEEPTIMER_START`, `SLEEPTIMER_NO_AUTOSTART`

### Graceful shutdown
- **Graceful exit** checkbox (on by default) — shutdown/restart without `-Force` so apps can save
- Sleep uses non-critical suspend when graceful is enabled
- Audit log records `force=true/false` on power actions

## [3.9.0] — 2026-06-02

### LuxGrid bridge (optional)
- **LuxGrid RGB** checkbox — off by default; writes timer events to `%LOCALAPPDATA%\LuxGrid\events\inbox\`
- Events: `timer.start`, `timer.tick` (every 30s), `timer.warning` (5m / 60s / 30s), `lights.out` (punch), `timer.completed`, `timer.cancelled`
- Source app: `LightsOut` — pair with LuxGrid Studio **Sleep Ritual** profile
- See `LUXGRID-LIGHTSOUT.md` for full stack setup

## [3.8.0] — 2026-06-02

### Animation
- **Punch + lights out** — when timer hits 0: fist punches the bulb, ring shatters, "LIGHTS OUT" slam, then confirm dialog

## [3.7.1] — 2026-06-02

### Branding
- **Title logo** — `LightsOut-Logo.png` wordmark in app header (moon + ring + type)

## [3.7.0] — 2026-06-02

### Rebrand: Lights Out
- Display name **Lights Out** (exe stays `SleepTimer.exe` for compatibility)
- New moon + ring app icon (`SleepTimer.ico`)
- **Live tray icon** — ring drains as countdown runs (color matches action)
- Last 30s: tray alternates warning + live ring
- Desktop launcher: `Lights Out.bat`

## [3.6.2] — 2026-06-02

### UX & safety
- **30-second alert** — sound, tray balloon, flashing tray icon
- **Start balloon** — "Started — Shutdown at 2:47 PM"
- **5-min warn** includes end time
- **Final confirm** — action-colored, "Shut down now" button, cancel hint
- **Tray menu: Cancel** — same as Ctrl+Shift+S
- Minimize-to-tray balloon shows end time

## [3.6.1] — 2026-06-02

### UX
- **End time clock** — "Ends at 2:47 PM · shutdown" (and preview before start)
- **Active preset highlight** — selected duration pill stays amber
- Tray tooltip shows countdown → end time

## [3.6.0] — 2026-06-02

### Safety & trust
- **Emergency cancel** — `Ctrl+Shift+S` stops countdown (works from tray / minimized)
- **Audit log** — `%LOCALAPPDATA%\CoolTimer\actions.log` (start, stop, snooze, power)
- **60s minimum** timer in production (settings cannot go below 1 minute)
- Window title + tray show live countdown and action when running
- `Test-NoPowerAction` blocks all power commands in CI/dry-run

### CI
- GUI smoke tests removed (no app launch in CI — prevents accidental shutdown)

### Distribution
- Published GitHub Release v3.6.0 on ForgeCore_OS
- Winget package `KickA.SleepTimer` submitted to microsoft/winget-pkgs

## [3.5.0] — 2026-06-02

### UI overhaul
- **Progress ring** with color by action (amber shutdown, mint sleep, blue restart)
- **Pulse glow** last 30 seconds
- **Action pills** instead of dropdown
- **Duration presets** — 24m, 28:20, 30m, 45m (tap while running to extend/change)
- Dark Nightfall theme, styled buttons, card layout

## [3.4.0] — 2026-06-02

### Added
- **System tray** — minimize hides timer; double-click or right-click menu to restore
- **Tray menu** — Show, +10 min, Stop timer, Exit
- **Run at login** — checkbox creates Startup shortcut
- **Minimize to tray** — toggle (on by default)
- **5 min tray balloon** — alongside sound warning
- Close dialog: **Yes** = hide to tray, **No** = stop & exit
- `Publish-GitHubRelease.ps1` for one-shot gh release publish

## [3.3.0] — 2026-06-02

### Fixed
- Countdown tick scoping — timer no longer freezes in compiled exe
- Deploy script no longer resets user settings on rebuild

### Added
- **Sleep** action (Shutdown / Restart / Sleep dropdown)
- Release build from `SleepTimer-Tonight.ps1` (proven nightly source)
- Custom icon on Desktop exe
- Installer targets `SleepTimer.exe` (`SleepTimer-Setup-3.3.0.exe`)
- **CI pipeline**: `CI-Local.ps1`, `Test-SleepTimer.ps1`, GitHub Actions `sleep-timer-ci.yml`
- Dry-run smoke tests for CI (`-DryRun`, `SLEEPTIMER_*` env vars)

### Changed
- Canonical source: `SleepTimer-Tonight.ps1` (not Nightfall bundle)
- `Build-Release.ps1` → `dist\Release\SleepTimer.exe`

## [3.2.0] — 2026-06-01

### Added
- Run at Windows login (shortcut + UI checkbox)
- `Install-Nightfall.ps1` (Program Files + Start Menu)
- Winget manifest template + `Update-WingetHash.ps1`
- GitHub Actions `nightfall-build.yml`
- WPF preview app (`nightfall/src/Nightfall.App`) + Core library
- Custom tray icon from `assets/Nightfall.ico`
- Improved release bundle (embedded host init)

## [3.1.0] — 2026-06-01

### Productization
- `Nightfall.Core` PowerShell module (settings, power, LuxGrid events)
- Release vs Dev build pipeline (`Build-Release.ps1`)
- Inno Setup installer script
- App icon generator, `PRODUCT.md`, MIT license
- Optional LuxGrid event emission (Sleep Ritual bridge)
- About dialog, version in UI
- Release builds: dry run hidden by default

### Nightfall UI (3.0)
- Ring countdown, tray, 5s confirm, dry-run safety
- +5 / +10 snooze, action pills, presets including 28:20

### Original
- Desktop `SleepTimer.exe` — Pro Timer, 28:20 shutdown ritual
