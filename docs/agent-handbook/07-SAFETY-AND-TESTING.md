# Safety and testing

## Read this before running anything

Lights Out can shut down, sleep, restart, hibernate, or lock the user's real PC. Treat testing like testing a power tool, not a toy script.

## Absolute red rules

1. **Never run automated tests that launch `SleepTimer.exe` without `-DryRun`.**
2. **Never add `Start-Process SleepTimer.exe` to scripts unless `-DryRun` is passed.**
3. **Never deploy with `-Launch` unless the user explicitly asks.**
4. **Never lower production minimum below 60 seconds.**
5. **Never bypass `Test-NoPowerAction` inside `Do-PowerAction`.**
6. **Never remove final confirmation unless the user asks and safety is redesigned.**
7. **Never treat CI as allowed to perform real power actions.**

## Safe validation commands

Run these from the repo root unless using full paths.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\KickA\Desktop\CascadeProjects\windsurf-project\scripts\Test-AgentSafety.ps1"
```

Expected role:

- Static scan of scripts and agent docs for unsafe `SleepTimer.exe` launches without `-DryRun`.
- Allows only `USER_LAUNCHER`-marked end-user `.bat` paths and explicit deploy `-Launch` blocks.
- Does not launch the app.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\KickA\Desktop\CascadeProjects\windsurf-project\scripts\Test-SleepTimer.ps1"
```

Expected role:

- Parse checks.
- Static safety patterns.
- `Test-NoPowerAction` logic.
- No GUI timer launch.
- No shutdown/sleep/restart.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\KickA\Desktop\CascadeProjects\windsurf-project\scripts\CI-Local.ps1"
```

Expected role:

- Validate/build pipeline.
- No real timer launch.
- No power action.

## Power action gates

Real power action must be blocked when any of these are active:

| Gate | How it is set |
|---|---|
| Dry-run switch | `-DryRun` |
| Dry-run env | `SLEEPTIMER_DRY_RUN=1` |
| CI env | `SLEEPTIMER_CI=1` |

`Do-PowerAction` must consult `Test-NoPowerAction` before calling `shutdown.exe`, `Stop-Computer`, sleep, restart, hibernate, or lock paths.

## Safe manual visual launch

Only when a human/agent truly needs to see the UI:

```powershell
Start-Process "C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-DryRun','-NoAutoStart'
```

Optional daytime script if present:

```powershell
.\scripts\Test-Daytime.ps1 -Launch -UseExe -Seconds 60
```

Do not use those commands in unattended CI.

## Safe deploy

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\KickA\Desktop\CascadeProjects\windsurf-project\scripts\Deploy-SleepTimer-Desktop.ps1"
```

Deploy rules:

- Copies/builds to `Desktop\Lights Out\`.
- Copies `modules\` next to `SleepTimer.exe`.
- Does not launch by default.
- Do not add `-Launch` unless the user explicitly asks.

## Forbidden patterns

Search for these before marking a task done:

```powershell
Start-Process *SleepTimer.exe*
& *SleepTimer.exe*
.\SleepTimer.exe
shutdown.exe
Stop-Computer
rundll32.exe powrprof.dll,SetSuspendState
```

Not every match is wrong, but every match must be guarded or intentional.

## Known historical failures

| Failure | Cause | Prevention |
|---|---|---|
| Agent nearly shut down machine | Exe launched without dry-run guard | Always pass `-DryRun` in tests/visual checks. |
| Crash on paint | Null theme color table | Use `Get-UiColor` / `Get-SteamUiColor`; initialize palette. |
| App hang/exit | Parse errors from odd punctuation | Use ASCII-safe strings in PowerShell source. |
| Settings overwritten on load | Save handler fired before UI ready | Guard with `$script:UiReady`. |
| Module missing after deploy | Modules not copied next to exe | Run deploy script; verify `Desktop\Lights Out\modules\`. |

## Single-instance troubleshooting

Mutex: `Global\SleepTimerTonight`.

If the app appears not to open:

1. Check Task Manager for stale `SleepTimer.exe`.
2. Kill stale process only if safe and user expects it.
3. Reopen with `-DryRun -NoAutoStart` for testing.

## Audit trail

Audit log path:

```powershell
%LOCALAPPDATA%\CoolTimer\actions.log
```

Use it to confirm starts, cancels, completions, and real power action logs without reproducing the power action.

## Definition of done

Before claiming a code task is done:

- [ ] `scripts\Test-AgentSafety.ps1` passes.
- [ ] `scripts\Test-SleepTimer.ps1` passes.
- [ ] No unsafe `SleepTimer.exe` launch was added.
- [ ] Any power action path is protected by `Test-NoPowerAction`.
- [ ] Production minimum is still 60 seconds.
- [ ] Lobby-first behavior is preserved unless user asked otherwise.
- [ ] Deploy ran only if needed, and without `-Launch` unless asked.
- [ ] `CHANGELOG.md`/version/docs updated if behavior changed.
- [ ] No commit was made unless the user asked.
