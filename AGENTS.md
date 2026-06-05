# Agent instructions (windsurf-project)

**Start here:** [`docs/agent-handbook/AGENT-QUICKSTART.md`](docs/agent-handbook/AGENT-QUICKSTART.md) — danger rules, canonical files, safe commands, what not to touch.

**Product roadmap handoff:** [`docs/lights-out/AGENT-IDEA-BRIEF.md`](docs/lights-out/AGENT-IDEA-BRIEF.md) — Last Light, Tonight Cards, Bedside Remote specs and build order.

**Full handbook:** [`docs/agent-handbook/00-README.md`](docs/agent-handbook/00-README.md)

**UI mockup north stars:** [`docs/lights-out/UI-REFERENCE.md`](docs/lights-out/UI-REFERENCE.md) — use `docs/assets/lights-out/*.png` when polishing ring, Classic, Night Lobby, Morning Proof, or Last Light (polish only; canonical `SleepTimer-Tonight.ps1`).

**Ecosystem contract:** [`docs/lights-out/INTEGRATION-CONTRACT.md`](docs/lights-out/INTEGRATION-CONTRACT.md) — standalone first, modular always, hard dependency never.

**Public docs & CI:** [`README.md`](README.md) · [`docs/lights-out/GETTING-STARTED.md`](docs/lights-out/GETTING-STARTED.md) · [`docs/lights-out/SAFETY-MODEL.md`](docs/lights-out/SAFETY-MODEL.md) · [`docs/lights-out/CI.md`](docs/lights-out/CI.md) · workflow [`.github/workflows/lights-out-ci.yml`](.github/workflows/lights-out-ci.yml)

---

## Canonical nightly sleep timer

**Do not replace or “upgrade” the user’s nightly app without explicit request.**

| Item | Path |
|------|------|
| Desktop app | `C:\Users\KickA\Desktop\Lights Out\SleepTimer.exe` |
| **Source** | `SleepTimer-Tonight.ps1` |
| Docs | `COOLTIMER.md`, `CANONICAL-APPS.md` |
| Quick deploy | `scripts\Deploy-SleepTimer-Desktop.ps1` (no `-Launch` by default) |
| Release build | `scripts\Build-Release.ps1` |
| Product docs | `PRODUCT.md`, `PRODUCT_ROADMAP.md`, `CHANGELOG.md` |

Behavior: Classic duration timer first (Night Lobby optional via `-SteamUi`), shutdown/sleep/restart, snooze, 5s confirm, always-on-top, tray, `Ctrl+Shift+S` emergency cancel. See [`docs/lights-out/SIMPLE-TIMER.md`](docs/lights-out/SIMPLE-TIMER.md).

## Safety — CRITICAL

**Never run tests that launch Sleep Timer or could shut down the user's PC.**

- Do **not** run GUI smoke tests or start `SleepTimer.exe` in automated/CI context unless user explicitly asks.
- If you must launch the exe, use **`-DryRun`** (see quickstart).
- Safe validation only: `.\scripts\Test-SleepTimer.ps1` (parse + static guards, no app launch).
- Safe full CI: `.\scripts\CI-Local.ps1` (validate + build; never launches timer).
- Deploy without auto-start: `.\scripts\Deploy-SleepTimer-Desktop.ps1` (add `-Launch` only if user wants it).
- Power actions are blocked when `-DryRun`, `SLEEPTIMER_DRY_RUN=1`, or `SLEEPTIMER_CI=1` (`Test-NoPowerAction`).

## Not canonical (experiments — do not deploy)

- `CoolTimer.ps1` — Nightfall UI experiment
- `SleepTimer.ps1` / variants — legacy suite
- `SleepTimer-Electron/` — separate Electron UI
- `luxgrid/` + Snoozurp bridge — RGB platform; **Lights Out v3.9+** emits optional events (`EmitLuxGridEvents`). See `LUXGRID-LIGHTSOUT.md`.
- `nightfall/src/` — WPF preview (future migration)
- `scripts\Ready-Tonight.ps1`, `scripts\Deploy-Nightfall-Desktop.ps1` — legacy Nightfall desktop deploy; use `Deploy-SleepTimer-Desktop.ps1` instead

When the user says “sleep timer” in a bedtime/nightly context, assume **SleepTimer-Tonight**, not Sleep Timer Pro v3 or Nightfall bundle.

## UI visual reference (do not forget)

Also use the UI mockup images in [`docs/assets/lights-out/`](docs/assets/lights-out/) as visual reference targets when polishing the **canonical** app (`SleepTimer-Tonight.ps1`).

Full guide: [`docs/lights-out/UI-REFERENCE.md`](docs/lights-out/UI-REFERENCE.md)

| Asset | Surface | Use for |
|---|---|---|
| `classic-simple-timer-reference.png` | Classic UI | Timer amount first, quick chips, ring, action pills, START — keep simple |
| `night-lobby-reference.png` | Night Lobby | Header, hero card, dark premium layout, trust badges, ring placement |
| `morning-proof-reference.png` | Morning Proof | Proof/result layout, clean dark card, stats rows, polished readability |
| `last-light-reference.png` | Last Light | Exit the Grid, shutdown finale, full-screen overlay, countdown drama |

**Original mockup names (2026-06-04):** `lights_out_pc_bedtime_mode_dashboard.png`, `lights_out_pc_app_interface.png`, `lights_out_pc_final_disconnect_sequence.png` — copied to repo assets above.

Do **not** treat mockups as exact pixel-perfect requirements. Treat them as the visual north star:

- Dark premium Windows app
- Readable timer first
- Glowing but not cluttered
- Analog/digital ring as the central control
- **Classic stays simple**
- **Steam / Night Lobby gets the premium treatment**

**Important:** Do not lose these reference images. Do not replace the current working UI with a totally new design. Use the images to guide polish only. Ring and UI work stay inside `SleepTimer-Tonight.ps1` and `modules\LightsOut.*.psm1` — not `CoolTimer.ps1`, Electron, or WPF experiments.

UI references are now preserved in repo memory, not chat history.

**Before future UI work:**

1. Read [`docs/lights-out/UI-REFERENCE.md`](docs/lights-out/UI-REFERENCE.md).
2. Use [`docs/assets/lights-out/`](docs/assets/lights-out/) as visual reference assets.
3. Keep Classic UI simple and usable first.
4. Use Steam/Night Lobby for premium polish.
5. Do not replace the canonical `SleepTimer-Tonight.ps1` app.
6. Do not start a new UI stack.
7. Do not change shutdown safety while polishing visuals.

## Launcher split (confirmed — do not change)

| Launcher | Mode | Purpose |
|---|---|---|
| `Lights Out.lnk` / `Lights Out.bat` | **Classic live** (`-ClassicUi -NoAutoStart`) | Real bedtime timer — do **not** change |
| `Lights Out Premium Preview.bat` | **Steam / Night Lobby DryRun** (`-SteamUi -DryRun -NoAutoStart`) | Premium UI polish preview only |

**Do not judge Steam UI from the normal Lights Out shortcut.** That path is intentionally locked to Classic.

Any future premium UI work must be checked through **Premium Preview** only:

```powershell
Get-Process SleepTimer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-SteamUi','-DryRun','-NoAutoStart'
```

Or double-click `Lights Out Premium Preview.bat`.

Classic and Steam are two modes in the same canonical app (`SleepTimer-Tonight.ps1` + `modules\LightsOut.*.psm1`) — not separate products or a new UI stack. Do not change `Do-PowerAction` or `Test-NoPowerAction`.

## Ecosystem integration (modular — not standalone-only)

Lights Out is **one module inside the bigger Neural ecosystem**, not a dead-end app.

```text
Standalone first.  Modular always.  Hard dependency never.
```

Full contract: [`docs/lights-out/INTEGRATION-CONTRACT.md`](docs/lights-out/INTEGRATION-CONTRACT.md)

| Rule | Detail |
|---|---|
| Canonical app | `SleepTimer-Tonight.ps1` → `SleepTimer.exe` — unchanged |
| Core works alone | Fully offline; no LuxGrid, NeuralOS, cloud, or future app required |
| Integration style | Optional modules, local JSON events, CLI flags, file bridges |
| Ecosystem targets | NeuralOS, LuxGrid, NeuralShell, Snoozurp, NeuralTube, future dashboards |
| Off by default | `EmitLuxGridEvents` and all future bridges optional |
| Power authority | `Do-PowerAction` + `Test-NoPowerAction` only — listeners never control shutdown |
| Do not | New UI stack, hard deps, cloud, redesign UI for integration |

```text
Lights Out Core → timer, safe power, confirm, audit
Optional bridges → LuxGrid events, NeuralOS, Snoozurp, NeuralShell, future launchers
```

## Docs, README, and CI (task routing)

| Task | Read / run |
|------|------------|
| Public README / user docs | [`README.md`](README.md), [`docs/lights-out/`](docs/lights-out/) |
| Doc lint | `.\scripts\Test-Docs.ps1` |
| CI workflows | [`.github/workflows/lights-out-ci.yml`](.github/workflows/lights-out-ci.yml), [`docs/lights-out/CI.md`](docs/lights-out/CI.md) |
| Release QA | [`docs/lights-out/RELEASE-CHECKLIST.md`](docs/lights-out/RELEASE-CHECKLIST.md) |

**Docs must preserve:**

- Classic vs Premium Preview launcher split (normal = Classic live; preview = Steam DryRun)
- Standalone-first modular integration rule (no hard deps on LuxGrid/NeuralOS)
- CI must never launch real shutdown (`SLEEPTIMER_CI=1`, `SLEEPTIMER_DRY_RUN=1`, no `-Launch` on deploy)
