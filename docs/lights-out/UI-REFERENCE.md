# UI visual reference (north star mockups)

**Canonical app:** `SleepTimer-Tonight.ps1` → `Desktop\Lights Out\SleepTimer.exe`

These mockups are **visual north stars** for polish on the shipping Lights Out WinForms shell — not pixel-perfect specs and not a license to replace the working UI with a new design.

## Before future UI work

UI references are preserved in repo memory, not chat history.

1. Read this file (`docs/lights-out/UI-REFERENCE.md`).
2. Use `docs/assets/lights-out/` as visual reference assets.
3. Keep Classic UI simple and usable first.
4. Use Steam/Night Lobby for premium polish.
5. Do not replace the canonical `SleepTimer-Tonight.ps1` app.
6. Do not start a new UI stack.
7. Do not change shutdown safety while polishing visuals.
8. **Do not judge Steam UI from the normal Lights Out shortcut** — use Premium Preview only.

## Launcher split (confirmed)

| Launcher | Mode |
|---|---|
| `Lights Out.lnk` / `Lights Out.bat` | Classic live bedtime (`-ClassicUi -NoAutoStart`) — **do not change** |
| `Lights Out Premium Preview.bat` | Steam / Night Lobby DryRun (`-SteamUi -DryRun -NoAutoStart`) |

Do **not** judge premium mockup work by double-clicking the normal shortcut. Any premium UI polish must be verified through Premium Preview:

```powershell
Get-Process SleepTimer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-SteamUi','-DryRun','-NoAutoStart'
```

Classic and Steam are two modes in the same canonical WinForms shell — not a new UI stack. Do not change `Do-PowerAction` or `Test-NoPowerAction`.

## Ecosystem note

Lights Out is standalone first but **modular for ecosystem integration** — not a closed one-off. Optional bridges (LuxGrid, NeuralOS, NeuralShell, Snoozurp, future apps) connect via local events/JSON/modules only. Hard dependency never.

```text
Standalone first.  Modular always.  Hard dependency never.
```

Integration contract: [`INTEGRATION-CONTRACT.md`](INTEGRATION-CONTRACT.md)

## Agent rule

When touching UI (ring, lobby, Steam mode, Classic mode, Last Light, Morning Proof):

1. Open the relevant reference image below.
2. Polish toward the mockup — readability, spacing, glow, hierarchy.
3. **Do not** redesign from scratch or swap in a separate experiment (`CoolTimer.ps1`, Electron, WPF).
4. **Classic stays simple.** **Steam / Night Lobby gets premium treatment.**

## Visual north star

- Dark premium Windows app
- Readable timer first
- Glowing but not cluttered
- Analog/digital ring as the central control
- Classic = simple timer path (`-ClassicUi`)
- Night Lobby = premium path (`-SteamUi`)

## Reference images (repo)

| Repo asset | Surface | Use for |
|---|---|---|
| [`../assets/lights-out/classic-simple-timer-reference.png`](../assets/lights-out/classic-simple-timer-reference.png) | **Classic UI / Simple Timer** | Timer amount first, quick chips, ring, action pills, START — minimal layout |
| [`../assets/lights-out/night-lobby-reference.png`](../assets/lights-out/night-lobby-reference.png) | **Night Lobby / premium dashboard** | Header, hero card, dark premium layout, trust badges, ring placement |
| [`../assets/lights-out/morning-proof-reference.png`](../assets/lights-out/morning-proof-reference.png) | **Morning Proof / app interface** | Proof/result layout, clean dark card, stats rows, polished readability |
| [`../assets/lights-out/last-light-reference.png`](../assets/lights-out/last-light-reference.png) | **Last Light / final disconnect** | Exit the Grid, shutdown finale, full-screen overlay, countdown drama |

## Original mockup filenames (2026-06-04)

Preserved in repo under `docs/assets/lights-out/` with stable names:

| Original (chat/session) | Repo copy |
|---|---|
| `lights_out_pc_bedtime_mode_dashboard.png` | `night-lobby-reference.png` |
| `lights_out_pc_app_interface.png` | `morning-proof-reference.png` |
| `lights_out_pc_final_disconnect_sequence.png` | `last-light-reference.png` |
| *(Classic — capture or regen)* | `classic-simple-timer-reference.png` |

## Surface → code map

| UI surface | Primary code | CLI preview |
|---|---|---|
| Classic Simple Timer | `SleepTimer-Tonight.ps1` (Classic branch), ring paint | `-ClassicUi -DryRun -NoAutoStart` |
| Night Lobby | `modules\LightsOut.SteamTheme.psm1`, Tonight Cards | `-SteamUi -DryRun -NoAutoStart` |
| Morning Proof | `modules\LightsOut.Novel.psm1` (proof dialog) | `-Demo -NoAutoStart` |
| Last Light | `modules\LightsOut.LastLight.psm1` | `-Demo -LastLightSequence ExitTheGrid` |

## Related docs

- [`SIMPLE-TIMER.md`](SIMPLE-TIMER.md) — Classic UI contract
- [`COHESION-ROADMAP.md`](COHESION-ROADMAP.md) — Night Lobby cohesion
- [`LAST-LIGHT-SEQUENCES.md`](LAST-LIGHT-SEQUENCES.md) — finale sequences
- [`MORNING-PROOF.md`](MORNING-PROOF.md) — proof screen behavior
- [`../agent-handbook/03-UI-AND-THEMES.md`](../agent-handbook/03-UI-AND-THEMES.md) — theme and layout rules

## Classic vs premium launchers

| Launcher | UI | Safe? | Use |
|---|---|---|---|
| `Lights Out.bat` / `Lights Out.lnk` | **Classic** | Live | Real bedtime — timer amount first |
| `Lights Out Premium Preview.bat` | **Steam / Night Lobby** | DryRun | Premium mockup polish preview only |

Double-clicking the normal desktop shortcut **should** show Classic. That is intentional.

## Safe preview commands

```powershell
# Classic polish reference
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-DryRun','-NoAutoStart'

# Night Lobby polish reference (or double-click Lights Out Premium Preview.bat)
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-SteamUi','-DryRun','-NoAutoStart'

# Full loop (Morning Proof + cards)
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-Demo','-NoAutoStart'

# Last Light finale
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-Demo','-LastLightSequence','ExitTheGrid'
```
