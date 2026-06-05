# Calendar scheduling

Lights Out can schedule shutdown, sleep, or restart for a **specific date and time** using your calendar app.

## Supported calendar apps

Export a **`.ics`** file from any of these (same format everywhere):

- **Google Calendar** — Settings → Import & export → Export
- **Microsoft Outlook** — File → Save Calendar → `.ics`
- **Apple Calendar** — File → Export → `.ics`
- **Windows Calendar** — export via Outlook or account sync, then export `.ics`

## In the app

1. Tap **Calendar** (next to Duration / At time).
2. Click **Import .ics** and choose your exported file.
3. Pick an event from the list — the countdown runs until that **start** time.
4. Press **Start** (or let auto-start run).

You can also set **date + time** manually with the date and time pickers without importing.

Tray menu: **Calendar event...** opens the same importer.

## Command line

```powershell
# Next upcoming event in an .ics file
SleepTimer.exe -Calendar "C:\Users\You\Downloads\calendar.ics" -Action Sleep -Start

# Specific date and time (no .ics)
SleepTimer.exe -At "2026-12-31 23:30" -Action Shutdown -Start
```

Environment variables: `SLEEPTIMER_CALENDAR`, `SLEEPTIMER_AT`

## Live feed (Google / Outlook / Apple)

No OAuth required — use the calendar app’s **subscribe / secret iCal URL** (must be `https://`):

1. **Google Calendar:** Settings → your calendar → **Integrate calendar** → **Secret address in iCal format** (copy URL).
2. In Lights Out: **Calendar** mode → **Live feed** (or tray **Calendar live feed...**).
3. Paste URL, set refresh interval (default 30 min), optional **Auto-start** after sync.
4. **Sync now** to test.

Lights Out downloads the feed, picks the **next upcoming event** (90-day window), and schedules shutdown/sleep for that **start** time.

## Tips

- Manual **Import .ics** is still a snapshot; **Live feed** refreshes automatically.
- Re-export `.ics` after you add new events if you only use file import.
- The timer uses the event **start** time (`DTSTART`).
- **At time** mode = today/tomorrow at a wall-clock time. **Calendar** mode = one-shot date+time, imported event, or live feed.

See also [MY-TIMERS.md](MY-TIMERS.md) for saved named timers.
