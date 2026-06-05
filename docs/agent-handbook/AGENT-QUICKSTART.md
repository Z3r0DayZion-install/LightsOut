# Agent quickstart

**RC locked:** v5.2.0 internal nightly — see [`docs/lights-out/RC-LOCKED.md`](../lights-out/RC-LOCKED.md).  
Do **not** change code before tonight unless Classic UI fails in real use.

Use this when giving a code agent the fastest possible safe instructions.

## Read first

1. `docs/agent-handbook/00-README.md`
2. `docs/agent-handbook/01-PRODUCT-VISION.md`
3. `docs/agent-handbook/02-ARCHITECTURE.md`
4. `docs/agent-handbook/07-SAFETY-AND-TESTING.md`

## Canonical app

```text
Source:  SleepTimer-Tonight.ps1
Modules: modules\LightsOut.*.psm1
Deploy:  Desktop\Lights Out\SleepTimer.exe
```

**Product rule:** Simple Timer first. Night Lobby second.

```text
Classic UI = duration timer first
Steam UI   = premium Night Lobby
```

## Classic UI bedtime fix (locked RC)

Do **not** redesign Classic UI or add features until live bedtime use confirms the fix.

- Classic is default unless `-SteamUi` is passed
- Classic forces duration mode (ignores stale saved `TimerMode: clock`)
- **Timer amount** is the first visible control (label, `-`/`+`, spinner, quick chips including **23m**)
- START shows current amount (`START · N min`)
- Steam / Night Lobby remains optional only

Regression guards: `scripts\Test-SleepTimer.ps1` (classic-ui-lock checks).  
Full spec: [`docs/lights-out/SIMPLE-TIMER.md`](../lights-out/SIMPLE-TIMER.md).

## Default desktop (live nightly use)

`Desktop\Lights Out\Lights Out.bat` → `-ClassicUi -NoAutoStart` (live, not Demo, not DryRun).

See [`docs/lights-out/SIMPLE-TIMER.md`](../lights-out/SIMPLE-TIMER.md).

```powershell
# USER_LAUNCHER: end-user Desktop shortcut (live Classic UI)
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-NoAutoStart'
```

Agent/manual test only:

```powershell
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-DryRun','-NoAutoStart'
```

Human-requested live run (never in CI — see SIMPLE-TIMER.md):

```text
SleepTimer.exe -ClassicUi -Minutes 23 -Action Shutdown -Start
```

Night Lobby (optional premium UI):

```powershell
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-SteamUi','-DryRun','-NoAutoStart'
```

## UI visual reference (polish north star)

Mockup PNGs: `docs/assets/lights-out/` · Guide: [`docs/lights-out/UI-REFERENCE.md`](../lights-out/UI-REFERENCE.md)

**Before future UI work:**

1. Read `docs/lights-out/UI-REFERENCE.md`.
2. Use `docs/assets/lights-out/` as visual reference assets.
3. Keep Classic UI simple and usable first.
4. Use Steam/Night Lobby for premium polish.
5. Do not replace the canonical `SleepTimer-Tonight.ps1` app.
6. Do not start a new UI stack.
7. Do not change shutdown safety while polishing visuals.

**Launcher split:** normal `Lights Out.lnk` = Classic live (do not change). Premium UI checks = `Lights Out Premium Preview.bat` or `-SteamUi -DryRun -NoAutoStart` only. Never judge Steam UI from the normal shortcut.

## Ecosystem integration (modular)

Lights Out is one module in the Neural ecosystem — **not** a dead-end standalone app, but **standalone first**:

```text
Standalone first.  Modular always.  Hard dependency never.
```

- Core: `SleepTimer-Tonight.ps1` + `modules\LightsOut.*.psm1` — works fully offline
- Bridges: optional local events / JSON / modules (LuxGrid today; NeuralOS, NeuralShell, Snoozurp, NeuralTube later)
- Off by default; no hard deps; no cloud; no new UI stack for integration
- Power gate unchanged: `Do-PowerAction` + `Test-NoPowerAction` only

Contract: [`docs/lights-out/INTEGRATION-CONTRACT.md`](../lights-out/INTEGRATION-CONTRACT.md)

## Docs, README, and CI

| Task | Path / command |
|------|----------------|
| Public README | [`README.md`](../../README.md) |
| User docs | [`docs/lights-out/GETTING-STARTED.md`](../lights-out/GETTING-STARTED.md), [`CLI.md`](../lights-out/CLI.md), [`SAFETY-MODEL.md`](../lights-out/SAFETY-MODEL.md) |
| Doc lint | `.\scripts\Test-Docs.ps1` |
| CI guide | [`docs/lights-out/CI.md`](../lights-out/CI.md) |
| Release QA | [`docs/lights-out/RELEASE-CHECKLIST.md`](../lights-out/RELEASE-CHECKLIST.md) |
| GitHub workflow | `.github/workflows/lights-out-ci.yml` |

**Preserve in all doc edits:**

- Normal launcher = Classic live; Premium Preview = Steam DryRun only
- Standalone first; LuxGrid/NeuralOS optional — never required
- CI never launches real shutdown; never `Deploy-SleepTimer-Desktop.ps1 -Launch` in automation

## Do not touch unless asked

- `CoolTimer.ps1`
- `SleepTimer-Electron/`
- `nightfall/src/`
- Legacy `SleepTimer-*.ps1`
- LuxGrid internals

## Safe test

```powershell
.\scripts\Test-SleepTimer.ps1
.\scripts\Test-AgentSafety.ps1
```

## Safe deploy

```powershell
.\scripts\Deploy-SleepTimer-Desktop.ps1
```

Do not add `-Launch` unless the user asks.

## Safe visual launch

```powershell
Start-Process "C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-DryRun','-NoAutoStart'
```

Do **not** use `-DryRun` alone without `-ClassicUi` for nightly-path checks — default deploy uses Classic.

## Demo Mode (screenshots / marketing / manual UI checks)

Safe full-loop preview — **never performs a real power action**. Demo implies `-DryRun` and skips writes to `settings.json` and `actions.log`.

```powershell
Start-Process "C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-Demo','-NoAutoStart'
Start-Process "C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-Demo','-Seconds','90','-Start'
Start-Process "C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-Demo','-LastLightSequence','ExitTheGrid'
```

Lobby shows: **DEMO MODE** banner, trust badges (`DEMO MODE · DRY-RUN SAFE · …`), Tonight Preview, Tonight Cards, sample Morning Proof (dismissible, not persisted).

See [`docs/lights-out/COHESION-ROADMAP.md`](../lights-out/COHESION-ROADMAP.md) and [`docs/lights-out/DEMO-MODE.md`](../lights-out/DEMO-MODE.md).

## Definition of done

- Tests pass (`Test-SleepTimer.ps1`, `Test-AgentSafety.ps1`, `CI-Local.ps1`).
- No unsafe `SleepTimer.exe` launch added.
- No real power action possible in CI/dry-run.
- Classic UI = default bedtime path; Steam UI = optional premium.
- LuxGrid still optional.
- No experiments substituted for the canonical app.
- **RC locked:** no code changes unless Classic UI fails in real use ([`RC-LOCKED.md`](../lights-out/RC-LOCKED.md)).
