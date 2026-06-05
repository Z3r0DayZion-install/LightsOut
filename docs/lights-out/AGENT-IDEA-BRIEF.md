# Lights Out PC — Agent Idea Brief

**Purpose:** One clean handoff for coding agents working on **Lights Out PC** product/UI ideas — without confusing shipped features, planned specs, experiments, or unsafe paths.

**Working product name:** **Lights Out PC**  
**Subtitle:** **Bedtime Mode for Windows**  
**Tagline:** **Choose tonight's run. Your PC powers down when it should.**

**Core positioning:** Lights Out PC is not a generic shutdown timer. It is a local-first Windows bedtime control app with a session loop:

```text
Night Lobby -> Sleep Clearance -> PLAY -> Session -> Last Light -> Power gates -> Morning Proof
```

**Feature specs in this repo:**

| Spec | Path | Status |
|------|------|--------|
| Sleep Clearance | [`SLEEP-CLEARANCE.md`](SLEEP-CLEARANCE.md) | Shipped v1 |
| Morning Proof | [`MORNING-PROOF.md`](MORNING-PROOF.md) | Shipped v1 |
| Last Light Sequences | [`LAST-LIGHT-SEQUENCES.md`](LAST-LIGHT-SEQUENCES.md) | Planned |
| Tonight Cards | [`TONIGHT-CARDS.md`](TONIGHT-CARDS.md) | Spec only |
| Bedside Remote | [`BEDSIDE-REMOTE.md`](BEDSIDE-REMOTE.md) | Spec only |

---

## 0. Non-negotiable agent rules

Before touching code, read:

1. [`../agent-handbook/AGENT-QUICKSTART.md`](../agent-handbook/AGENT-QUICKSTART.md)
2. [`../agent-handbook/00-README.md`](../agent-handbook/00-README.md)
3. [`../agent-handbook/03-UI-AND-THEMES.md`](../agent-handbook/03-UI-AND-THEMES.md)
4. [`../agent-handbook/07-SAFETY-AND-TESTING.md`](../agent-handbook/07-SAFETY-AND-TESTING.md)
5. The feature spec listed for the assigned task

Canonical app only:

```text
SleepTimer-Tonight.ps1
modules/LightsOut.*.psm1
Desktop\Lights Out\SleepTimer.exe
```

Do **not** treat these as canonical unless explicitly instructed:

```text
CoolTimer.ps1
SleepTimer-Electron/
nightfall/src/
legacy SleepTimer-*.ps1
repos/sleeptimer-*
```

Safety rules:

- Never launch `SleepTimer.exe` without `-DryRun` during agent/testing work.
- Do not lower the production 60-second minimum.
- Do not bypass `Test-NoPowerAction`.
- Do not call `Do-PowerAction` directly from new UI, remote APIs, or animation code.
- Do not remove emergency cancel.
- Do not make LuxGrid required.
- Do not add cloud dependency for the core timer.
- Do not create public internet exposure for any remote feature by default.

Required validation after code changes:

```powershell
.\scripts\Test-AgentSafety.ps1
.\scripts\Test-SleepTimer.ps1
.\scripts\CI-Local.ps1
```

---

## 1. Current shipped trust loop

These features are already implemented — do not reimplement from scratch.

### Sleep Clearance v1

**Purpose:** "Is the PC safe/ready to start tonight's run?"

- Lobby-only panel; read-only before PLAY.
- Does not block PLAY by itself.
- Existing PLAY warning/confirm gates remain in charge.
- LuxGrid optional.

### Morning Proof v1

**Purpose:** "Did Lights Out actually work last time?"

- Parses `actions.log` newest-first; `MorningProofLastSeen` show-once.
- Steam hero takeover in lobby only.
- States: completed, dry-run, cancelled, unknown.
- Buttons: PLAY TONIGHT AGAIN, VIEW LEDGER, DISMISS.
- Does not change `Do-PowerAction`, `Test-NoPowerAction`, or PLAY gating.

### Existing UI foundation

- Game-library style shell (Night Lobby).
- LIB / SCH / SET navigation; hero panel; countdown ring.
- Lobby-first behavior; Cinema Mode; punch at zero; dim phase.
- Optional LuxGrid bridge; Sleep Ledger / streak stats.

---

## 2. Brand and naming direction

| Layer | Name |
|---|---|
| Main product | **Lights Out PC** |
| Subtitle | **Bedtime Mode for Windows** |
| UI experience | **Night Lobby** |
| Before-start trust | **Sleep Clearance** |
| After-run proof | **Morning Proof** |
| Preset tiles | **Tonight Cards** |
| Finale animations | **Last Light Sequences** |
| Cyber finale pack | **Unplug Sequence** |
| Fullscreen | **Cinema Mode** |
| Strict preset | **Hard Stop** |
| Stats/history | **Sleep Ledger** |
| Phone control | **Bedside Remote** |

Public copy: use **game-library style**, **Night Lobby**, **Cinema Mode** — not "Steam UI" or "Steam clone."

Avoid user-facing IP-adjacent copy: Matrix Mode, Red Pill, etc.

Safe cyber copy:

```text
Unplug from the feed. End the session. Save the night.
Exit the Grid.
Signal severed. Night secured.
The algorithm lost tonight.
```

---

## 3. Recommended build order

| Phase | Feature | Action |
|------:|---------|--------|
| A | Last Light v1 | **Implement** — see [`LAST-LIGHT-SEQUENCES.md`](LAST-LIGHT-SEQUENCES.md) |
| B | Tonight Cards v1 | **Implement** after Last Light — see [`TONIGHT-CARDS.md`](TONIGHT-CARDS.md) |
| C | Bedside Remote | **Spec first, implement later** — see [`BEDSIDE-REMOTE.md`](BEDSIDE-REMOTE.md) |
| D | LuxGrid Pulse Pack | Optional polish after Last Light v1 stable |

---

## 4. Combined roadmap

| Priority | Feature | Type | Risk | Why |
|---:|---|---|---|---|
| 1 | Last Light v1 | implementation | low/medium | Existing zero hook + high polish |
| 2 | Tonight Cards spec | design | low | Locks LIB direction |
| 3 | Tonight Cards v1 | implementation | medium | Night Lobby feels real |
| 4 | Bedside Remote spec | design | medium/high | Security clarity first |
| 5 | Bedside Remote v1 | implementation | high | Local server + token surface |
| 6 | LuxGrid Pulse Pack | implementation | medium | Optional hardware polish |
| 7 | Product copy update | docs | low | Public story after ship |

---

## 5. Acceptance standard for future UI features

**Good if it:**

- Makes the nightly path faster, clearer, or more trustworthy.
- Reinforces the Night Lobby session loop.
- Keeps PLAY explicit unless existing settings say otherwise.
- Keeps emergency cancel available.
- Leaves `Do-PowerAction` and `Test-NoPowerAction` intact.
- Uses local data only unless user explicitly opts in elsewhere.
- Does not require LuxGrid.

**Bad if it:**

- Feels like generic timer bloat.
- Adds cloud dependency for core behavior.
- Bypasses final confirm.
- Makes shutdown feel unsafe.
- Requires app launch in tests.
- Pretends to measure sleep quality or health outcomes.

---

## 6. One-shot agent prompts

### Last Light v1 (next code pass)

```text
Work only on Lights Out.

Start with:
docs/agent-handbook/AGENT-QUICKSTART.md
docs/agent-handbook/03-UI-AND-THEMES.md
docs/agent-handbook/07-SAFETY-AND-TESTING.md
docs/lights-out/LAST-LIGHT-SEQUENCES.md
docs/lights-out/AGENT-IDEA-BRIEF.md

Task: Implement Last Light v1.

Scope:
- Add LastLightEnabled, LastLightSequence, LastLightUseCinema, LastLightLuxPulse settings.
- Add Start-LastLightSequence visual function.
- Sequences: Classic Fade, Exit the Grid, Anti-Algorithm Protocol, Signal Severance.
- Wire at timer zero: punch -> Last Light -> dim -> final confirm.
- SET dropdown/options; keep lobby unbloated.
- Keep final confirm, emergency cancel, Do-PowerAction, Test-NoPowerAction, 60s minimum unchanged.
- Keep LuxGrid optional. Add tests.

Validation:
.\scripts\Test-AgentSafety.ps1
.\scripts\Test-SleepTimer.ps1
.\scripts\CI-Local.ps1

Do not launch SleepTimer.exe except with -DryRun.
```

### Tonight Cards (spec — done in repo)

See [`TONIGHT-CARDS.md`](TONIGHT-CARDS.md). Implement only when user asks.

### Bedside Remote (spec — done in repo)

See [`BEDSIDE-REMOTE.md`](BEDSIDE-REMOTE.md). Implement only when user asks.

---

## 7. Product-facing copy (after Last Light / Tonight Cards ship)

```text
Lights Out PC
Bedtime Mode for Windows

Choose tonight's run.
Check Sleep Clearance.
Hit PLAY.
Watch Last Light.
Wake up to Morning Proof.
```

Use: **PC bedtime control**, **Night Lobby**, **local-only**, **no account**, **no telemetry**.

Avoid: just a shutdown timer, Steam clone, Matrix mode, AI sleep-health score, cloud sleep tracker.

---

*Filed from user brief · aligns with handbook [`06-FEATURES-PLANNED.md`](../agent-handbook/06-FEATURES-PLANNED.md)*
