# Last Light Sequences™ — design

**Status:** v1 implemented in `SleepTimer-Tonight.ps1` + `LightsOut.LastLight.psm1`
**Product:** Lights Out (`SleepTimer-Tonight.ps1`)  
**Public line:** *Unplug from the feed. End the session. Save the night.*  
**Cyber pack (internal codename):** Unplug Sequence™  
**Pairs with:** [`SLEEP-CLEARANCE.md`](SLEEP-CLEARANCE.md) (pre-PLAY), [`MORNING-PROOF.md`](MORNING-PROOF.md) (post-run proof)

---

## Product purpose

Sleep Clearance answers **“Am I safe to start?”**  
Morning Proof answers **“Did it work?”**  
Last Light Sequences answer **“How does the session end?”**

When the timer hits zero, Lights Out should not feel like a generic alarm. It should play a short, ritualized **reality-break finale** — glitch, darken, fade — then hand off to the **existing** final confirm and power gates.

| Generic timer | Lights Out with Last Light |
|---------------|----------------------------|
| “Time’s up” dialog | Scripted unplug sequence |
| Abrupt shutdown feel | Dim → portal ring → fade to black |
| No narrative | Cyber copy that names the real enemy (the feed, the loop, the glow) |

**Positioning:** A Steam-style **session finale**, not a movie reference or wellness gimmick.

**Naming rule:** Public copy must be original. Do **not** ship “Matrix mode,” “Red Pill,” or other third-party IP in user-facing strings. Internal codenames are fine.

---

## Session loop (where this fits)

```text
Lobby (Clearance)  →  PLAY  →  Session (ring + optional Cinema)
                                      ↓ timer = 0
                              Last Light Sequence  (NEW)
                                      ↓
                              Dim phase (optional, existing)
                                      ↓
                              Final confirm (existing Show-FinalConfirm)
                                      ↓
                              Do-PowerAction + Test-NoPowerAction (unchanged)
                                      ↓
Next open: Morning Proof
```

Most timer apps stop at zero. Lights Out already has punch animation, dim phase, Cinema, and LuxGrid events — Last Light **rethemes** that finale layer; it does **not** replace Windows shutdown or safety code.

---

## Existing hooks (do not reinvent)

| Piece | Location | Role today |
|-------|----------|------------|
| Timer zero | `$script:timer` tick when `$script:Left -le 0` | Calls `Start-PunchAnimation { Invoke-AfterTimerEnd }` |
| Punch panel | `Start-PunchAnimation`, `Draw-PunchScene`, `pnlPunch` | ~1.2s fist animation at zero |
| Dim phase | `Start-LightsDimPhase`, `pnlDim`, `DimPhaseEnabled` | Optional fade before final confirm |
| Final confirm | `Complete-TimerEnd` → `Show-FinalConfirm` | Snooze / cancel / proceed |
| Power action | `Do-PowerAction`, `Test-NoPowerAction` | **Untouched by this feature** |
| Cinema | `Show-BigPicture`, `BigPictureOnStart` | Fullscreen session overlay |
| LuxGrid | `Publish-LuxGridEvent` | Optional; `lights.out`, `lights.dim`, `timer.completed`, etc. |

**Integration point (v1):** At timer zero, keep **punch first**, then `Start-LastLightSequence` when enabled, then existing dim → `Complete-TimerEnd`. Visual only — never call `Do-PowerAction` from sequence code.

```text
Start-PunchAnimation
Start-LastLightSequence   (if LastLightEnabled)
Start-LightsDimPhase      (if DimPhaseEnabled)
Show-FinalConfirm
Do-PowerAction / Test-NoPowerAction
```

---

## v1 sequences (ship these three + classic)

| Setting value | Public name | Best for |
|---------------|-------------|----------|
| `ClassicFade` | Classic Fade | Default; calm punch + dim |
| `ExitTheGrid` | Exit the Grid™ | Default cyberpunk finale |
| `AntiAlgorithm` | Anti-Algorithm Protocol™ | Hard Stop / viral copy |
| `SignalSeverance` | Signal Severance™ | Polished product feel; pairs with Clearance |

Use **ASCII-safe internal ids** (PascalCase per [`AGENT-IDEA-BRIEF.md`](AGENT-IDEA-BRIEF.md)). Normalize legacy/snake_case on load.

Additional modes (Feed Collapse, Neural Disconnect, Rabbit Hole Exit, etc.) are **v1.1+** copy packs — same engine, different script tables.

### Exit the Grid™

```text
GRID LOCK DETECTED
Dopamine loop active.

Breaking signal...
Disconnecting feed...
Exiting the grid...

You are no longer available to the system.
```

Visual: ring becomes circular “disconnect portal,” UI darkens, fade to black before final confirm.

### Anti-Algorithm Protocol™

```text
ANTI-ALGORITHM PROTOCOL

Autoplay resisted.
Recommendations ignored.
Infinite scroll denied.
Session ending.

The algorithm lost tonight.
```

Primary button on final confirm may read **UNPLUG** (copy only — same confirm logic).

### Signal Severance™

```text
SIGNAL SEVERANCE INITIATED

Browser noise: muted
Video loop: severed
System glow: fading
Session: terminated

Signal severed. Night secured.
```

Visual: checklist lines tick off sequentially (system decontamination list).

### Classic Fade

Existing punch + dim copy. No new animation engine required — baseline for tests and users who want calm.

---

## Shared copy blocks (all sequences)

**Sequence open (optional overlay):**

```text
LAST LIGHT
Your session is ending.
```

**Final 5 seconds (countdown overlay during dim or sequence tail):**

```text
5  Signal fading
4  Feed collapsing
3  Screen dimming
2  Session closing
1  Lights out
```

**Completion stamp (before final confirm):**

```text
UNPLUGGED
Night recovered.
```

Dry-run: replace completion with honest copy — **No power action will run.**

---

## Settings (SET page)

```text
Last Light Sequence
[x] Enable Last Light finale

[ Classic Fade            v ]
  Exit the Grid
  Anti-Algorithm Protocol
  Signal Severance

[ ] Use Cinema Mode for finale   (LastLightUseCinema)
[x] Dim screen during finale     (existing DimPhaseEnabled)
[ ] LuxGrid pulse                (LastLightLuxPulse — v1.1 with master EmitLuxGridEvents)
```

### Settings keys

| Key | Default | Meaning |
|-----|---------|---------|
| `LastLightEnabled` | `true` | Master switch; when false, punch → dim → confirm only |
| `LastLightSequence` | `'ClassicFade'` | `ClassicFade` \| `ExitTheGrid` \| `AntiAlgorithm` \| `SignalSeverance` |
| `LastLightUseCinema` | `false` | Open/use Cinema for finale overlay (separate from session `BigPictureOnStart`) |
| `LastLightLuxPulse` | `false` | Extended LuxGrid finale events when `EmitLuxGridEvents` (v1.1) |

Existing keys reused: `DimPhaseEnabled`, `DimPhaseSeconds`, `BigPictureOnStart`, `EmitLuxGridEvents`, `ConfirmAtEnd`.

---

## Tonight Cards integration (v1.1 — after Tonight Cards ship)

| Tonight Card | Default sequence |
|--------------|------------------|
| Weeknight | `SignalSeverance` |
| Movie | `ClassicFade` (+ Cinema optional) |
| Bedtime | `ExitTheGrid` |
| Hard Stop | `AntiAlgorithm` |
| Custom | User-selected from SET |

See [`TONIGHT-CARDS.md`](TONIGHT-CARDS.md).

---

## UI behavior

### When sequence runs

1. Timer reaches `0` — stop tick timer, set `$Running = $false` (same as today).
2. If Cinema active, sequence renders on Big Picture form **or** main form hero (prefer fullscreen when Cinema visible).
3. Play sequence script (~8–15s for v1; dry-run capped like dim at 5s).
4. On sequence complete → existing `Invoke-AfterTimerEnd` (dim if enabled).
5. Dim complete → `Complete-TimerEnd` / `Show-FinalConfirm` — **unchanged**.

### Cancel / emergency during sequence

- **Ctrl+Shift+S** emergency cancel must still work (abort sequence, restore lobby).
- User cancel at final confirm → existing `final_cancelled` audit + LuxGrid `timer.cancelled`.
- Sequence abort must not call `Do-PowerAction`.

### Steam session state

During Last Light, UI is in **session-ending** state (not lobby). Ring may show portal/disconnect animation instead of countdown. Sleep Clearance hidden; Morning Proof unaffected.

---

## LuxGrid (optional, v1.1)

Do **not** require LuxGrid. When `EmitLuxGridEvents` is on:

| Moment | Suggested effect |
|--------|------------------|
| Sequence start | Green/cyan scanning pulse (`last_light.start`) |
| 5 seconds left | Keys drain left-to-right |
| Final second | One white flash |
| Lights out | All black (`lights.out` — already emitted at zero today) |
| Dry run | Blue pulse instead of blackout |
| Cancel | Red flicker, then restore |

New event names are **additive** — existing pack consumers must ignore unknown events. Document in `11-LUXGRID-INTEGRATION.md` when shipped.

---

## Proposed API (implementation)

Prefer `modules/LightsOut.SteamTheme.psm1` or a small `modules/LightsOut.LastLight.psm1` for testability.

```powershell
function Get-LastLightSequenceCatalog {
    # Returns ordered list of @{ Id; Name; Description; Lines; FinalLine; ConfirmButton }
}

function Get-LastLightSequenceReport {
    param(
        [string]$SequenceId = 'ClassicFade',
        [bool]$DryRun = $false
    )
    # Returns copy + timing hints for UI; no side effects
}

function Start-LastLightSequence {
    param(
        [string]$SequenceId,
        [scriptblock]$OnComplete,
        [System.Windows.Forms.Control]$HostPanel,
        [bool]$DryRun
    )
    # Drives animation timer; calls OnComplete once; idempotent stop
}
```

`SleepTimer-Tonight.ps1` timer tick change (conceptual):

```powershell
if ($script:Left -le 0) {
    ...
    Start-PunchAnimation {
        if ($script:LastLightEnabled) {
            Start-LastLightSequence -SequenceId $script:LastLightSequence -OnComplete { Invoke-AfterTimerEnd } ...
        } else {
            Invoke-AfterTimerEnd
        }
    }
}
```

---

## Safety (non-negotiable)

1. **Do not change** `Do-PowerAction` or `Test-NoPowerAction`.
2. **Do not bypass** `Show-FinalConfirm` when `ConfirmAtEnd` is true.
3. **Do not auto-shutdown** at sequence end — only after existing confirm + gates.
4. **Dry-run honesty** — finale copy must not imply real shutdown.
5. **Emergency cancel** remains one chord (Ctrl+Shift+S).
6. **LuxGrid optional** — sequence works with RGB off.
7. **No network** — local UI only.
8. Agents: never launch `SleepTimer.exe` without `-DryRun` for testing.

---

## v1 scope vs later

### v1 (first implementation)

| Item | In |
|------|-----|
| `LastLightEnabled`, `LastLightSequence`, SET dropdown | Yes |
| `LastLightUseCinema` setting | Yes |
| Three cyber sequences + Classic Fade | Yes |
| Punch → Last Light → dim → final confirm | Yes |
| Dry-run shortened sequence + honest copy | Yes |
| `LastLightLuxPulse` + LuxGrid events | No (v1.1) |
| Tonight Card defaults | No (v1.1 with [`TONIGHT-CARDS.md`](TONIGHT-CARDS.md)) |

### v1.1+

- `LastLightLuxPulse` + documented LuxGrid finale events
- Tonight Card → sequence mapping
- Signal Severance lines fed from Sleep Clearance scan (e.g. show active blocker names)
- Classic UI parity (compact sequence panel)

### Explicitly out of scope

- Replacing Windows shutdown UI
- Health / sleep-score claims in finale copy
- Share cards / social export
- AI-generated nightly scripts
- Blocking cancel during sequence (anti-cancel friction is a separate feature)

---

## Tests needed

### Unit (no GUI, no exe)

Add to `Test-SleepTimer-Logic.ps1` or `Test-LastLight-Logic.ps1`:

| Test | Assert |
|------|--------|
| `Get-LastLightSequenceCatalog` | Contains v1 four IDs |
| Unknown sequence id | Falls back to `ClassicFade` |
| `LastLightEnabled` false | Skips sequence; punch → dim → confirm |
| No direct `Do-PowerAction` in sequence module | Static grep |
| `Get-LastLightSequenceReport -DryRun` | Honest dry-run final line |
| Sequence id roundtrip in settings JSON | Save/load |

### Static

| Test | Assert |
|------|--------|
| `Test-SleepTimer.ps1` | `LastLightSequence` / `Start-LastLightSequence` present after ship |
| `Test-AgentSafety.ps1` | Still passes |

### Manual (human, `-DryRun` only)

```powershell
Start-Process "C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-DryRun','-NoAutoStart'
```

1. SET → Exit the Grid → short duration → PLAY.  
2. Watch sequence → dim → final confirm → dry-run completion.  
3. Reopen → Morning Proof shows dry-run honestly.  
4. Emergency cancel mid-sequence → lobby, no power.

---

## Implementation sketch (when approved)

| Step | File | Change |
|------|------|--------|
| 1 | `modules/LightsOut.LastLight.psm1` (new) or `LightsOut.SteamTheme.psm1` | Catalog + `Start-LastLightSequence` |
| 2 | `Get-Settings` / `Save-Settings` | `LastLightSequence` |
| 3 | `SleepTimer-Tonight.ps1` | Timer-zero branch; SET dropdown |
| 4 | `LightsOut.SteamTheme.psm1` | Sequence panel / portal ring draw helpers |
| 5 | `Test-SleepTimer-Logic.ps1` | Catalog + settings tests |
| 6 | `docs/agent-handbook/04-SETTINGS-AND-DATA.md` | Schema row |
| 7 | `docs/agent-handbook/05-FEATURES-SHIPPED.md` | Mark shipped after v1 |

---

## Definition of done (v1)

- [ ] User can pick Classic / Exit the Grid / Anti-Algorithm / Signal Severance in SET.
- [ ] Non-classic sequences play at timer zero before dim/confirm.
- [ ] Final confirm and power gates behave exactly as before.
- [ ] Dry-run uses honest copy and shortened timing.
- [ ] Emergency cancel aborts sequence safely.
- [ ] Cinema + dim toggles still work.
- [ ] LuxGrid not required.
- [ ] `Test-AgentSafety.ps1`, `Test-SleepTimer.ps1`, `CI-Local.ps1` pass.

---

## Related docs

| Doc | Use |
|-----|-----|
| [`SLEEP-CLEARANCE.md`](SLEEP-CLEARANCE.md) | Pre-PLAY trust (shipped) |
| [`AGENT-IDEA-BRIEF.md`](AGENT-IDEA-BRIEF.md) | Master agent handoff + build order |
| [`TONIGHT-CARDS.md`](TONIGHT-CARDS.md) | LIB tiles (planned) |
| [`MORNING-PROOF.md`](MORNING-PROOF.md) | Post-run proof (shipped) |
| [`UI-RESEARCH-REPORT.md`](UI-RESEARCH-REPORT.md) | Broader UI research |
| [`../agent-handbook/03-UI-AND-THEMES.md`](../agent-handbook/03-UI-AND-THEMES.md) | Cinema, lobby/session contract |
| [`../agent-handbook/04-SETTINGS-AND-DATA.md`](../agent-handbook/04-SETTINGS-AND-DATA.md) | Settings schema |
| [`../agent-handbook/06-FEATURES-PLANNED.md`](../agent-handbook/06-FEATURES-PLANNED.md) | Roadmap parent |

---

## One-line summary

**Last Light Sequences = timer-zero cyber finale layered on existing punch/dim/confirm/power flow — original Unplug copy, three v1 modes, settings-driven, LuxGrid optional, safety gates untouched.**
