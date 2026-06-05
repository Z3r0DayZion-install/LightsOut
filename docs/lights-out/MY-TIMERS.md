# My timers (saved profiles)

Save any Lights Out setup as a **named one-tap timer**.

## Save

1. Set **Duration**, **At time**, or **Calendar** (and action: Sleep, Shutdown, etc.).
2. Tap **+ Save** under **My timers**.
3. Name it (e.g. `Weeknight sleep`, `Friday movie`, `Vacation shutdown`).
4. Choose whether tapping the button should **start immediately**.

## Use

- Tap a pill under **My timers** — applies settings and starts (if you enabled auto-start).
- **Edit** — delete saved timers you no longer need (max 24).

## What gets saved

| Mode | Saved |
|------|--------|
| Duration | Minutes/seconds + action |
| At time | Wall-clock time + action |
| Calendar | Date/time, event title, `.ics` path or feed URL reference |

Stored in `%LOCALAPPDATA%\CoolTimer\settings.json` under `SavedTimers`.

## Live calendar feed

See [CALENDAR.md](CALENDAR.md) — paste your Google **secret iCal** URL under **Calendar → Live feed** for automatic next-event scheduling.
