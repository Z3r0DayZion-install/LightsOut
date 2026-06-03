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

## Tips

- Re-export `.ics` after you add new events (exports are a snapshot, not live sync).
- The timer uses the event **start** time (`DTSTART`).
- **At time** mode = today/tomorrow at a wall-clock time. **Calendar** mode = one-shot date+time or imported event.
