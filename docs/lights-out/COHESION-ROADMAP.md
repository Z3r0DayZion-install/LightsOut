# Cohesion roadmap — one bedtime session system

**Status:** Living doc (post trust-loop ship)  
**Product:** Lights Out PC

The core loop is strong:

```text
Night Lobby → Sleep Clearance → PLAY → Session → Last Light → Power gates → Morning Proof
```

Cohesion work makes that feel like **one premium experience**, not separate modules.

**Public line:**

> Choose tonight's run. Clear the PC. Start the session. Watch Last Light. Wake to proof.

---

## Product rule

**Simple Timer first. Night Lobby second.**

| Mode | Launcher | Purpose |
|------|----------|---------|
| **Simple Timer** | `-ClassicUi -NoAutoStart` | Default desktop — real nightly use |
| **Night Lobby** | `-SteamUi -NoAutoStart` | Premium cards, clearance, proof |
| **Demo** | `-Demo -NoAutoStart` | Screenshots only (implies DryRun) |

See [`SIMPLE-TIMER.md`](SIMPLE-TIMER.md).

---

## Shipped (trust loop)

| Piece | Status |
|-------|--------|
| Sleep Clearance v1 | Shipped |
| Morning Proof v1 | Shipped |
| Last Light v1 | Shipped |
| Tonight Cards v1 | Shipped |
| Agent safety + DryRun CI | Shipped |

---

## Priority ranking (cohesion phase)

| Priority | Upgrade | Status | Notes |
|--------:|---------|--------|-------|
| 1 | Tonight Cards as main LIB interface | **Shipped v1** | Tiles + select-without-start |
| 2 | **Tonight Preview hero** | **Shipped v1.1** | Whole-run summary before PLAY |
| 3 | **Calmer defaults, optional cyber** | **Shipped v1.1** | Weeknight → Classic Fade; cyber on explicit cards |
| 4 | **Trust badges** | **Shipped v1.1** | LOCAL ONLY · DRY-RUN · CONFIRM · CANCEL · NO CLOUD |
| 5 | **Last Light Sound setting** | **Shipped v1.1 stub** | Off default; Soft tick optional |
| 6 | Cleaner SET sections | Planned | Power · Last Light · Remote · Safety · Advanced |
| 7 | Demo Mode (`-Demo -DryRun`) | **Shipped v1** | Screenshots / README / video |
| 8 | Bedside Remote v1 | Spec ready | After cohesion stabilizes |
| 9 | Morning Proof v2 | Planned | “Usual drift” from local history |
| 10 | LuxGrid Pulse Pack | Planned | Atmosphere, not core |

---

## 1. Tonight Cards = main interface

**Goal:** LIB feels like choosing tonight's mode, not editing presets.

**Shipped:** Five tiles, hero updates, clearance integration, no auto-start.

**Next polish:** Larger tile copy, “Choose tonight's mode” framing, SCH for fine-tuning only.

---

## 2. Calmer default, optional cyber

**Rule:** First impression = professional and trustworthy.

| Context | Last Light default |
|---------|-------------------|
| Weeknight (default card) | Classic Fade |
| Movie | Classic Fade |
| Bedtime | Exit the Grid (explicit cyber — user chose Bedtime) |
| Hard Stop | Anti-Algorithm (explicit strict mode) |
| SET dropdown default | Classic Fade |

Cyber sequences remain selectable in SET: Exit the Grid, Anti-Algorithm, Signal Severance.

---

## 3. Tonight Preview (hero)

Before PLAY, hero summarizes the **whole run**:

```text
TONIGHT'S RUN
Weeknight · 24 min · Shutdown
Clearance: Clear · Ending: Classic Fade · Proof: Tomorrow morning
```

Replaces competing clearance + hero copy in lobby. Clearance panel hides when preview is active.

---

## 4. Last Light Sound

Setting (SET → Last Light):

```text
Last Light Sound: Off | Soft | Cyber | Silent
```

v1.1 ships **Off** (default) and **Soft** (single tick at sequence end). Cyber/Silent reserved.

No loud gimmicks. Default **Off**.

---

## 5. Morning Proof v2 (later)

Add local history comparison — not sleep science:

```text
You ended 47 minutes earlier than your usual drift.
```

Requires drift baseline from `actions.log` — defer until v2.

---

## 6. Trust badges

Lobby strip (read-only):

```text
LOCAL ONLY · FINAL CONFIRM ON · EMERGENCY CANCEL · NO CLOUD
```

When `-DryRun`: show **DRY-RUN SAFE**.

Surfaces existing safety gates (`Test-NoPowerAction`, confirm, Ctrl+Shift+S) without new settings.

---

## 7. SET page sections (later)

Target structure:

```text
SET
  Power Action
  Last Light
  Remote
  Safety
  Advanced
```

Not 20 toggles on one screen.

---

## 8. Bedside Remote

Spec: [`BEDSIDE-REMOTE.md`](BEDSIDE-REMOTE.md)

Higher utility than LuxGrid polish. Higher risk (local HTTP + token). Build after cohesion v1.1 stable.

---

## 9. Demo Mode

**Status:** Shipped v1 — see [`DEMO-MODE.md`](DEMO-MODE.md).

Safe marketing / screenshots:

```powershell
SleepTimer.exe -Demo -NoAutoStart
SleepTimer.exe -Demo -Seconds 90 -Start
SleepTimer.exe -Demo -LastLightSequence ExitTheGrid
```

Demo implies DryRun, skips settings/log writes, shows sample Morning Proof and trust badges.

---

## 10. Public naming

Use in product copy:

```text
Lights Out PC · Night Lobby · Sleep Clearance · Morning Proof
Tonight Cards · Last Light · Bedside Remote
```

Use ™ sparingly in marketing docs, not every UI label.

Avoid: Matrix, Red Pill, “Steam clone” in user-facing strings.

---

## Definition of done (cohesion v1.1)

- [x] Hero shows Tonight Preview with clearance / ending / proof lines
- [x] Weeknight default uses Classic Fade
- [x] Trust badges visible in Steam lobby
- [x] LastLightSound in settings (Off + Soft)
- [x] Clearance panel defers to hero preview in lobby
- [x] Tests pass; no unsafe launches

---

## Related docs

| Doc | Use |
|-----|-----|
| [`AGENT-IDEA-BRIEF.md`](AGENT-IDEA-BRIEF.md) | Agent handoff + build order |
| [`TONIGHT-CARDS.md`](TONIGHT-CARDS.md) | Cards spec |
| [`LAST-LIGHT-SEQUENCES.md`](LAST-LIGHT-SEQUENCES.md) | Finale spec |
| [`MORNING-PROOF.md`](MORNING-PROOF.md) | Proof spec |
| [`BEDSIDE-REMOTE.md`](BEDSIDE-REMOTE.md) | Remote spec |
