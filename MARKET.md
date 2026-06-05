# Lights Out — market research (June 2026)

## Category

**Windows countdown power timer** — schedule shutdown / sleep / restart after a duration or (in advanced tools) clock time.

Not the same as: focus timers (Pomodoro), media sleep timers (stop Spotify), or enterprise power managers (Desomnia, Auto Shutdown Manager).

---

## What’s on the market

| Product | Distribution | Size | Strengths | Weaknesses |
|---------|--------------|------|-----------|------------|
| **Shutdown Timer Classic** | [Microsoft Store](https://www.microsoft.com/store/apps/9NTDG6C9BTTW), winget `LukasLangrock.ShutdownTimerClassic`, GitHub | ~860 KB, C# | CLI automation, graceful shutdown, lock/hibernate, Store + winget, MIT | Generic UI, no “bedtime ritual”, no live tray ring |
| **Wise Auto Shutdown** | Vendor site, freeware | Small | Daily schedules, delay 10m–4h, simple 2-panel UI | Bundled with Wise brand, dated UX, no countdown ring |
| **SleepTimer Ultimate** | sleeptimer.net, winget `SleepTimer.SleepTimer.Ultimate` | Installer | Feature-rich, long history | Proprietary, cluttered, dynamic download URLs (winget pain) |
| **Supreme Lite Auto Shutdown** | GitHub | <50 MB | Idle/CPU/battery triggers, themes, gamification | Bloated for nightly ritual, gimmicky |
| **Windows built-in** | `shutdown -s -t N`, Task Scheduler | 0 | Always there, scriptable | No tray UX, easy to forget, no snooze/confirm |
| **Desomnia / IT tools** | Service installers | Heavy | Network/session aware, WoL | Wrong audience for personal bedtime |

**Bar to be “real”:** Microsoft Store and/or winget, signed installer, CLI optional, graceful shutdown option, tray presence, Windows 10/11.

---

## What users actually want (from forums + reviews)

1. **“Don’t forget it’s running”** — always-visible or tray countdown
2. **“Don’t kill my work accidentally”** — warning + snooze + cancel
3. **“Set and forget at bedtime”** — auto-start, run at login, same duration every night
4. **“Don’t fight Windows sleep”** — `powercfg /requests` blockers are a common pain (other apps prevent sleep)
5. **Trust** — signed exe, no adware, no phone-home (Wise/SleepTimer.net skepticism)

---

## What Lights Out already has (differentiators)

| Feature | Lights Out | Typical competitor |
|---------|------------|-------------------|
| Bedtime-first UX (28:20 presets, auto-start) | Yes | Manual each time |
| Progress ring + **live tray ring** | Yes | Static icon or window only |
| End time clock (“Ends at 2:47 PM”) | Yes | Rare |
| Emergency cancel (global hotkey) | Ctrl+Shift+S | Tray only |
| Final confirm + punch animation | Yes | Some have confirm only |
| Local audit log, no telemetry | Yes | Often unclear |
| Portable + per-user install | Yes | Yes |

---

## What’s **missing** to be legit (priority)

### P0 — Trust & distribution (do before marketing)

- [ ] **Production code signing** (not dev cert) — SmartScreen green
- [ ] **Winget PR merged** — `KickA.SleepTimer` or rebrand `KickA.LightsOut`
- [ ] **Dedicated GitHub repo** (not buried in ForgeCore_OS) — README, issues, screenshots
- [ ] **Release cadence** — tagged releases match VERSION; changelog public
- [ ] **Graceful shutdown option** — `-Force` vs apps that can block (Shutdown Timer Classic has this)

### P1 — Table stakes (competitors have these)

- [ ] **CLI / autostart args** — e.g. `LightsOut.exe /minutes 28 /action shutdown /start`
- [ ] **Schedule by clock** — “shutdown at 11:30 PM” not just countdown (STC 1.3.2 added this)
- [ ] **Pause/resume** — STC has; we have Pause but polish
- [ ] **Hibernate / Lock** actions — optional, low priority for your ritual
- [ ] **MSIX or Store listing** — STC’s legitimacy anchor

### P2 — Moat (why pick Lights Out)

- [ ] **Ritual profiles** — one tap: “Weeknight 24m shutdown”, “Movie 45m sleep”
- [ ] **Blocked-shutdown detection** — warn if `powercfg /requests` shows blockers before arming
- [x] **LuxGrid bridge** — optional RGB events via `%LOCALAPPDATA%\LuxGrid\events\inbox\` (v3.9, off by default)
- [ ] **.NET native rewrite** — only when PS2EXE limits signing/Store (later)

### P3 — Skip (market bloat)

- Gamification / achievements (Supreme Lite)
- CPU/network idle triggers (different product)
- Cloud accounts, mobile, subscriptions

---

## Positioning statement

**Lights Out** — *The bedtime shutdown timer for Windows.*

Not “another task scheduler.” One job: open it, see when the PC dies, cancel if you’re still up, lights out.

**Target user:** Single-PC nightly habit (you), then same persona on r/Windows11, winget, Store.

**Price:** Free, MIT — monetize LuxGrid ritual pack later if anything.

---

## 90-day legit checklist

| Week | Ship |
|------|------|
| 1 | Production cert, winget live, repo + screenshots |
| 2 | Graceful shutdown toggle + CLI `/start /minutes /action` |
| 3 | Microsoft Store submission (or MSIX sideload page) |
| 4–12 | Clock schedule, blocked-shutdown hint, dogfood + 1.0 blog post |

---

## Competitive verdict

The market is **crowded but mediocre** — old UX, no emotional “ritual,” most tools feel like utilities from 2010. Shutdown Timer Classic is the quality bar (Store + winget + CLI). **Nothing owns “bedtime lights out”** as a brand.

Lights Out is already more opinionated than most; it’s **not legit yet** because of signing, repo/discovery, and missing CLI/graceful shutdown — not because the core idea is weak.
