# Lights Out safety model

Lights Out controls real shutdown, sleep, restart, hibernate, and lock on your PC. This document defines the safety contracts agents and CI must preserve.

**Do not change `Do-PowerAction` or `Test-NoPowerAction` without explicit user request.**

---

## Power gate (sole execution path)

```text
Test-NoPowerAction  →  blocks if DryRun / Demo / CI
Do-PowerAction      →  sole path that issues real power commands
```

| Function | Role |
|----------|------|
| `Test-NoPowerAction` | Returns true when power must be blocked (DryRun, Demo, `SLEEPTIMER_CI=1`) |
| `Do-PowerAction` | Executes Shutdown/Sleep/Restart/Hibernate/Lock after all gates pass |

No other code path may issue real power commands. Ecosystem listeners (LuxGrid, NeuralOS, etc.) must **never** bypass this gate.

---

## DryRun / CI gates

| Gate | How enabled | Effect |
|------|-------------|--------|
| **`-DryRun` flag** | CLI or `SLEEPTIMER_DRY_RUN=1` | UI runs; power blocked |
| **`-Demo` flag** | CLI or `SLEEPTIMER_DEMO=1` | Implies DryRun; skips settings/log writes |
| **`SLEEPTIMER_CI=1`** | CI / automated test env | Power blocked in all automated runs |

When `Test-NoPowerAction` is true:

- `Do-PowerAction` logs `power_blocked` and exits without power command.
- Countdown, final confirm, Last Light, and Morning Proof may still run for UI testing.
- Audit log records safe-mode blocks.

---

## User-facing safety features

| Feature | Detail |
|---------|--------|
| **60s minimum** | Production builds cannot arm sub-60-second shutdown |
| **Final confirm** | 5-second dialog after countdown — snooze or proceed |
| **Emergency cancel** | `Ctrl+Shift+S` global hotkey anytime |
| **Lobby-first** | App opens without auto-start unless `-Start` or setting enabled |
| **Power blocker warn** | Warns if apps may block shutdown/sleep |
| **Audit log** | `%LOCALAPPDATA%\CoolTimer\actions.log` — local only |

---

## Agent safety rules

1. **Never launch `SleepTimer.exe` in CI** without `-DryRun` or Demo.
2. **Never deploy with `-Launch`** unless user explicitly asks.
3. **Never run GUI smoke tests** that could trigger real shutdown.
4. **Safe validation only:** `Test-AgentSafety.ps1`, `Test-SleepTimer.ps1`, `Test-Docs.ps1`, `CI-Local.ps1`.
5. **Live commands are for humans only** — document them; do not automate in scripts/CI.

---

## Safe vs live commands

### Safe (agents, CI, previews)

```powershell
# Static tests — no app launch
.\scripts\Test-AgentSafety.ps1
.\scripts\Test-SleepTimer.ps1
.\scripts\Test-Docs.ps1
.\scripts\CI-Local.ps1

# Safe UI preview
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-DryRun','-NoAutoStart'
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-SteamUi','-DryRun','-NoAutoStart'
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-Demo','-NoAutoStart'

# Safe deploy
.\scripts\Deploy-SleepTimer-Desktop.ps1
```

### Live (human bedtime use only)

```powershell
# USER_LAUNCHER: end-user Desktop shortcut (live Classic UI)
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -NoAutoStart

# Human-requested live run — never in CI
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -Minutes 23 -Action Shutdown -Start
```

---

## CI environment

```text
SLEEPTIMER_CI=1
SLEEPTIMER_DRY_RUN=1
```

Both must be set in GitHub Actions and local CI. See [`CI.md`](CI.md).

---

## Related docs

- [`CLI.md`](CLI.md) — flag reference
- [`RELEASE-CHECKLIST.md`](RELEASE-CHECKLIST.md) — QA safety steps
- [`../agent-handbook/07-SAFETY-AND-TESTING.md`](../agent-handbook/07-SAFETY-AND-TESTING.md) — handbook safety chapter
- [`INTEGRATION-CONTRACT.md`](INTEGRATION-CONTRACT.md) — ecosystem listeners must not control power
