# Features planned

This file separates real roadmap work from already-shipped behavior. Agents should not assume a planned item is implemented unless they verify it in `SleepTimer-Tonight.ps1`, `modules\`, or tests.

## Current priority: trust and distribution

The local app is useful. The public-product bottleneck is trust.

| Priority | Status | Why it matters |
|---|---|---|
| Production Authenticode signing | Not done | A shutdown app without signing feels sketchy to strangers. |
| Public GitHub Release matches `VERSION` | May lag | Users need the release page to match local truth. |
| Winget package live | In progress/stale until verified | `winget install` is the easiest trust path. |
| Dedicated Lights Out repo/surface | Partial | Monorepo history can confuse users and agents. |
| Screenshots and first-run README | Incomplete | Users must see what it does before running an exe. |
| Public safety explanation | Needs polish | Explain confirmation, dry-run, local-only, no telemetry. |

Exit condition: a stranger can install a signed build, understand it, and trust it without knowing the author.

## Product moat roadmap

The app should not compete as "just a timer." It should become PC bedtime control.

### 1. Sleep Clearance scan

**Status:** v1 **shipped** (Steam lobby panel + `Get-SleepClearanceReport`). See [`SLEEP-CLEARANCE.md`](../lights-out/SLEEP-CLEARANCE.md).

Design reference (broader UI research): [`UI-RESEARCH-REPORT.md`](../lights-out/UI-RESEARCH-REPORT.md)

Pre-PLAY readiness panel:

- Selected action.
- Dry-run/testing status.
- Power blockers.
- Active media apps.
- Downloads likely active.
- Unsaved work risk.
- Windows update/restart risk.
- Current AutoStart state.

Goal: users feel safe pressing PLAY.

### 2. Better Tonight modes

Existing rituals are a good start. Expand only if it keeps the nightly path clear.

Potential modes:

| Mode | Purpose |
|---|---|
| YouTube Mode | Shutdown/sleep even if browser/media keeps the PC active. |
| Steam Download Mode | Wait until downloads finish, then sleep/shutdown. |
| Hard Stop Mode | Strong bedtime boundary, limited snooze. |
| Lock Only Mode | Privacy without shutdown. |
| Update Night | Restart after timer for Windows updates. |
| Discipline Mode | Extra cancel friction while preserving emergency cancel. |

### 3. Next-morning proof

**Status:** v1 **shipped** (Steam hero result + `Get-MorningProofReport`). See [`MORNING-PROOF.md`](../lights-out/MORNING-PROOF.md).

On next launch, show a simple proof card:

- Last completed action.
- Completion time.
- Snoozes used.
- Current streak.
- Estimated time/power saved.
- Link to ledger.

This turns the app into a behavioral loop.

### 4. Last Light Sequences™ (Unplug Sequence)

**Status:** v1 **shipped** (`LightsOut.LastLight.psm1` + timer-zero wiring). See [`LAST-LIGHT-SEQUENCES.md`](../lights-out/LAST-LIGHT-SEQUENCES.md).

### 5. Tonight Cards v1

**Status:** v1 **shipped** — [`TONIGHT-CARDS.md`](../lights-out/TONIGHT-CARDS.md).

### 6. Bedside Remote v1

**Status:** Spec ready — [`BEDSIDE-REMOTE.md`](../lights-out/BEDSIDE-REMOTE.md). **Not implemented.**

Local-only LAN phone control (QR + token). Higher risk — implement after Tonight Cards.

### 7. Anti-cancel friction

Optional friction, never unsafe:

- Hold to cancel for 3 seconds.
- Type a short phrase to cancel a Pact session.
- Snooze limit warnings.
- Show "you already snoozed twice".
- Never remove emergency cancel.

### 8. Profiles and rituals polish

- Cleaner saved profile management.
- Better ritual copy.
- Last-used ritual recall.
- Favorite modes.
- One-click "tonight same as yesterday".

### 9. LuxGrid pack install

LuxGrid should remain optional, but the bridge can become smoother:

- One-click Sleep Ritual pack install.
- Demo events without launching timer.
- Clear status showing whether Studio is watching the inbox.

## Platform roadmap

Optional and not canonical until the user explicitly chooses migration:

| Idea | Status |
|---|---|
| .NET WinUI/WPF rewrite | Future/experiment only. |
| Microsoft Store / MSIX | Future distribution path. |
| Dedicated installer | Useful after signing/version surface is clean. |
| Electron UI | Not canonical; do not default to it. |

## Documentation backlog

- Make `AGENTS.md` short and forceful.
- Keep `PRODUCT.md` version aligned with `VERSION`.
- Add screenshots/GIFs for public trust.
- Add a public "Safety model" section.
- Add a concise "Why not Windows Task Scheduler?" comparison.

## Experiments not to ship as Lights Out

- `CoolTimer.ps1`.
- `SleepTimer-Electron/`.
- Legacy `SleepTimer-*.ps1` variants.
- `nightfall/src/` unless explicitly migrating.
- Old "Sleep Timer Pro" naming unless explicitly revived.

## Implementation rules for planned work

1. Edit `SleepTimer-Tonight.ps1` for canonical behavior.
2. Use `modules\LightsOut.*.psm1` when the feature is self-contained and testable.
3. Update tests for safety-sensitive behavior.
4. Update `CHANGELOG.md`, `VERSION`, `$script:AppVersion`, and this handbook when behavior changes.
5. Run `scripts\Test-SleepTimer.ps1`.
6. Never launch the real exe without `-DryRun`.
