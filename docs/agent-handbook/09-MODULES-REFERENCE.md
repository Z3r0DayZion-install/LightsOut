# Modules reference

Modules are loaded from `{AppDir}\modules\` at runtime. In the deployed Desktop app, that means `Desktop\Lights Out\modules\` next to `SleepTimer.exe`.

Missing modules should degrade features where possible, but the app is expected to ship with modules copied by the deploy script.

## Module ownership

| Module | Owns | Does not own |
|---|---|---|
| `LightsOut.SteamTheme.psm1` | Steam UI helpers, palettes, ritual metadata, session copy, tray menu styling. | Power actions, settings persistence, timer loop. |
| `LightsOut.Calendar.psm1` | ICS parsing, local import, remote feed import, upcoming event listing. | UI layout, power action. |
| `LightsOut.Profiles.psm1` | Saved timer profile conversion/deserialization/hints. | Main settings write orchestration. |
| `LightsOut.Novel.psm1` | Sleep ledger, pact helpers, household sync payloads. | Core countdown or shutdown. |

`Nightfall.Core.psm1` is not loaded by the canonical exe. It belongs to the WPF/Nightfall experiment.

## `LightsOut.SteamTheme.psm1`

Purpose: Steam-style chrome and session presentation.

| Export | Role |
|---|---|
| `Get-LightsOutThemePalette` | Return theme color table for `classic` or `steam`. |
| `Set-LightsOutTheme` | Apply palette to form controls. |
| `Get-RitualGameCatalog` | Return ritual metadata for Library. |
| `Get-RitualGameById` | Resolve ritual by ID. |
| `Get-SessionState` | Return Lobby/Running/Paused labels and copy. |
| `Add-SteamFormChrome` | Add sidebar/header/nav shell. |
| `Add-SteamHeroPanel` | Add hero panel host. |
| `Update-SteamExperience` | Refresh hero/sidebar/session UI. |
| `Set-SteamNavHighlight` | Highlight active LIB/SCH/SET page. |
| `New-SteamTrayMenu` | Build tray context menu. |
| `Set-SteamTrayMenuStyle` | Style tray menu. |
| `Get-SteamUiColor` | Safe color lookup for module paint paths. |
| `Add-UiControl` | Helper for parenting controls. |

Color rule: module paint paths should use `Get-SteamUiColor`, not raw `$script:C`.

## `LightsOut.Calendar.psm1`

Purpose: calendar/ICS support.

| Export | Role |
|---|---|
| `Parse-IcsContent` | Parse VEVENT blocks. |
| `Import-IcsCalendarFile` | Load events from local `.ics`. |
| `Import-IcsFromUrl` | Fetch/load events from remote feed. |
| `Test-CalendarFeedUrl` | Validate feed URL shape/connectivity. |
| `Get-IcsUpcomingEvents` | Return upcoming event list. |

User-facing docs: `docs/lights-out/CALENDAR.md`.

## `LightsOut.Profiles.psm1`

Purpose: saved "My timers" profiles.

| Export | Role |
|---|---|
| `ConvertTo-TimerProfile` | Build normalized profile object. |
| `Get-TimerProfileHint` | Produce subtitle/help copy for profile lists. |
| `ConvertFrom-TimerProfilesJson` | Deserialize `SavedTimers`. |

User-facing docs: `docs/lights-out/MY-TIMERS.md`.

## `LightsOut.Novel.psm1`

Purpose: behavioral/novel features.

| Export | Role |
|---|---|
| `Get-SleepLedgerStats` | Return stats from audit log. |
| `Get-PactDeadline` | Compute pact deadline. |
| `Test-SnoozeCrossesPact` | Determine whether snooze violates pact. |
| `New-HouseholdSyncPayload` | Build household sync payload. |
| `Import-HouseholdSyncPayload` | Import household plan. |
| `Test-HouseholdPlansAlign` | Compare household plans. |

User-facing docs: `docs/lights-out/NOVEL-FEATURES.md`.

## Main script owns

Keep these in `SleepTimer-Tonight.ps1` unless there is a strong reason to extract:

| Area | Examples |
|---|---|
| Timer loop | `Start-Timer`, tick handler, pause/resume/cancel. |
| Power | `Do-PowerAction`, `Test-NoPowerAction`, final confirm. |
| Form creation | Main WinForms shell and control instances. |
| Ring paint | Core drawing and state display. |
| Cinema form | Big Picture/Cinema creation and updates. |
| Settings | `Get-Settings`, `Save-Settings`, Run at Login sync. |
| Ritual invocation | Button handlers and session start logic. |
| LuxGrid emission | Optional event writing based on setting. |
| Achievements | Streak detection and toasts. |

## When to extract to a module

Extract only when the code is:

- Self-contained.
- Testable without launching the GUI.
- Not tightly coupled to form controls.
- Over roughly 100 lines or likely to grow.
- Reused across multiple UI paths.

Do not over-module the timer loop. The current architecture intentionally keeps the shipping app simple.

## Module edit checklist

- [ ] Edit `windsurf-project\modules\LightsOut.*.psm1`.
- [ ] Do not rename exports without updating imports/call sites.
- [ ] Run `scripts\Test-SleepTimer.ps1`.
- [ ] Deploy if Desktop app needs updated module copy.
- [ ] Verify `Desktop\Lights Out\modules\` contains the changed module.
