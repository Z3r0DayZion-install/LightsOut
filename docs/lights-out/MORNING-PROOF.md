# Morning Proof™ — design

**Status:** v1 implemented in `SleepTimer-Tonight.ps1` + `LightsOut.Novel.psm1` (Steam lobby hero)
**Product:** Lights Out (`SleepTimer-Tonight.ps1`)  
**Pairs with:** [`SLEEP-CLEARANCE.md`](SLEEP-CLEARANCE.md) (pre-PLAY trust)

---

## Product purpose

Sleep Clearance answers:

> **Am I safe to start?**

Morning Proof answers:

> **Did Lights Out actually work?**

It closes the **trust loop** on the next app open — without cloud accounts, sleep-health claims, or an analytics dashboard.

| Generic timer | Lights Out with Morning Proof |
|---------------|-------------------------------|
| User guesses if shutdown happened | User sees last run result in lobby |
| No habit feedback | Streak + snooze count from local log |
| Countdown ends the product | **Lobby → PLAY → session → result screen** |

**Positioning:** A Steam-style **post-game result card**, not a wellness app.

---

## Session loop (unique angle)

```text
Lobby (Clearance)  →  PLAY  →  Session (countdown)  →  Power / dry-run end
                                                              ↓
Next open: Morning Proof in hero  →  Dismiss  →  Lobby (tonight again)
```

Most timer apps stop at countdown. Lights Out gets a full **game loop** using existing Steam UI pieces: hero panel, ring, LIB/SCH/SET, STATS link, Sleep Ledger.

---

## UI placement (Steam-first)

### v1: Hero panel takeover (lobby only)

Morning Proof **replaces the normal lobby hero copy** until dismissed. It is **not** a separate modal wizard or analytics page.

```text
+------------------------------------------+
| Lights Out       v5.2.0        STATS     |
+------+-----------------------------------+
| LIB  | ┌ LAST NIGHT'S RUN ─────────────┐ |
| SCH  | │ Mission complete              │ |
| SET  | │ 11:32 PM · Shutdown · 0 snooze│ |
|      | │ 4-night streak                │ |
|      | └───────────────────────────────┘ |
|      | [Sleep Clearance panel — normal]  |
|      | Ring: subtle ✓ completed badge    |
|      | [PLAY TONIGHT AGAIN]              |
|      | [VIEW LEDGER]  [DISMISS]          |
+------+-----------------------------------+
```

**Placement rules:**

1. Show only in **lobby** (`-not $Running -and -not $Paused`).
2. Hero title/tagline carry the proof; ring shows optional **completed** badge (small check or “DONE” arc) until dismiss.
3. **Sleep Clearance stays visible** below hero — tonight’s pre-flight is separate from last night’s result.
4. **PLAY** remains available (labeled **PLAY TONIGHT AGAIN** while proof is showing).
5. **DISMISS** clears proof for this session end; hero returns to normal ritual copy.
6. **VIEW LEDGER** opens existing `Show-SleepLedgerDialog` (no new stats UI in v1).
7. Classic UI v1: compact card above Start (same copy, same buttons) — Steam is primary.

### What appears once vs what persists

| Element | Once (until dismiss) | Always in STATS |
|---------|----------------------|-----------------|
| “Last night’s run” hero copy | Yes | No |
| Ring completed badge | Yes | No |
| Streak count | Shown on proof | Yes (`lblLedger` / STATS) |
| Best streak, nights, snoozes, cancels | Via VIEW LEDGER | Yes (ledger dialog) |
| Seven-day dots | Ledger only | Ledger only |
| Achievement toasts (3/7/14/30) | Still on real `power_action` | N/A |

**Persistence:** one new settings field (see Data).

---

## Data sources (local only)

### Primary: audit log

Path: `%LOCALAPPDATA%\CoolTimer\actions.log`  
Format: `ISO8601 event detail...` (see [`04-SETTINGS-AND-DATA.md`](../agent-handbook/04-SETTINGS-AND-DATA.md))

**Session parsing (v1):** walk log **newest-first**. Find the latest **terminal** event for the previous run:

| Terminal event | Proof state | Notes |
|----------------|-------------|-------|
| `power_action` | **completed** | Real shutdown/sleep/restart/hibernate/lock |
| `power_blocked` | **dry-run completed** | Safe mode / CI / `-DryRun` — no real power |
| `emergency_cancel` | **cancelled** | User aborted via hotkey |
| `final_cancelled` | **cancelled** | User backed out at final confirm |
| `timer_cancelled` | **cancelled** | Paused session cleared |
| (none / only old unrelated lines) | **unknown** | First run or no prior session |

**Session window:** from the matching `timer_started` line **before** that terminal event (if any) through the terminal line.

**Fields extracted from session window:**

| Field | Source |
|-------|--------|
| Completion time | Timestamp of terminal event |
| Action | `timer_started` detail `action=` or `power_*` detail |
| Mode | `timer_started` detail `mode=` |
| Snoozes | Count of `snooze` lines in window |
| Ritual | Nearest preceding `ritual_selected` in window (optional v1) |
| Dry-run | Terminal is `power_blocked` |

### Secondary: Sleep Ledger

Reuse `Get-SleepLedgerStats` in `modules/LightsOut.Novel.psm1` for:

- `Streak`, `BestStreak`, `NightsDone`, `Snoozes`, `Cancels`, `WeekDots`

Do **not** duplicate streak math in v1.

### New settings key (v1)

| Key | Default | Purpose |
|-----|---------|---------|
| `MorningProofLastSeen` | `''` | ISO timestamp of last terminal event already shown in Morning Proof |

**Show proof when:** latest terminal event timestamp **>** `MorningProofLastSeen` (and state is not `unknown`).

**On dismiss:** set `MorningProofLastSeen` = that event’s timestamp; save settings.

No new cloud fields. No telemetry.

---

## Proposed API (implementation)

```powershell
function Get-MorningProofReport {
    param(
        [string]$AuditLogPath = $script:AuditLogPath,
        [string]$LastSeen = ''
    )

    # Returns [pscustomobject]@{
    #   State      = 'completed' | 'dry-run' | 'cancelled' | 'unknown'
    #   ShowProof  = $true/$false   # false if already seen or unknown
    #   CompletedAt = [DateTime]
    #   TimeLabel  = '11:32 PM'
    #   Action     = 'Shutdown'
    #   Mode       = 'duration'
    #   SnoozeCount = 0
    #   Streak     = 4              # from Get-SleepLedgerStats
    #   ResultLine = 'Clean shutdown path'
    #   HeroTitle  = 'Mission complete'
    #   HeroTagline = '11:32 PM · Shutdown · 4-night streak'
    #   Headline   = 'LIGHTS OUT COMPLETE'
    #   Subtitle   = 'Last run: 11:32 PM · Action: Shutdown · Snoozes: 0'
    #   EventKey   = '2026-06-03T23:32:01...'  # for LastSeen write
    # }
}
```

Place in `SleepTimer-Tonight.ps1` or `LightsOut.Novel.psm1` (prefer **Novel module** next to `Get-SleepLedgerStats`).

UI hooks in `LightsOut.SteamTheme.psm1`:

- `Show-SteamMorningProofHero` / `Clear-SteamMorningProofHero` — or extend `Update-SteamExperience` when `$MorningProof` is set.

---

## Display states and copy

### 1. Completed (real power)

```text
Hero title:    Mission complete
Hero tagline:  11:32 PM · Shutdown · 4-night streak
Headline:      LIGHTS OUT COMPLETE
Subtitle:      Last run: 11:32 PM · Action: Shutdown · Snoozes: 0
Result line:   Clean shutdown path
Ring badge:    ✓ (subtle green arc)
```

### 2. Dry-run completed

```text
Hero title:    Dry run complete
Hero tagline:  11:32 PM · Shutdown (simulated) · 4-night streak
Headline:      DRY RUN COMPLETE
Subtitle:      No power action ran · Snoozes: 0
Result line:   Safe mode — PC stayed on
Ring badge:    ✓ (muted blue, not green)
```

Label honestly. Never imply the PC shut down.

### 3. Cancelled

```text
Hero title:    Session ended early
Hero tagline:  Cancelled at 11:15 PM · 2 snoozes
Headline:      RUN CANCELLED
Subtitle:      Last session did not finish · Streak unchanged tonight
Result line:   No shutdown logged
Ring badge:    none (or neutral dash)
```

Still show once if user had a terminal cancel after `timer_started` — builds honesty, not shame.

### 4. Unknown / no previous session

Do **not** show Morning Proof panel. Normal lobby hero only.

---

## Buttons (v1)

| Button | Behavior |
|--------|----------|
| **PLAY TONIGHT AGAIN** | Same as PLAY — starts tonight’s run (Clearance + existing gates unchanged) |
| **VIEW LEDGER** | `Show-SleepLedgerDialog` |
| **DISMISS** | Sets `MorningProofLastSeen`, restores normal hero + ring |

Optional v1.1: **Same ritual as last night** (reads last `ritual_selected` from session window).

---

## Safety (non-negotiable)

1. **No startup auto-shutdown** — Morning Proof is read-only UI on open.
2. **No change to `Do-PowerAction`** or `Test-NoPowerAction`.
3. **No change to minimum timer** or lobby-first default.
4. **No auto-start** triggered by proof display.
5. **No LuxGrid requirement** — proof works with RGB off.
6. **No fake sleep metrics** — do not claim hours slept, sleep score, or health grades in v1.
7. **No network** — parse local log only.
8. Agents testing: still **never** launch `SleepTimer.exe` without `-DryRun`.

If audit log is missing or corrupt → `unknown`, hide proof, do not error-loop.

---

## v1 scope vs later

### v1 (implement next)

| Item | In |
|------|-----|
| `Get-MorningProofReport` | Yes |
| `MorningProofLastSeen` setting | Yes |
| Steam hero takeover + dismiss | Yes |
| Ring completed badge (completed / dry-run only) | Yes |
| Reuse ledger streak + session snooze count | Yes |
| VIEW LEDGER button | Yes |
| Classic compact card | Nice-to-have same PR |

### v1.1+

| Item | Notes |
|------|-------|
| “Same ritual as last night” button | Reads audit `ritual_selected` |
| Result persists in header until midnight | Instead of dismiss-only |
| Tray balloon on boot | Optional; hero is enough for v1 |

### Explicitly out of scope (report ideas deferred)

- Sleep score / letter grades
- Weekly graphs in proof card
- Energy kWh estimates
- Social share
- Post-login separate window (use hero, not second splash)
- Browser / Steam download analytics

See [`UI-RESEARCH-REPORT.md`](UI-RESEARCH-REPORT.md) — treat dashboard wireframes as v2+ unless scoped.

---

## Interaction with existing features

| Feature | Relationship |
|---------|----------------|
| Sleep Clearance | Both visible in lobby; Clearance = tonight, Proof = last night |
| Achievement toasts | Still fire on real `power_action`; Proof does not replace them |
| Sleep Ledger | Proof links to it; streak source of truth unchanged |
| Bedtime Pact | Cancel proof may mention pact breaks later; v1 ignores |
| Cinema / Big Picture | Proof shows in main form lobby first; Cinema unchanged |
| Auto-play on open | Proof shows **before** user commits; if AutoStart, proof visible briefly then existing auto-start rules apply (same as Clearance note) |

**Conflict with UI research report:** Report suggests blocking PLAY when Clearance warns. **Do not** block PLAY on Morning Proof — ever.

---

## Tests needed before / during implementation

### Unit (no GUI, no exe launch)

Add to `Test-SleepTimer-Logic.ps1` or `Test-MorningProof-Logic.ps1`:

| Test | Assert |
|------|--------|
| Temp log: `timer_started` → `power_action` | `State=completed`, `ShowProof=$true` |
| Temp log: `timer_started` → `power_blocked` | `State=dry-run`, honest copy |
| Temp log: `timer_started` → `emergency_cancel` | `State=cancelled` |
| Empty log | `State=unknown`, `ShowProof=$false` |
| `LastSeen` ≥ event time | `ShowProof=$false` |
| Session snooze count | Two `snooze` lines between start and end → `SnoozeCount=2` |

### Static

| Test | Assert |
|------|--------|
| `Test-SleepTimer.ps1` | `Get-MorningProofReport` exists |
| `Test-AgentSafety.ps1` | Still passes |

### Manual (human, `-DryRun` only)

```powershell
Start-Process "C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-DryRun','-NoAutoStart'
```

1. Run session to `power_blocked` completion.  
2. Close app, reopen with `-DryRun`.  
3. See dry-run proof → Dismiss → normal hero.  
4. STATS / ledger unchanged and still correct.

---

## Implementation sketch (when approved)

| Step | File | Change |
|------|------|--------|
| 1 | `modules/LightsOut.Novel.psm1` | `Get-MorningProofReport` |
| 2 | `Get-Settings` / `Save-Settings` | `MorningProofLastSeen` |
| 3 | `LightsOut.SteamTheme.psm1` | Hero proof mode + ring badge |
| 4 | `SleepTimer-Tonight.ps1` | Wire on `$script:UiReady`, `Update-Ui` lobby branch |
| 5 | `Test-SleepTimer-Logic.ps1` | Temp-log tests |
| 6 | `docs/agent-handbook/05-FEATURES-SHIPPED.md` | Mark shipped after v1 |

**Do not** add a second stats system. **Do not** parse log on every timer tick — once on lobby `Update-Ui` is enough.

---

## Definition of done (v1)

- [ ] Proof appears in Steam lobby hero after a completed or cancelled terminal session.
- [ ] Each terminal event shown **once** until dismiss.
- [ ] Dry-run labeled honestly.
- [ ] PLAY, Clearance, and power gates behave exactly as before.
- [ ] VIEW LEDGER opens existing dialog.
- [ ] All data local; no new network code.
- [ ] `Test-AgentSafety.ps1`, `Test-SleepTimer.ps1`, `CI-Local.ps1` pass.

---

## Related docs

| Doc | Use |
|-----|-----|
| [`SLEEP-CLEARANCE.md`](SLEEP-CLEARANCE.md) | Pre-PLAY trust (shipped v1) |
| [`NOVEL-FEATURES.md`](NOVEL-FEATURES.md) | Sleep Ledger, pact, household |
| [`UI-RESEARCH-REPORT.md`](UI-RESEARCH-REPORT.md) | Broader UI research (partial alignment table at top) |
| [`../agent-handbook/03-UI-AND-THEMES.md`](../agent-handbook/03-UI-AND-THEMES.md) | Lobby/session UI contract |
| [`../agent-handbook/06-FEATURES-PLANNED.md`](../agent-handbook/06-FEATURES-PLANNED.md) | Roadmap parent |

---

## One-line summary

**Morning Proof = next-open Steam hero result card parsed from local `actions.log`, shown once per completed/cancelled run, dismissible, ledger-linked — proof the bedtime session happened, not a analytics product.**
