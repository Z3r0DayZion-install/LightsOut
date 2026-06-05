# Sleep Clearance™ — design

**Status:** v1 implemented in `SleepTimer-Tonight.ps1` (Steam lobby panel)
**Product:** Lights Out (`SleepTimer-Tonight.ps1`)  
**Goal:** Trust before shutdown — show readiness before PLAY, proof after completion (proof = separate feature)

---

## User problem

People do not fear the countdown. They fear **surprise failure**:

- "I pressed start but Steam is still downloading."
- "I thought it would sleep, but a browser tab kept the PC awake."
- "I forgot it was set to shutdown, not sleep."
- "Something blocked power and I only found out at 0:00."

A generic shutdown timer hides this until it is too late. **Sleep Clearance** answers one question before PLAY:

> **Is tonight's run set up the way I think it is?**

That is the trust hook — not more timer modes.

---

## Product positioning

| Generic timer | Lights Out with Sleep Clearance |
|---------------|----------------------------------|
| "Run command in N minutes" | "Bedtime control ritual" |
| User discovers blockers at zero | User sees blockers before PLAY |
| Settings scattered | One pre-flight panel |
| No confidence signal | **Clear for Lights Out** or **N things may keep your PC awake** |

Sleep Clearance does **not** replace final confirmation at zero. It adds **pre-flight clarity** in the lobby.

---

## UI placement (lobby-first)

Sleep Clearance lives in **Lobby only**, never during an active session countdown.

### Steam UI (default)

```text
+------------------------------------------+
| Lights Out       v5.2.0        STATS     |
+------+-----------------------------------+
| LIB  | Hero: session title               |
| SCH  | Ring: target time (lobby)         |
| SET  | ┌ Sleep Clearance ──────────────┐ |
|      | │ ✓ Shutdown · 24m · lobby-first│ |
|      | │ ⚠ 2 things may delay sleep    │ |
|      | └───────────────────────────────┘ |
|      | PLAY / rituals / schedule         |
+------+-----------------------------------+
```

**Placement rules:**

1. Panel sits **above PLAY**, below hero/ring — visible before the user commits.
2. Collapsed to one line when **Clear for Lights Out** (green/neutral Steam accent).
3. Expanded or highlighted when warnings exist (amber, not alarm-red).
4. Tapping the panel opens a **read-only detail sheet** (modal or inline expand) — no new navigation page in v1.
5. **PLAY stays enabled** even with warnings (user choice), but warnings must be visible first.
6. If user opens app with **AutoStart** enabled, show Clearance for ~2s or until dismissed, then start — never skip silently.

### Classic UI

Same information in a compact card above the Start button. Same lobby-only rule.

---

## Checks shown before PLAY

Each row is **read-only** in v1. No toggles inside Clearance (change settings on SET / Options).

| Check | Source (existing) | Shown as |
|-------|-------------------|----------|
| **Power action** | `$script:Action`, action pills | "Shutdown" / "Sleep" / "Lock" / … |
| **Timer mode** | `TimerMode`, duration / clock / calendar UI | "24 min" / "At 11:30 PM" / "Calendar: Movie night" |
| **Auto-start status** | `AutoStart`, lobby-first behavior | "Lobby-first" or "Auto-start on open" |
| **App blockers** | `Get-PowerRequestBlockers` (`powercfg /requests`) | Count + top 1–2 names, or "None detected" |
| **Downloads / media warning** | Heuristic v1 (see below) | "Possible active download/media" or clear |
| **Safety gate** | `ConfirmAtEnd`, `GracefulShutdown`, emergency cancel | "5s confirm · graceful · Ctrl+Shift+S" |
| **LuxGrid** | `EmitLuxGridEvents` | "RGB off" or "LuxGrid on (optional)" |

### Summary line (the hook)

| Condition | Headline |
|-----------|----------|
| No warnings | **Clear for Lights Out** |
| 1 warning | **1 thing may keep your PC awake** |
| N warnings | **N things may keep your PC awake** |

Warnings are **informational**, not blocking (except where existing blocker confirm already applies at PLAY — see below).

---

## Safe fallback behavior

1. **Never perform power actions** during Clearance scan — read-only queries only.
2. **Never block PLAY** solely because Clearance failed to scan — show "Could not verify blockers" and let user proceed.
3. **Reuse existing blocker gate** at PLAY: `Invoke-StartTimer` already calls `Get-PowerRequestBlockers` + `Confirm-PowerBlockerWarning`. Clearance **surfaces the same data earlier**; it does not duplicate modal spam unless user taps for detail.
4. **Dry-run / CI:** Clearance runs normally but labels power action as simulated; `Test-NoPowerAction` unchanged.
5. **Lock action:** skip sleep-specific blocker sections (already done in `Get-PowerRequestBlockers`).
6. **Local only:** no network, no cloud score, no telemetry. Optional audit log entry: `clearance_scan` with counts only (no PII).

---

## v1 vs later

### v1 (first ship — small and safe)

| Item | v1 scope |
|------|----------|
| Lobby panel with summary + 7 check rows | Yes |
| Data from settings + `Get-PowerRequestBlockers` | Yes |
| Media/download heuristic (process name list) | Best-effort, clearly labeled "may" |
| Detail expand / modal | Simple list |
| Auto-refresh on setting change in lobby | Yes (debounced) |
| Session / running state | Hidden |
| LuxGrid required | **No** — checkbox state only |
| Next-morning proof card | **No** — separate feature |
| Anti-cancel friction | **No** |
| Tonight modes (YouTube / Steam Download) | **No** — design hooks only |

### v1.1+

| Item | Notes |
|------|-------|
| Steam / browser / qBittorrent-specific hints | Named apps with icons |
| Download completion wait modes | Ties to "Better Tonight modes" roadmap |
| Windows Update pending restart | `powershell` query or registry, best-effort |
| Unsaved document risk | Hard on Windows; defer or manual "I saved" ack |
| Clearance history in audit log | Streak / proof integration |

### Explicitly out of scope

- Cloud "sleep score"
- LuxGrid-driven clearance (RGB optional forever)
- Blocking PLAY without override
- Replacing 5s final confirm or emergency cancel

---

## Media / download heuristic (v1)

Conservative, local process scan — **not** a guarantee.

```text
Candidate process names (configurable list):
  steam.exe, EpicGamesLauncher.exe, chrome.exe, msedge.exe, firefox.exe,
  vlc.exe, Spotify.exe, qbittorrent.exe, Transmission.exe, ...
```

Rules:

- If process exists **and** `Get-PowerRequestBlockers` shows EXECUTION/DISPLAY activity → count as one warning bucket ("Possible active media/download").
- If process exists but no power request → soft note only in detail, not in warning count.
- Label copy uses **"may"** — never "will fail".

---

## Fit with lobby-first model

| State | Sleep Clearance |
|-------|-----------------|
| **Lobby** | Visible, refreshed when action/duration/schedule changes |
| **Running** | Hidden (user already committed; use tray + warnings at 5 min / 30 s) |
| **Paused** | Optional one-line "Started with N blocker warnings" — v1.1 |
| **AutoStart on open** | Show Clearance snapshot before countdown starts (brief or until PLAY equivalent) |

Lobby-first is preserved: opening the app does **not** start a real countdown unless AutoStart or user presses PLAY. Clearance reinforces that pause — user sees the plan before commitment.

---

## Implementation sketch (when approved)

**Do not implement in the same PR as this doc unless the slice is tiny.**

Suggested touch points:

| Area | Change |
|------|--------|
| `SleepTimer-Tonight.ps1` | `Get-SleepClearanceReport` function; lobby panel controls |
| `modules/LightsOut.Steam.psm1` (if present) | Panel layout in Steam shell |
| Settings | Optional `ShowSleepClearance` default `$true` |
| Audit | `Write-AuditLog 'clearance_scan' ...` |

**PLAY click flow (v1):**

```text
User clicks PLAY
  → Invoke-StartTimer (unchanged safety)
  → existing Confirm-PowerBlockerWarning if blockers and WarnPowerBlockers on
  → session starts
```

Clearance is **before** click; blocker confirm at PLAY remains the last gate for users who ignored warnings.

---

## Tests needed

### Static / unit (no GUI launch)

| Test | Assert |
|------|--------|
| `Get-SleepClearanceReport` with mock settings | Correct action/mode/autostart labels |
| Blocker count matches `Get-PowerRequestBlockers` | Same count for same action |
| Lock action | No sleep blocker rows |
| Dry-run env | Report shows simulated power path |
| Heuristic | Known process name → warning bucket increments |

Add to `Test-SleepTimer-Logic.ps1` or new `Test-SleepClearance-Logic.ps1` — **no** `Start-Process SleepTimer.exe`.

### Agent safety

| Test | Assert |
|------|--------|
| `Test-AgentSafety.ps1` | Still passes — no unsafe launch docs added |
| `Test-SleepTimer.ps1` | Still passes |

### Manual (human only, `-DryRun`)

```powershell
Start-Process "C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-DryRun','-NoAutoStart'
```

Verify: lobby shows Clearance; PLAY starts dry-run session; panel hides when running.

---

## Related docs

| Doc | Relationship |
|-----|--------------|
| [`docs/agent-handbook/06-FEATURES-PLANNED.md`](../agent-handbook/06-FEATURES-PLANNED.md) | Roadmap parent |
| [`docs/agent-handbook/03-UI-AND-THEMES.md`](../agent-handbook/03-UI-AND-THEMES.md) | Lobby/session UI contract |
| [`docs/agent-handbook/01-PRODUCT-VISION.md`](../agent-handbook/01-PRODUCT-VISION.md) | Bedtime control positioning |
| [`docs/lights-out/NOVEL-FEATURES.md`](NOVEL-FEATURES.md) | Ledger / pact — future proof card |

---

## One-line summary

**Sleep Clearance = pre-PLAY trust panel: show tonight's plan, surface blockers early, say "Clear for Lights Out" or warn honestly — without requiring LuxGrid and without replacing final shutdown safety.**
