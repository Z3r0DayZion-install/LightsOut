# CLI and automation

The CLI exists for shortcuts, task scheduler, tests, and power users. It must not compromise the default lobby-first safety model.

## Parameters

| Switch | Aliases | Meaning |
|---|---|---|
| `-Minutes` | `-m`, `-mins` | Countdown minutes. |
| `-Seconds` | `-sec`, `-s` | Countdown seconds. |
| `-Action` | `-a` | `shutdown`, `sleep`, `restart`, `hibernate`, `lock`. |
| `-Start` | none | Start countdown on launch. |
| `-NoAutoStart` | none | Force Lobby and ignore AutoStart. |
| `-Minimized` | none | Start minimized/tray. |
| `-DryRun` | none | Block real power action. |
| `-Help` | none | Show CLI help dialog. |
| `-SteamUi` | none | Force Steam theme. |
| `-ClassicUi` | none | Force Classic theme. |
| `-ScheduleAt` | `-schedule` | Clock/datetime schedule target. |
| `-IcsPath` | none | Load calendar from ICS file. |

Slash forms are parsed in `Apply-StartupArguments`, such as `/minutes`, `/action`, `/start`, `/min`, `/at`, and `/calendar`.

## Environment variables

| Variable | Effect |
|---|---|
| `SLEEPTIMER_SECONDS` | Sets seconds. |
| `SLEEPTIMER_MINUTES` | Sets minutes. |
| `SLEEPTIMER_ACTION` | Sets action. |
| `SLEEPTIMER_MINIMIZED=1` | Starts minimized/tray. |
| `SLEEPTIMER_NO_AUTOSTART=1` | Forces Lobby. |
| `SLEEPTIMER_START=1` | Starts countdown on open unless no-autostart wins. |
| `SLEEPTIMER_AT` | Schedule string. |
| `SLEEPTIMER_CALENDAR` | ICS path. |
| `SLEEPTIMER_DRY_RUN=1` | Blocks real power action. |
| `SLEEPTIMER_CI=1` | CI safe mode; blocks real power action. |

## Auto-start precedence

Default is Lobby.

Precedence:

1. `-NoAutoStart` or `SLEEPTIMER_NO_AUTOSTART=1` forces Lobby.
2. Else `-Start`, `SLEEPTIMER_START=1`, or setting `AutoStart` can start.
3. Ritual handlers may start if their design is immediate-start.
4. Calendar feed auto-start may start when configured and eligible.

Document this clearly whenever changing CLI behavior.

## Action normalization

`Normalize-ActionName` accepts short/common forms and converts to canonical action names.

Examples:

| Input | Canonical |
|---|---|
| `shut` | `Shutdown` |
| `shutdown` | `Shutdown` |
| `reboot` | `Restart` |
| `restart` | `Restart` |
| `hib` | `Hibernate` |
| `lock` | `Lock` |

## Examples

Safe visual test:

```powershell
SleepTimer.exe -DryRun -NoAutoStart -Seconds 120
```

Weeknight automation:

```powershell
SleepTimer.exe -Minutes 24 -Action Shutdown -Start
```

Bedtime clock but do not auto-start from open:

```powershell
SleepTimer.exe -ScheduleAt "23:30" -Action Shutdown -NoAutoStart
```

Task Scheduler safe test:

```powershell
SleepTimer.exe -Minutes 5 -Action Shutdown -Start -DryRun
```

## Scheduler guidance

For real user automation, use explicit arguments. Do not rely on hidden defaults.

Recommended real pattern:

```powershell
SleepTimer.exe -ScheduleAt "23:30" -Action Shutdown -Start
```

Recommended test pattern:

```powershell
SleepTimer.exe -ScheduleAt "23:30" -Action Shutdown -Start -DryRun
```

## Graceful shutdown

`GracefulShutdown` defaults to true. It avoids forced shutdown so apps can save. CLI should not silently override this unless a new explicit option is added and documented.

## Emergency cancel

`Ctrl+Shift+S` should work regardless of CLI launch mode once the form handle is registered.

## CLI safety rules

- Tests must include `-DryRun` or `SLEEPTIMER_DRY_RUN=1`.
- CI must set or respect `SLEEPTIMER_CI=1`.
- Do not add headless real shutdown paths that bypass the UI safety model.
- Keep `-NoAutoStart` strong enough to force Lobby.
