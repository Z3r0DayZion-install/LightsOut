# Product vision

## Core idea

**Lights Out is the missing bedtime mode for Windows PCs.**

It is not just a shutdown timer. A generic timer says: "run a command later." Lights Out says: **pick tonight's mode, press PLAY, and the PC handles bedtime safely.**

The strongest market angle is people who fall asleep with a PC, gaming rig, media setup, stream, YouTube, movie, or download running. Windows sleep settings often fail because media, downloads, USB devices, games, or blockers keep the system awake. Lights Out gives the user an intentional ritual and a clear finish line.

## North star

**Open -> choose tonight's run -> PLAY -> visible countdown -> final confirmation -> safe power action.**

The product should feel like starting a Steam session, except the "game" is shutting the night down.

## What problem it solves

Users want:

- One-tap PC bedtime control.
- A reliable shutdown, sleep, restart, hibernate, or lock after a known window.
- A clock-based bedtime target such as 11:30 PM.
- Confidence that the app will not accidentally shut down during testing or setup.
- A final confirm/cancel path before real power action.
- Optional atmosphere, stats, rituals, and RGB without cloud dependency.

## Target user

Primary:

- A single Windows user controlling their own PC at night.
- Gamers, stream watchers, YouTube/Prime/Netflix users, downloaders, and people who fall asleep at the computer.

Secondary:

- Household users who want aligned bedtime shutdowns.
- Power users who want CLI/scheduler automation.
- LuxGrid users who want optional RGB sleep ritual effects.

Not target:

- Enterprise fleet management.
- Server cron replacement.
- Cloud-based parental control.
- A generic automation suite.

## Product positioning

| Lights Out is | Lights Out is not |
|---|---|
| Bedtime mode for Windows | A generic "run exe later" utility |
| A PC sleep/shutdown ritual | Enterprise endpoint management |
| Local-only by default | Cloud account, telemetry, subscription core |
| WinForms + ps2exe portable app | Required Electron/Store app |
| Safe, confirmable, cancelable | Silent forced shutdown tool |
| Optional LuxGrid RGB bridge | RGB-dependent software |

## The product moat

The moat is not the countdown. Anyone can count down.

The moat is the **bedtime control layer**:

1. **Lobby-first UX** - the user intentionally starts the session.
2. **Tonight modes** - Weeknight, Movie, Bedtime, Classic, and future discipline modes.
3. **Safety trust** - dry-run, confirmation, emergency cancel, production minimums.
4. **Readiness intelligence** - blocker warnings, future "Sleep Clearance" scan.
5. **Behavior loop** - sleep ledger, streaks, achievements, pact, next-morning proof.
6. **Atmosphere** - Cinema mode and optional LuxGrid RGB.

## Core user journey

1. Launch from `Desktop\Lights Out\Lights Out.bat` or `SleepTimer.exe`.
2. Land in **Lobby**. No active countdown unless AutoStart, CLI `-Start`, or an immediate-start ritual/feed explicitly requests it.
3. Choose a ritual, duration, clock time, calendar event, or saved profile.
4. Choose power action: Shutdown, Sleep, Restart, Hibernate, or Lock.
5. Press **PLAY**.
6. Watch session state through the ring, tray icon, warnings, and optional Cinema mode.
7. Pause, snooze, or emergency-cancel if needed.
8. At zero, show punch/final confirm.
9. Perform the power action unless blocked by dry-run/CI safety gates.
10. Log the event for ledger/stats/debugging.

## Naming contract

| Name | Meaning |
|---|---|
| **Lights Out** | Product/display name. |
| **SleepTimer.exe** | Historical executable filename. Keep for compatibility. |
| **CoolTimer** | Legacy settings folder under `%LOCALAPPDATA%`. Do not rename casually. |
| **Sleep Ritual** | LuxGrid/event framing and user-facing ritual language. |
| **Lobby** | Pre-PLAY state. No active countdown. |
| **Session** | Running or paused countdown after PLAY. |

## UI philosophy

Steam theme is the default because it makes the timer feel like a nightly session, not a utility panel.

- **LIB:** Rituals and fast presets.
- **SCH:** Tonight scheduling: duration, clock, calendar.
- **SET:** Power action, options, safety toggles.
- **Ring:** Target time in Lobby; countdown/progress only during Session.
- **PLAY:** The primary commitment button.
- **Cinema:** Fullscreen bedtime display.

Do not turn the lobby into a wall of toggles. Hide advanced options behind collapse panels or settings pages.

## On-vision changes

A change is on-vision if it:

- Makes the nightly path faster, clearer, or safer.
- Improves trust before a power action.
- Makes the app more obviously useful than a basic shutdown timer.
- Keeps LuxGrid optional.
- Preserves local-first behavior.
- Strengthens the ritual/streak/ledger loop without adding clutter.

## Off-vision changes

A change is off-vision if it:

- Replaces the canonical script without explicit direction.
- Adds cloud dependency to the core timer.
- Starts the countdown by surprise.
- Removes final confirmation or dry-run gates.
- Makes RGB required.
- Adds broad automation features unrelated to bedtime control.
- Bloats the lobby with every possible setting.

## Best next product direction

The highest-leverage future feature is **Sleep Clearance**: a pre-flight check before PLAY that shows whether the PC is ready for bedtime.

Potential checks:

- Media/video active.
- Downloads active.
- Power blockers detected.
- Unsaved app risk.
- Windows update/restart state.
- Final selected action.
- Dry-run status when testing.

This would make Lights Out feel like a trustworthy control system, not just a countdown.
