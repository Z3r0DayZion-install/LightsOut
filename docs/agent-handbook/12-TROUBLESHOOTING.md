# Troubleshooting

Use this when fixing real bugs. Prefer safe debug commands. Do not reproduce a shutdown bug by launching the timer unsafely.

## First safe checks

```powershell
# Parse/static/safety checks
.\scripts\Test-SleepTimer.ps1

# Settings inspection
Get-Content "$env:LOCALAPPDATA\CoolTimer\settings.json" | ConvertFrom-Json

# Audit trail
Get-Content "$env:LOCALAPPDATA\CoolTimer\actions.log" -Tail 30
```

Safe visual launch if needed:

```powershell
Start-Process "C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-DryRun','-NoAutoStart'
```

## App will not start

| Symptom | Likely cause | Fix |
|---|---|---|
| Instant exit | Parse error in `SleepTimer-Tonight.ps1` | Run `Test-SleepTimer.ps1`; check recent string edits. |
| Opens then disappears | Single-instance/mutex or unhandled startup exception | Check Task Manager and audit/log output. |
| Hangs on open | Stale process, blocked modal, module import issue | Kill stale `SleepTimer.exe` only if safe; verify modules. |
| Crash on paint | Null color/palette | Use `Get-UiColor`; initialize palette before paint. |

## UI looks wrong

| Symptom | Cause | Fix |
|---|---|---|
| Green arc in Lobby | Running arc drawn while idle | Ensure state is Lobby; no progress arc until Running. |
| Countdown starts on open | AutoStart, CLI/env start, ritual/feed auto-start | Check `AutoStart`, `-Start`, `SLEEPTIMER_START`, feed settings. |
| PLAY/pause controls confusing | Wrong session state | Check `Get-SessionState`/`Get-UiSessionState` data flow. |
| Too many options visible | Options panel not collapsed | Restore SET page collapsed Options behavior. |
| Steam colors missing | Palette import/fallback failed | Initialize built-in palette and use safe color getters. |

## ForeColor / BackColor null

Root cause: `$script:C` empty or accessed too early.

Fix pattern:

1. Initialize palette at startup.
2. Use `Get-UiColor` for main controls.
3. Use `Get-SteamUiColor` in module paint code.
4. Avoid `$script:C` in function parameter defaults.

## Modules not loading

| Check | Action |
|---|---|
| `Desktop\Lights Out\modules\` exists | If missing, rerun deploy. |
| Module filenames match imports | Fix names or imports. |
| Import errors are swallowed | Temporarily add safe diagnostics, do not crash user path. |
| Feature degraded | Verify relevant module is present and exported functions exist. |

## Settings not sticking

Likely causes:

- `Save-Settings` fired during initial UI binding.
- Handler ran before `$script:UiReady`.
- Setting key mismatch.
- Running-state guard blocked save.
- Deploy used new exe but old settings remained.

Fix:

- Confirm key exists in `Get-Settings` default schema.
- Guard load-time handlers.
- Inspect `%LOCALAPPDATA%\CoolTimer\settings.json`.

## Power action happened or nearly happened during test

Stop and verify:

- Was `-DryRun` passed?
- Was `SLEEPTIMER_DRY_RUN=1` set?
- Was `SLEEPTIMER_CI=1` set in CI?
- Does `Do-PowerAction` call `Test-NoPowerAction`?
- Did any script call `Start-Process SleepTimer.exe` without safe args?

Search:

```powershell
Select-String -Path .\**\*.ps1 -Pattern "Start-Process.*SleepTimer.exe|shutdown.exe|Stop-Computer|SetSuspendState"
```

## Calendar / ICS issues

| Issue | Check |
|---|---|
| No events | Valid ICS file, readable path, `LightsOut.Calendar.psm1` present. |
| Feed stale | `CalendarFeedIntervalMin`, feed timer, last sync setting. |
| Wrong event shown | `CalendarEventUid`, upcoming event sorting. |
| Feed starts unexpectedly | `CalendarFeedAutoStart`, AutoStart precedence. |

## LuxGrid no lights

Check in order:

1. Checkbox is enabled.
2. `EmitLuxGridEvents` is true in settings.
3. `Install-LuxGrid-LightsOut.ps1` created inbox folders.
4. Event JSON files are written.
5. LuxGrid Studio is watching the inbox.
6. Studio demo mode reacts without timer launch.

## Toast/balloon silent

Ensure the message variable is assigned in every branch before `ShowBalloonTip` or toast call. This previously affected session feedback paths.

## When to read more context

Read:

- `CHANGELOG.md` for regression after a version bump.
- `PRODUCT_ROADMAP.md` for phase intent.
- `docs/agent-handbook/` for canonical rules.
- Prior session notes only when the bug is clearly from a recent large UI pass.
