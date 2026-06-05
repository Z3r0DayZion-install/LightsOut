# Architecture

## Canonical shape

```text
windsurf-project/
  SleepTimer-Tonight.ps1          # canonical app source, PowerShell WinForms monolith
  VERSION                         # release/version string
  modules/
    LightsOut.SteamTheme.psm1     # Steam UI, theme, session copy
    LightsOut.Calendar.psm1       # ICS/calendar import and feed
    LightsOut.Profiles.psm1       # saved timer profiles
    LightsOut.Novel.psm1          # ledger, pact, household helpers
  scripts/
    Test-SleepTimer.ps1           # safe parse/static/safety tests
    CI-Local.ps1                  # local validate/build pipeline
    Deploy-SleepTimer-Desktop.ps1 # canonical Desktop deploy

Desktop\Lights Out\
  SleepTimer.exe                  # ps2exe output
  Lights Out.bat                  # user launcher
  modules\                        # required at runtime
  source\SleepTimer-Tonight.ps1   # copied source reference
  archive\SleepTimer.exe.bak      # previous exe backup
```

There is no separate shipping .NET project. There is no required Electron runtime. The monolith script plus runtime modules is the product.

## Source of truth

| Artifact | Canonical path |
|---|---|
| Main app source | `windsurf-project/SleepTimer-Tonight.ps1` |
| Runtime modules | `windsurf-project/modules/LightsOut.*.psm1` |
| Version file | `windsurf-project/VERSION` |
| In-script version | `$script:AppVersion` inside `SleepTimer-Tonight.ps1` |
| Desktop binary | `C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe` |
| Desktop launcher | `C:\Users\KickA\Desktop\Lights Out\Lights Out.bat` |

When versioning changes, keep `VERSION`, `$script:AppVersion`, Steam header/about text, `CHANGELOG.md`, and public docs aligned.

## Runtime model

- UI stack: PowerShell WinForms.
- Build output: `SleepTimer.exe` via ps2exe, STA, no console.
- Main thread: WinForms form/dialog loop.
- Countdown: 1-second timer.
- Pulse/ring: UI animation timer.
- Calendar feed: periodic poll timer.
- Global hotkey: `Ctrl+Shift+S` emergency cancel.
- Single instance: `Global\SleepTimerTonight` mutex.

## Module loading

Modules are loaded from `{AppDir}\modules\` next to the executable. The Desktop deploy must copy modules every time.

| Module | Runtime role | Failure behavior |
|---|---|---|
| `LightsOut.SteamTheme.psm1` | Palettes, Steam layout, session text, tray styling | Main script should fall back to built-in palette where possible. |
| `LightsOut.Calendar.psm1` | ICS file/feed parsing and event listing | Calendar mode degrades/alerts if unavailable. |
| `LightsOut.Profiles.psm1` | Saved timers/profiles in settings JSON | Profile UX degrades if unavailable. |
| `LightsOut.Novel.psm1` | Sleep ledger, pact, household sync | Novel/social features degrade if unavailable. |

Do not rename module files without updating imports and deploy packaging.

## Representative global state

| Variable | Meaning |
|---|---|
| `$script:Running` | Countdown is active. |
| `$script:Paused` | Countdown is paused. |
| `$script:Left` / `$script:Total` | Remaining and total seconds. |
| `$script:Action` | Current power action. |
| `$script:TimerMode` | `duration`, `clock`, or `calendar`. |
| `$script:DefaultSec` | Lobby duration when not running. |
| `$script:UseSteamUi` | Steam theme active. |
| `$script:C` | Theme color table. Must never be assumed non-null in UI paint paths. |
| `$script:UiReady` | Form loaded and safe to save UI-driven settings. |
| `$script:AutoStartOnOpen` | From settings `AutoStart`, unless overridden by CLI/env. |

## Edit map

| Area | Primary edit location |
|---|---|
| Timer lifecycle | `Invoke-StartTimer`, `Start-Timer`, `Stop-Timer`, `Resume-Timer` in main script. |
| Power actions | `Do-PowerAction`, `Test-NoPowerAction`, `Complete-TimerEnd`. |
| Settings | `Get-Settings`, `Save-Settings`, settings load/apply handlers. |
| Steam UI layout | Main script layout plus `LightsOut.SteamTheme.psm1`. |
| Theme colors | `Get-UiColor`, `Get-BuiltinLightsOutPalette`, module palette functions. |
| Ring paint | Main script paint handlers; module color resolve helpers. |
| Tray | `Update-TrayProgressIcon`, `New-SteamTrayMenu`, tray handlers. |
| Cinema | `Initialize-BigPictureForm`, `Show-BigPicture`, `Hide-BigPicture`, `Update-BigPictureDisplay`. |
| Calendar | `LightsOut.Calendar.psm1` plus main UI binding. |
| Profiles | `LightsOut.Profiles.psm1` plus settings persistence. |
| Ledger/pact/household | `LightsOut.Novel.psm1`. |
| LuxGrid events | Main script event emission; keep optional. |

## Safety invariants

These are architecture rules, not preferences:

- `Do-PowerAction` must consult `Test-NoPowerAction` before any real shutdown/sleep/restart/hibernate action.
- `-DryRun`, `SLEEPTIMER_DRY_RUN=1`, and `SLEEPTIMER_CI=1` must block real power actions.
- The app must not auto-start a countdown from Lobby unless explicitly configured/requested.
- Production minimum stays 60 seconds.
- Emergency cancel remains available from tray and `Ctrl+Shift+S`.
- Deploy scripts must not auto-launch unless explicitly asked.

## Experiments and non-canonical stacks

Do not treat these as Lights Out unless the user explicitly names them:

| Path/name | Status |
|---|---|
| `CoolTimer.ps1` | Older Nightfall/CoolTimer experiment. |
| `SleepTimer-*.ps1` | Legacy variants. |
| `SleepTimer-Electron/` | Separate stack/experiment. |
| `nightfall/src/` | WPF/WinUI-style future preview, not shipping canonical. |
| `repos/sleeptimer-*` | Related splits/experiments. |
| LuxGrid internals | Optional RGB bridge only; not core timer architecture. |

## Agent rule of thumb

If the user says "sleep timer" or "Lights Out" without naming another file, edit `SleepTimer-Tonight.ps1` and, if needed, `modules\LightsOut.*.psm1`. Do not go hunting through experiments.
