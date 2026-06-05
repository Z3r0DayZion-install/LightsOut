# UI and themes

**Visual north-star mockups:** [`../lights-out/UI-REFERENCE.md`](../lights-out/UI-REFERENCE.md) — reference PNGs in [`../assets/lights-out/`](../assets/lights-out/). Use for polish only; do not redesign the shipping shell from scratch.

**Launcher split:** normal `Lights Out` shortcut = Classic live. Premium Steam/Night Lobby checks = `Lights Out Premium Preview.bat` (`-SteamUi -DryRun -NoAutoStart`) only — never judge premium UI from the normal shortcut.

## UI contract

Lights Out uses a single PowerShell WinForms shell. The default experience is the Steam-style UI.

The UI must make three things obvious:

1. **Am I in Lobby or Session?**
2. **What happens when the timer ends?**
3. **How do I cancel or change it safely?**

Do not optimize only for visual flash. This app controls real shutdown/sleep behavior, so clarity beats decoration.

## WinForms shell

- Single main form (`$form`).
- Steam mode width is approximately 480px.
- Optional always-on-top via `TopMost`.
- Tray icon with live progress while running.
- Global emergency cancel: `Ctrl+Shift+S`.
- Optional Cinema/Big Picture fullscreen overlay.

## Theme modes

| Theme | Flag/setting | Role |
|---|---|---|
| `steam` | `UiTheme = steam`, `-SteamUi` | Default dark library/session UI. |
| `classic` | `UiTheme = classic`, `-ClassicUi` | Older card layout with visible logo. |

Theme switching can happen through settings or `Set-LightsOutTheme`.

## Color safety rules

The app previously hit null `ForeColor` / `BackColor` failures. Do not reintroduce them.

Rules:

- Do not assign `$script:C.SomeKey` directly to `ForeColor` or `BackColor`.
- Use `Get-UiColor` in the main script.
- Use `Get-SteamUiColor` inside Steam module paint paths.
- Initialize palette with `Initialize-LightsOutThemePalette`.
- Keep `Get-BuiltinLightsOutPalette` fallback available.
- Do not put `$script:C` lookups in parameter defaults, especially in `Style-Button`.

## Steam layout

```text
+------------------------------------------+
| Lights Out       v5.2.0        STATS     |
+------+-----------------------------------+
| LIB  | Hero: session title + badge       |
| SCH  | Ring: target time or countdown    |
| SET  | PLAY / PAUSE / RESUME / SNOOZE    |
|      | Rituals, presets, schedule        |
+------+-----------------------------------+
```

## Navigation pages

| Page | Key | Purpose |
|---|---|---|
| Library | `LIB` | Rituals and fast duration presets. |
| Schedule | `SCH` | Duration, clock target, calendar/ICS. |
| Settings | `SET` | Power action pills and collapsed Options. |

Keep advanced checkboxes collapsed behind **Options**. The main screen should not look like a control panel.

## State model

| State | Ring behavior | Primary button | Secondary controls |
|---|---|---|---|
| Lobby | Shows target time/duration, no running arc | `PLAY` | Pause/snooze hidden |
| Running | Shows countdown and progress arc | `PAUSE` | Snooze/cancel visible |
| Paused | Shows frozen remaining time | `RESUME` | Snooze/cancel as configured |

Lobby must never look like an active countdown.

## Lobby-first behavior

On open, no countdown should start unless one of these is true:

- Setting `AutoStart` / Auto-play on open is enabled.
- CLI `-Start` is passed.
- `SLEEPTIMER_START=1` is set.
- A ritual handler explicitly starts immediately.
- Calendar feed auto-start logic starts an eligible event.

`-NoAutoStart` and `SLEEPTIMER_NO_AUTOSTART=1` must force Lobby.

## Key UI functions

| Function | Role |
|---|---|
| `Update-Ui` | Master refresh for labels, ring, buttons, Steam block. |
| `Update-SteamExperience` | Module-driven Steam hero/sidebar/session copy refresh. |
| `Set-SteamMainPage` | Switch LIB/SCH/SET pages. |
| `Update-ScheduleSectionLayout` | Schedule tab layout. |
| `Update-ControlRowLayout` | PLAY/pause/resume/snooze row. |
| `Update-CardOptionsPanel` | Expand/collapse advanced options. |
| `Style-Button` / `Style-Link` | Themed control styling. |
| `Show-SessionToast` | Non-blocking feedback. |
| `Show-SleepLedgerDialog` | Visual stats dialog. |

## Cinema mode

| Item | Detail |
|---|---|
| User-facing name | Cinema mode. |
| Internal name | Big Picture. |
| Entry | Double-click ring, tray menu, or `BigPictureOnStart`. |
| Exit | `Esc` calls `Hide-BigPicture`. |
| Core functions | `Initialize-BigPictureForm`, `Show-BigPicture`, `Update-BigPictureDisplay`. |

Cinema should be calm, readable, and obvious. It should not hide the emergency cancel path if cancellation is available elsewhere.

## Achievements and ledger UI

After successful real power action, streak milestones can trigger achievement toasts:

- 3 nights.
- 7 nights.
- 14 nights.
- 30 nights.

Persist dedupe in `LastAchievementStreak`. Use the sleep ledger for next-morning proof and stats, not raw message boxes.

## Animation rules

Allowed animations:

- Punch at timer zero before confirm.
- Dim phase in final configured seconds.
- Pulse on ring when urgent.
- Toasts for session events.

Avoid animations that confuse state or make the countdown feel started in Lobby.

## String and encoding rules

PowerShell source has had parse problems from fancy punctuation. For new PowerShell user-facing strings, use ASCII-safe punctuation:

- Prefer `-` over em dash.
- Avoid smart quotes.
- Avoid unusual invisible characters.

Markdown docs can be prettier, but source strings should stay boring and safe.
