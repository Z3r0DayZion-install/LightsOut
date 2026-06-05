# Lights Out - Agent Handbook

This handbook is the operating manual for code agents working on **Lights Out only**.

Lights Out is the Windows bedtime shutdown timer. The canonical product is a PowerShell WinForms app, built to `SleepTimer.exe`, and deployed to the user's Desktop. Do not treat old sleep timer files, CoolTimer experiments, Electron experiments, or LuxGrid internals as the product.

## Non-negotiable agent rules

1. **Canonical source:** `SleepTimer-Tonight.ps1`.
2. **Runtime modules:** `modules\LightsOut.*.psm1`.
3. **Canonical deploy:** `Desktop\Lights Out\SleepTimer.exe` via `scripts\Deploy-SleepTimer-Desktop.ps1`.
4. **Never launch `SleepTimer.exe` without `-DryRun` during agent testing.**
5. **Do not use `-Launch` on deploy unless the user explicitly asks.**
6. **Do not migrate to Electron, WPF, WinUI, or a separate .NET project unless the user explicitly asks.**
7. **Keep LuxGrid optional.** Lights Out must work without RGB.
8. **Preserve lobby-first behavior.** Opening the app should not start a real countdown unless the user or setting explicitly requests it.
9. **Production minimum timer stays 60 seconds.** Do not lower it for convenience.
10. **Run safe tests before claiming a task is done.**

## Start here

For any task, read these first:

1. `00-README.md` - this file, agent rules and routing.
2. `01-PRODUCT-VISION.md` - product identity and what makes the app worth building.
3. `02-ARCHITECTURE.md` - canonical files, modules, runtime model.
4. `07-SAFETY-AND-TESTING.md` - shutdown safety rules.

Then read the section that matches the task.

## Task routing

| If the task is about... | Read |
|---|---|
| Product idea, positioning, features, scope | `01-PRODUCT-VISION.md`, `05-FEATURES-SHIPPED.md`, `06-FEATURES-PLANNED.md` |
| File layout, where to edit, modules, state | `02-ARCHITECTURE.md`, `09-MODULES-REFERENCE.md` |
| Steam UI, lobby, ring, buttons, colors, Cinema | `03-UI-AND-THEMES.md`, `docs/lights-out/UI-REFERENCE.md` |
| Settings JSON, audit log, saved timers, data persistence | `04-SETTINGS-AND-DATA.md` |
| Existing capabilities | `05-FEATURES-SHIPPED.md` |
| Roadmap or feature gaps | `06-FEATURES-PLANNED.md` |
| Tests, CI, deploy safety, no accidental shutdown | `07-SAFETY-AND-TESTING.md` |
| Desktop packaging, ps2exe, release steps | `08-DEPLOY-AND-BUILD.md` |
| CLI switches, env vars, scheduler usage | `10-CLI-AND-AUTOMATION.md` |
| RGB bridge | `11-LUXGRID-INTEGRATION.md` |
| Ecosystem integration, event contract, Neural app bridges | `docs/lights-out/INTEGRATION-CONTRACT.md` |
| Public README, user docs, doc lint | `README.md`, `docs/lights-out/GETTING-STARTED.md`, `scripts/Test-Docs.ps1` |
| CI workflows, release checklist | `docs/lights-out/CI.md`, `docs/lights-out/RELEASE-CHECKLIST.md`, `.github/workflows/lights-out-ci.yml` |
| Crash, weird UI, settings bugs, module loading | `12-TROUBLESHOOTING.md` |
| Terms and naming | `13-GLOSSARY.md` |

## Fastest handoff

For short agent handoffs, use `AGENT-QUICKSTART.md`. It is intentionally blunt and safe.

## Section index

| File | Purpose |
|---|---|
| `01-PRODUCT-VISION.md` | Defines the app as a bedtime control ritual, not a generic timer. |
| `02-ARCHITECTURE.md` | Canonical implementation, deploy shape, edit map, forbidden stacks. |
| `03-UI-AND-THEMES.md` | Steam UI contract, lobby/session states, color safety, Cinema mode. |
| `04-SETTINGS-AND-DATA.md` | Settings schema, storage paths, audit log, persistence rules. |
| `05-FEATURES-SHIPPED.md` | What is already done and should not be rebuilt blindly. |
| `06-FEATURES-PLANNED.md` | Next product and distribution priorities. |
| `07-SAFETY-AND-TESTING.md` | Safe commands, forbidden commands, shutdown guardrails. |
| `08-DEPLOY-AND-BUILD.md` | Desktop deploy, ps2exe build, release checklist. |
| `09-MODULES-REFERENCE.md` | Module responsibilities and when to edit modules vs monolith. |
| `10-CLI-AND-AUTOMATION.md` | CLI, env vars, auto-start precedence, scheduler patterns. |
| `11-LUXGRID-INTEGRATION.md` | Optional RGB event bridge only. |
| `12-TROUBLESHOOTING.md` | Fast failure diagnosis and safe debug commands. |
| `13-GLOSSARY.md` | Shared vocabulary and file nicknames. |

## Related docs outside this folder

| Path | Use when |
|---|---|
| `AGENTS.md` | Repo-level agent entry point. Should link here. |
| `docs/lights-out/RITUALS.md` | User-facing ritual details. |
| `docs/lights-out/CALENDAR.md` | ICS and calendar mode details. |
| `docs/lights-out/MY-TIMERS.md` | Saved profile UX. |
| `docs/lights-out/NOVEL-FEATURES.md` | Ledger, pact, household features. |
| `docs/lights-out/AGENT-IDEA-BRIEF.md` | Master product handoff for agents (build order, prompts). |
| `docs/lights-out/LAST-LIGHT-SEQUENCES.md` | Timer-zero finale spec (planned). |
| `docs/lights-out/TONIGHT-CARDS.md` | LIB preset tiles spec (planned). |
| `docs/lights-out/BEDSIDE-REMOTE.md` | Local phone remote spec (planned). |
| `PRODUCT.md` | Public product summary. Keep version in sync when editing public docs. |
| `PRODUCT_ROADMAP.md` | Phase history and distribution narrative. |
| `CHANGELOG.md` | Version history. |
| `LUXGRID-LIGHTSOUT.md` | Deep dive for the optional LuxGrid bridge. |
| `COOLTIMER.md` / `CANONICAL-APPS.md` | History and canonical-vs-experiment notes. |

## Canonical one-liner

**Lights Out = `SleepTimer-Tonight.ps1` + `modules\LightsOut.*.psm1` -> `Desktop\Lights Out\SleepTimer.exe`. Everything else is historical, optional, or experimental unless the user says otherwise.**

## Copy-paste prompt for a code agent

```text
Work only on Lights Out.

Read docs/agent-handbook/00-README.md first, then read the sections relevant to the task. The canonical app is SleepTimer-Tonight.ps1 with modules/LightsOut.*.psm1, deployed as Desktop/Lights Out/SleepTimer.exe.

Rules:
- Do not touch CoolTimer.ps1, SleepTimer-Electron, nightfall/src, or legacy SleepTimer-* files unless explicitly asked.
- Never launch SleepTimer.exe without -DryRun.
- Do not deploy with -Launch unless explicitly asked.
- Keep LuxGrid optional.
- Preserve lobby-first behavior and all shutdown safety gates.
- Run scripts/Test-SleepTimer.ps1 before claiming completion.
```
