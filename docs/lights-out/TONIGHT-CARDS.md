# Tonight Cards™ — design

**Status:** v1 implemented (`LightsOut.TonightCards.psm1` + Steam LIB tiles)
**Product:** Lights Out PC (`SleepTimer-Tonight.ps1`)  
**Pairs with:** [`SLEEP-CLEARANCE.md`](SLEEP-CLEARANCE.md), [`MORNING-PROOF.md`](MORNING-PROOF.md), [`LAST-LIGHT-SEQUENCES.md`](LAST-LIGHT-SEQUENCES.md)

---

## Product purpose

Tonight Cards make the **LIB** page feel like a real **Night Lobby** — a game-library of selectable runs, not a settings panel.

The user should feel like they are **choosing tonight's mode**, not editing JSON.

| Generic timer | Lights Out with Tonight Cards |
|---------------|-------------------------------|
| Duration dropdown + Start | Pick a card → preview → PLAY |
| Presets buried in SET | Weeknight / Movie / Bedtime visible in LIB |
| No narrative | Each card has title, subtitle, and intent |

**Positioning:** Library tiles for **tonight's run**, not profile management (saved timers remain in SCH / profiles).

---

## Session loop

```text
LIB: pick Tonight Card
        ↓
Hero preview updates (Tonight's Run)
        ↓
Sleep Clearance reflects card settings
        ↓
PLAY (explicit — never auto-start from card select)
        ↓
Session → Last Light → Morning Proof
```

---

## V1 cards

| Card ID | Title | Default behavior |
|---------|-------|------------------|
| `weeknight` | Weeknight | 24 min → Shutdown |
| `movie` | Movie | 45 min → Sleep |
| `bedtime` | Bedtime | 11:30 PM clock → Shutdown |
| `hard_stop` | Hard Stop | Strict / limited snooze → Shutdown |
| `custom` | Custom | Current manual settings unchanged |

### Suggested copy

```text
WEEKNIGHT
24 min · Shutdown
Clean exit before the night drifts.

MOVIE
45 min · Sleep
Let the movie fade out.

BEDTIME
11:30 PM · Shutdown
Clock-based lights out.

HARD STOP
No drift · Shutdown
The algorithm loses tonight.

CUSTOM
Use current settings
Your manual setup.
```

---

## Card schema

Each card defines:

| Field | Type | Notes |
|-------|------|-------|
| `Id` | string | ASCII id, e.g. `weeknight` |
| `Title` | string | Tile headline |
| `Subtitle` | string | One-line intent |
| `DurationSeconds` | int? | For duration mode |
| `ClockTime` | string? | For clock mode, e.g. `23:30` |
| `TimerMode` | string | `duration` \| `clock` |
| `Action` | string | Shutdown, Sleep, etc. |
| `Strictness` | string | `normal` \| `hard` |
| `SnoozePolicy` | string | `default` \| `limited` \| `none` (v1: `limited` for Hard Stop only) |
| `DefaultLastLightSequence` | string | v1.1 mapping — see Last Light spec |
| `ClearanceSummary` | string | Optional override line for Clearance panel |

Store catalog in `modules/LightsOut.Profiles.psm1` or new `LightsOut.TonightCards.psm1` for unit tests.

### Proposed settings keys

| Key | Default | Meaning |
|-----|---------|---------|
| `TonightCardId` | `'custom'` | Last selected card in LIB |
| `TonightCardOverrides` | `@{}` | v1.1 — per-card user tweaks |

Card selection updates existing settings fields (`DefaultSeconds`, `Action`, `TimerMode`, `ClockTime`, pact/snooze flags as scoped) — no parallel timer state.

---

## UI placement (Steam / Night Lobby)

### LIB page

```text
+------+-----------------------------------+
| LIB  | TONIGHT'S RUN                     |
| SCH  |                                   |
| SET  | [Weeknight] [Movie] [Bedtime]     |
|      | [Hard Stop] [Custom]              |
|      |                                   |
|      | Hero: Weeknight · 24 min · Shut.. |
|      | Sleep Clearance panel             |
|      | Ring + PLAY                       |
+------+-----------------------------------+
```

**Rules:**

1. Cards are **tiles** in LIB content area (not SET).
2. Selected card gets visible highlight / border (Steam library selection).
3. Hero tagline shows **Tonight's Run** preview after selection.
4. Sleep Clearance re-reads when card changes.
5. **PLAY does not change** — same `Invoke-StartTimer` path and gates.

### Hero preview (after card select)

```text
TONIGHT'S RUN
Weeknight · 24 min · Shutdown
Clearance ready.
```

Clearance headline may append card-specific line when `ClearanceSummary` is set.

---

## Interaction behavior

Selecting a card:

- Updates current timer settings in memory (+ saves when user leaves LIB or on PLAY — match existing Save-Settings patterns).
- Updates hero preview and ring target.
- Updates Sleep Clearance summary.
- **Does not auto-start.**
- **Does not bypass** confirmation or power safety.
- **Custom** card: no overwrite — reflects whatever user set in SET/SCH.

Hard Stop card (v1 scope):

- Sets stricter snooze policy flags where they exist (Pact-adjacent or future anti-cancel).
- **Must not remove** emergency cancel (`Ctrl+Shift+S`).
- May default `LastLightSequence` to `AntiAlgorithm` when Last Light ships (v1.1).

---

## Last Light mapping (v1.1 — with Last Light v1)

| Card | Default Last Light sequence |
|------|----------------------------|
| Weeknight | `SignalSeverance` |
| Movie | `ClassicFade` (+ Cinema optional) |
| Bedtime | `ExitTheGrid` |
| Hard Stop | `AntiAlgorithm` |
| Custom | User-selected from SET |

Tonight Cards v1 can ship **without** Last Light overrides; mapping is a follow-up PR.

---

## Relationship to existing features

| Feature | Relationship |
|---------|----------------|
| Saved timer profiles (SCH) | Cards are curated presets; profiles remain for custom named timers |
| Rituals | Cards may set ritual id internally; v1 can ignore rituals |
| Sleep Clearance | Re-renders on card change |
| Morning Proof | Unchanged |
| AutoStart | Card selection does not trigger AutoStart |
| 60s minimum | Card durations must respect production minimum |

---

## Safety (non-negotiable)

1. Card select **never** calls `Do-PowerAction`.
2. Card select **never** starts timer without PLAY (or AutoStart setting on open — unchanged).
3. Hard Stop **never** removes emergency cancel.
4. Min timer **60 seconds** unchanged.
5. LuxGrid optional.
6. No network.
7. Agents: no `SleepTimer.exe` launch in tests except `-DryRun` manual checks.

---

## v1 scope vs later

### v1 (first implementation)

| Item | In |
|------|-----|
| Five cards in LIB | Yes |
| Tile selection + hero preview | Yes |
| Updates duration/action/mode | Yes |
| Hard Stop limited snooze (existing flags) | Yes, if flags exist |
| Last Light per-card defaults | No (v1.1) |
| Custom card editor | No |
| Card reorder / favorites | No |

### v1.1+

- Default Last Light sequence per card
- Per-card Clearance copy from scan
- "Same as last night" quick tile
- User-pinned favorite card

### Out of scope

- Cloud sync of cards
- Community/shared card packs
- Auto-start on card click
- Blocking PLAY on Clearance warn

---

## Proposed API

```powershell
function Get-TonightCardCatalog {
    # Returns ordered card definitions
}

function Get-TonightCardById {
    param([string]$Id)
}

function Apply-TonightCard {
    param(
        [string]$CardId,
        [hashtable]$Settings  # mutate in-place or return new settings
    )
    # No timer start; no power action
}

function Get-TonightCardHeroPreview {
    param([string]$CardId, [hashtable]$Settings)
    # Returns title/tagline lines for hero
}
```

---

## Tests needed

### Unit (no GUI, no exe)

| Test | Assert |
|------|--------|
| Catalog has 5 v1 ids | weeknight, movie, bedtime, hard_stop, custom |
| Apply weeknight | 24 min, Shutdown, duration mode |
| Apply bedtime | clock 23:30, Shutdown |
| Apply custom | settings unchanged |
| Hard stop | snooze policy stricter; emergency cancel path untouched |
| Min duration | no card below 60s production minimum |
| Hero preview | correct strings per card |

### Static

| Test | Assert |
|------|--------|
| `Test-SleepTimer.ps1` | Tonight Card symbols present after ship |
| `Test-AgentSafety.ps1` | Passes |

### Manual (`-DryRun` only)

1. LIB → Weeknight → hero shows 24 min → Clearance updates → PLAY starts session.  
2. LIB → Custom → prior manual settings preserved.  
3. Hard Stop → snooze limited per spec; Ctrl+Shift+S still works.

---

## Implementation sketch (when approved)

| Step | File | Change |
|------|------|--------|
| 1 | `modules/LightsOut.TonightCards.psm1` (new) | Catalog + Apply |
| 2 | `LightsOut.SteamTheme.psm1` | LIB tile UI |
| 3 | `SleepTimer-Tonight.ps1` | Selection wiring, `TonightCardId` setting |
| 4 | `Test-SleepTimer-Logic.ps1` | Apply + preview tests |
| 5 | `04-SETTINGS-AND-DATA.md` | Schema row |

---

## Definition of done (v1)

- [ ] Five cards visible in LIB with selection state.
- [ ] Hero preview updates on select.
- [ ] Clearance updates on select.
- [ ] PLAY path unchanged; no auto-start on select.
- [ ] Custom preserves manual settings.
- [ ] Emergency cancel and 60s minimum intact.
- [ ] All validation scripts pass.

---

## Related docs

| Doc | Use |
|-----|-----|
| [`AGENT-IDEA-BRIEF.md`](AGENT-IDEA-BRIEF.md) | Master handoff + build order |
| [`LAST-LIGHT-SEQUENCES.md`](LAST-LIGHT-SEQUENCES.md) | Per-card finale defaults (v1.1) |
| [`../agent-handbook/03-UI-AND-THEMES.md`](../agent-handbook/03-UI-AND-THEMES.md) | LIB / lobby contract |

---

## One-line summary

**Tonight Cards = LIB library tiles that apply preset run settings and hero preview without auto-start — Night Lobby chooses the run, PLAY still starts it.**
