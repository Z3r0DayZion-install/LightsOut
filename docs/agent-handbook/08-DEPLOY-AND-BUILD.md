# Deploy and build

## Canonical Desktop layout

```text
C:\Users\KickA\Desktop\Lights Out\
  SleepTimer.exe
  Lights Out.bat
  modules\
    LightsOut.Calendar.psm1
    LightsOut.Novel.psm1
    LightsOut.Profiles.psm1
    LightsOut.SteamTheme.psm1
  source\
    SleepTimer-Tonight.ps1
  archive\
    SleepTimer.exe.bak
```

Runtime requirement: `modules\` must sit next to `SleepTimer.exe`. Missing modules cause feature degradation and UI/calendar/profile issues.

## Daily deploy

From repo root:

```powershell
cd C:\Users\KickA\Desktop\CascadeProjects\windsurf-project
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Deploy-SleepTimer-Desktop.ps1
```

Switch behavior:

| Switch | Meaning | Agent rule |
|---|---|---|
| none | Build if needed and copy to Desktop | Safe default. |
| `-SkipBuild` | Copy existing build only | OK when build already exists. |
| `-Launch` | Start app after deploy | Do not use unless user explicitly asks. |

## Build pipeline

1. Source: `SleepTimer-Tonight.ps1`.
2. Builder: ps2exe.
3. App mode: STA, no console.
4. Output: `SleepTimer.exe`.
5. Deploy: copy exe, modules, launcher, source reference, backup old exe.
6. Release package: `scripts\Build-Release.ps1`.

## Version sync

When producing a release or changing user-visible behavior, check/update:

- `VERSION`.
- `$script:AppVersion`.
- Steam header/about strings.
- `CHANGELOG.md`.
- `PRODUCT.md` if public copy references version.
- This handbook if behavior/contracts changed.

## Source repo paths

| Item | Path |
|---|---|
| Main script | `windsurf-project\SleepTimer-Tonight.ps1` |
| Modules | `windsurf-project\modules\` |
| Tests | `windsurf-project\scripts\Test-SleepTimer.ps1` |
| Local CI | `windsurf-project\scripts\CI-Local.ps1` |
| Desktop deploy | `windsurf-project\scripts\Deploy-SleepTimer-Desktop.ps1` |
| Release build | `windsurf-project\scripts\Build-Release.ps1` |

## Agent edit workflow

1. Read this handbook and relevant section.
2. Edit `SleepTimer-Tonight.ps1` and/or `modules\LightsOut.*.psm1`.
3. Run `scripts\Test-SleepTimer.ps1`.
4. If Desktop update is needed, run deploy without `-Launch`.
5. Tell user to open `Desktop\Lights Out\Lights Out.bat` manually unless they asked you to launch.

## Public release workflow

Use only when preparing a public artifact:

1. Confirm `VERSION` and `$script:AppVersion` match.
2. Run safe tests.
3. Build release package.
4. Verify `SleepTimer.exe` exists and modules are included.
5. Generate/update checksums.
6. Update changelog and public README/PRODUCT docs.
7. Confirm signing status. If unsigned/dev-signed, say so honestly.
8. Do not claim winget/install availability unless verified.

## Settings survive deploy

Deploying to Desktop does not erase user data:

```text
%LOCALAPPDATA%\CoolTimer\settings.json
%LOCALAPPDATA%\CoolTimer\actions.log
```

Do not wipe those files unless the user explicitly asks.

## LuxGrid deploy

Optional second step:

```powershell
.\scripts\Install-LuxGrid-LightsOut.ps1
```

This only prepares the optional RGB event bridge. It is not required for Lights Out.

## Do not replace canonical app

Do not swap in these unless explicitly requested:

- `CoolTimer.ps1`.
- `SleepTimer-Electron/`.
- `nightfall/src/`.
- Legacy `SleepTimer-*.ps1`.
- Any new rewrite stack.
