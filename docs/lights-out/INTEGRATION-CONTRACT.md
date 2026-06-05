# Lights Out integration contract

**Canonical app:** `SleepTimer-Tonight.ps1` + `modules\LightsOut.*.psm1` → `Desktop\Lights Out\SleepTimer.exe`

## Principle

```text
Standalone first.
Modular always.
Hard dependency never.
```

Lights Out is a **standalone Windows bedtime timer first**, but it must stay buildable so it can connect cleanly with the broader Neural ecosystem later:

- NeuralOS
- LuxGrid
- NeuralShell
- Snoozurp
- NeuralTube
- future dashboard / launcher / automation apps

Do **not** turn Lights Out into a closed one-off app.

## Architecture

```text
Lights Out Core
  -> local timer
  -> safe power action (Do-PowerAction + Test-NoPowerAction only)
  -> final confirm
  -> audit log (%LOCALAPPDATA%\CoolTimer\actions.log)

Optional bridges (off by default)
  -> LuxGrid JSON events
  -> NeuralOS dashboard
  -> Snoozurp sleep layer
  -> NeuralShell automation
  -> future launcher / control panels
```

Core timer must work **fully offline and standalone**. Ecosystem connections are **optional** and must never be required for launch, countdown, confirm, or shutdown.

## Modular rule (agents)

1. Keep the canonical app as `SleepTimer-Tonight.ps1` → `SleepTimer.exe`.
2. Do not create a new UI stack unless explicitly asked.
3. Do not make other apps required for Lights Out to work.
4. Add integration through **optional modules, adapters, events, or JSON files**.
5. Core timer must work fully offline and standalone.
6. Ecosystem connections must be **optional / off by default**.
7. No hard dependency on LuxGrid, NeuralOS, cloud, or any future app.
8. Expose clean integration points instead of direct coupling.

## Preferred integration pattern

| Pattern | Use |
|---|---|
| Local event output | Drop JSON files to a local inbox (LuxGrid today) |
| JSON manifest | Pack definitions (`packaging/luxgrid/Sleep-Ritual-Pack.json`) |
| Optional module | `modules\LightsOut.*.psm1` — feature slices, not core coupling |
| CLI flags | `-DryRun`, `-SteamUi`, `-Demo`, schedule/action overrides |
| Local file bridge | Settings JSON, audit log, household export |
| Localhost API | **Only if explicitly planned** — never required for core |

## Standalone mode (default)

| Item | Detail |
|---|---|
| Launch | `Lights Out.bat` or `SleepTimer.exe -ClassicUi -NoAutoStart` |
| Settings | `%LOCALAPPDATA%\CoolTimer\settings.json` |
| Audit log | `%LOCALAPPDATA%\CoolTimer\actions.log` |
| LuxGrid | **Off** (`EmitLuxGridEvents: false`) |
| Network | None required |
| Other apps | None required |

Lights Out must shut down / sleep / restart the PC safely with zero ecosystem apps installed.

## Optional ecosystem mode

Enable bridges only when the user opts in:

| Bridge | Enable | Listener |
|---|---|---|
| **LuxGrid RGB** | Settings checkbox `LuxGrid RGB` / `EmitLuxGridEvents` | LuxGrid Studio EventBridge |
| **Future NeuralOS** | TBD — local events or manifest | Dashboard / launcher |
| **Future NeuralShell** | TBD — CLI or file watch | Automation scripts |
| **Future Snoozurp** | TBD — sleep-layer adapter | Sleep ritual overlay |
| **Future NeuralTube** | TBD — session-end hook | Media wind-down |

Listeners may **react** to events. They must **never** bypass `Test-NoPowerAction` or call shutdown directly.

## Event contract

### Envelope (all ecosystem events)

Written to `%LOCALAPPDATA%\LuxGrid\events\inbox\lightsout_{guid}.json` when LuxGrid bridge is enabled:

```json
{
  "id": "uuid",
  "timestamp": "2026-06-04T23:30:00.0000000Z",
  "sourceApp": "LightsOut",
  "eventName": "timer.warning",
  "channel": "sleep",
  "payload": { },
  "processed": false
}
```

### Required future-friendly event names

| Event | Status | When |
|---|---|---|
| `timer.started` | **Shipped as** `timer.start` | Countdown begins or resumes |
| `timer.paused` | Planned | User pauses session |
| `timer.resumed` | Planned | User resumes from pause |
| `timer.snoozed` | Planned | Snooze extends remaining time |
| `timer.cancelled` | **Shipped** | Pause stop, emergency cancel (`Ctrl+Shift+S`) |
| `timer.warning` | **Shipped** | 5m / 60s / 30s warnings |
| `timer.lastLight.started` | Planned | Last Light sequence begins |
| `timer.finalConfirm.shown` | Planned | 5s final confirm dialog shown |
| `timer.completed` | **Shipped** | Countdown finished, pre/post power path |
| `powerAction.blocked` | Planned (audit: `power_blocked`) | `Test-NoPowerAction` blocked execution |
| `powerAction.executed` | Planned (audit: `power_action`) | Real power command issued |
| `morningProof.available` | Planned | Morning Proof report ready on next launch |

### Also shipped today (LuxGrid channel)

| Event | When |
|---|---|
| `timer.tick` | Every 30s while running |
| `lights.dim` | Dim phase wind-down starts |
| `lights.out` | Punch at timer zero |

New integrations should converge on the **future-friendly names** above. Existing `timer.start` remains valid; alias to `timer.started` when adding new emitters.

### Typical payload fields

```json
{
  "timerName": "Sleep Ritual",
  "action": "Shutdown",
  "totalSeconds": 1380,
  "remainingSeconds": 300,
  "percentRemaining": 21.7,
  "phase": "countdown",
  "severity": "warning",
  "reason": "emergency",
  "result": "completed",
  "dryRun": false
}
```

Payload shape may grow per event. Listeners must ignore unknown fields.

## CLI hooks

| Flag | Integration use |
|---|---|
| `-DryRun` | Safe preview — no power action; events should include `dryRun: true` when emitted |
| `-Demo` | Marketing loop — implies DryRun; skips settings/log writes |
| `-SteamUi` / `-ClassicUi` | UI mode only — not an ecosystem switch |
| `-Minutes` / `-Action` / `-Start` | Automation without UI |
| `-LastLightSequence` | Preview finale sequences in Demo/DryRun |

Environment: `SLEEPTIMER_DRY_RUN`, `SLEEPTIMER_DEMO`, `SLEEPTIMER_CI` — all block real power via `Test-NoPowerAction`.

## Safe DryRun behavior

When `Test-NoPowerAction` is true (DryRun, Demo, CI):

- `Do-PowerAction` **does not** run shutdown/sleep/restart/hibernate/lock.
- Audit logs `power_blocked` instead of `power_action`.
- UI may show full countdown, Last Light, final confirm, and Morning Proof.
- Ecosystem listeners may still receive events — payloads should set `dryRun: true`.
- External apps must treat DryRun events as **non-authoritative** for power.

## How listeners integrate (without controlling shutdown)

```text
Lights Out                    Ecosystem app
    |                              |
    |-- JSON event file ----------> | watch inbox / audit log
    |                              | react (RGB, dashboard, toast)
    |                              |
    X<----- NEVER call shutdown --- X
```

Rules for listeners:

1. **Read-only** — consume events, settings, or audit log; do not inject power commands.
2. **Optional** — absence of a listener must not change timer behavior.
3. **Local only** — no cloud dependency in core path.
4. **Fail silent** — `Publish-LuxGridEvent` catches write errors; core timer continues.

## Power gate (non-negotiable)

**Only** these functions may gate or execute power:

| Function | Role |
|---|---|
| `Test-NoPowerAction` | Blocks all real power in DryRun, Demo, CI |
| `Do-PowerAction` | Sole execution path for Shutdown/Sleep/Restart/Hibernate/Lock |

Do **not**:

- Add alternate shutdown paths for ecosystem apps.
- Let LuxGrid, NeuralOS, or external scripts call `shutdown.exe` on Lights Out's behalf.
- Weaken `Test-NoPowerAction` for integration convenience.

Ecosystem integrations emit **signals**. Lights Out retains **authority** over power.

## Module ownership

| Layer | Owner |
|---|---|
| Timer, power, UI shell, settings, audit | `SleepTimer-Tonight.ps1` |
| Calendar, novel features, Steam theme, Last Light, Tonight Cards, Demo | `modules\LightsOut.*.psm1` |
| LuxGrid inbox setup | `scripts\Install-LuxGrid-LightsOut.ps1` |
| LuxGrid internals | `luxgrid/` (separate product — do not require for Lights Out) |

Add new ecosystem features as **optional modules or event emitters** — not as replacements for core.

## Related docs

- [`../agent-handbook/11-LUXGRID-INTEGRATION.md`](../agent-handbook/11-LUXGRID-INTEGRATION.md) — LuxGrid bridge today
- [`../../LUXGRID-LIGHTSOUT.md`](../../LUXGRID-LIGHTSOUT.md) — user setup guide
- [`UI-REFERENCE.md`](UI-REFERENCE.md) — UI polish (separate from integration)
- [`../agent-handbook/02-ARCHITECTURE.md`](../agent-handbook/02-ARCHITECTURE.md) — file layout
