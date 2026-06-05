# Three features you will not find in other shutdown timers

Lights Out v5+ adds three capabilities that typical sleep/shutdown utilities (Shutdown Timer Classic, Wise Auto Shutdown, etc.) do not offer.

## 1. Lights Dim Phase

After the punch animation when the countdown hits zero, the screen enters a **90-second dimming ritual** before the final confirm or power action.

- Progressive dark overlay (train your brain that lights are going down)
- Optional **+5 min wind-down** or **Proceed now**
- LuxGrid event: `lights.dim`
- Toggle: **Dim phase (90s)** in settings (5 seconds in dry-run/CI)

## 2. Sleep Ledger

A **habit streak** built from your local `actions.log` — no cloud, no account.

- Tracks completed lights-out nights, snoozes, and cancels
- **Sleep streak** link (top-right) and tray **Sleep ledger**
- Seven-day dot view in the dialog

## 3. Bedtime Pact + Household Harmony

### Bedtime Pact

You set a **must-be-asleep-by** time. If snoozing would push the shutdown past that pledge:

- Warning dialog (pact break)
- After **2 breaks**, snooze is locked for that session

### Household Harmony

Sync two PCs in the same home:

1. **Export my plan** — writes `household-export.json` and copies a 6-letter code
2. Partner **Import partner plan** on another machine
3. Lights Out schedules to the partner time and reports if plans align within 15 minutes

Tray: **Household sync...** | Card: **Household sync** button

---

All three are local-first, private, and optional.
