# UI research report (external)

**Filed from:** user research deliverable · **Repo alignment:** 2026-06-03

| Report item | Repo status |
|-------------|-------------|
| Sleep Clearance panel | **Shipped v1** — `Get-SleepClearanceReport`, Steam lobby panel. See [`SLEEP-CLEARANCE.md`](SLEEP-CLEARANCE.md) |
| Agent safety lint / DryRun | **Shipped** — `Test-AgentSafety.ps1`, `CI-Local.ps1` |
| Morning Proof dashboard | **Shipped v1** — [`MORNING-PROOF.md`](MORNING-PROOF.md) |
| Last Light / Unplug finale | **Spec ready** — [`LAST-LIGHT-SEQUENCES.md`](LAST-LIGHT-SEQUENCES.md) |
| Tonight Cards (library tiles) | **Spec ready** — [`TONIGHT-CARDS.md`](TONIGHT-CARDS.md) |
| Bedside Remote | **Spec ready** — [`BEDSIDE-REMOTE.md`](BEDSIDE-REMOTE.md) |
| Agent idea brief | [`AGENT-IDEA-BRIEF.md`](AGENT-IDEA-BRIEF.md) |
| Cancel puzzle / hard cancel | **Planned** — emergency cancel stays easy; optional friction later |
| Steam overlay / download-aware | **Planned** — LuxGrid optional; no Steamworks overlay yet |
| Ritual presets | **Partial** — Weeknight / 28:20 / Movie / Bedtime shipped |
| Onboarding wizard | **Not started** |
| Browser/media guard | **Deferred** — v1 Clearance uses power blockers only |

Agents: treat this as **ideas and flows**, not implementation truth. Canonical behavior: [`../agent-handbook/AGENT-QUICKSTART.md`](../agent-handbook/AGENT-QUICKSTART.md).

---

# Executive Summary  

Lights Out’s UI should combine trusted countdown controls with engaging, motivational elements.  Existing “sleep timer” apps on PC and mobile offer simple countdown timers (often always-on-top windows with color-coded urgency and fade-out audio).  However, Lights Out’s gaming context allows deeper integration: think Steam’s Big Picture mode, in-game overlays, and post-shutdown summaries.  We surveyed shutdown/sleep-timer apps, mobile bedtime features, and gaming overlays to identify UI patterns.  We then brainstormed 25 concrete features (grouped into **Trust/Clearance**, **Rituals/Modes**, **Anti-Cancel Friction**, **Proof/Analytics**, **Integrations**, **Accessibility**, **Onboarding**, **Monetization**).  Of these, 6–8 are highly novel (e.g. a “Sleep Clearance” pre-play checklist, enforced-cancel puzzles, AI-driven morning analytics).  Each novel idea is evaluated for user value, privacy/safety risk, and implementation cost.  We then sketched detailed UI flows (with wireframe mockups and mermaid diagrams) for the top 8 ideas, and devised a feasibility matrix and 3-month roadmap (MVP, v1, v2).  

Key findings: Lights Out needs a clear, controller-friendly “lobby” UI (especially for Steam Big Picture) with a prominent **Sleep Clearance** panel before starting.  After a session, a **Morning Proof** analytics screen (streaks, summary) builds engagement.  To prevent casual canceling, we propose a “serious cancel” confirmation (e.g. math puzzle or long-hold button).  Steam integration (in-game timer overlay, download-aware shutdown) and optional smart-home/RGB cues add polish.  Accessibility (text-to-speech, color modes) and guided onboarding ensure broad usability.  All features prioritize user trust: e.g. no hidden shutdowns, no data collection beyond local session stats. 

**Sources:** We reference shutdown/sleep apps and Steam docs for UI examples (Shutdown Timer Classic and Android Sleep Timer have visible countdowns, color cues, fade-out audio; Steam’s new in-game overlay now supports a clock/timer).  Sleep experts advise limiting screen time before bed and keeping a consistent schedule, aligning with Lights Out’s goal of healthy shutdown routines.  

# Survey of Existing Sleep/Timer UIs  

- **PC Shutdown Timers:** Apps like *Shutdown Timer Classic* use a simple window: pick a power action (shutdown/sleep/etc.) and duration.  The countdown window is always-on-top by default (so you don’t forget) and can be hidden to the system tray.  As time runs out it changes color (green→yellow→orange→red) to signal urgency and even plays a final animation.  This color-coding is an effective visual cue for “falling asleep.”  Many such apps allow “Run in background” (tray icon) and right-click to cancel or extend.  

- **Mobile Sleep Apps:** Android/iOS sleep/music timers often simply **pause media** at bedtime.  For example, *Sleep Timer (Audio & Video)* fades out audio/video gradually to avoid jarring stops.  Key UI patterns include large start/stop buttons, slider or picker for time, and *background control* via notification (so you can start/stop without opening the app).  They may also toggle phone settings (turn off Wi-Fi/Bluetooth when done).  The focus is on “set it and forget it” – once the timer’s started, it silently enforces shutdown with minimal further input.  

- **Bedtime Schedules / Focus Modes:**  Mobile OSes (iOS Health, Android Zen Mode) let you schedule recurring bedtimes and trigger Do-Not-Disturb or blue-light filters.  The UI is typically a **clock/panel** showing bedtime vs wake time with drag handles.  Users can set wind-down reminders and “sleep focus” to mute notifications before bed.  These emphasize *routine*, consistent timing, and reducing screen use (experts note >2 hours of evening screen time disrupts melatonin).  Lights Out could borrow the idea of scheduling or routines (see Features).  

- **Gaming Overlays / Steam:**  Steam’s **in-game overlay** (Shift+Tab) now includes a built-in timer/clock feature.  Gamers can pin the system clock or a timer on-screen via the overlay.  (Users report it appears only inside the game window and doesn’t remember position, highlighting a potential UX issue.)  Big Picture Mode (TV-friendly UI) typically uses large tiles and gamepad navigation.  Any Lights Out UI in Steam should follow those patterns: big text, simple controller inputs, minimal clutter.  

- **Smart-Home / TV Apps:**  Smart TV and Android TV often include simple “sleep timers” buried in settings; mobile apps for “bedtime routines” exist (e.g. children’s chore timers, focusing on lists and rewards).  More advanced systems use voice assistants (e.g. “Alexa, time to sleep” routines).  While Lights Out is PC-only, inspirations include voice-on and ambient modes.  

- **Takeaway:** Key patterns are a **prominent timer/countdown display**, simple start/stop controls, and low-friction operation (background running, dismissable notifications).  Many apps use color or notifications as feedback.  Crucially, experts urge minimizing evening screen stimulation and keeping routines – so Lights Out should both enforce a cutoff and encourage consistency.  

# Lights Out UI Touchpoints  

Lights Out spans several user touchpoints on Windows/Steam.  Below are the main interfaces to consider:

- **Lobby (Steam Big Picture Launcher):** The initial screen before starting a Lights Out session.  Think of it like a game’s launch menu.  The Steam Big Picture interface should have a large “PLAY” button, plus any settings toggles.  We can add panels here (e.g. *Sleep Clearance* summary, ritual mode chooser).  Controller/keyboard friendly: arrows or a simple menu.  

- **PLAY Button:** The big action control.  Starting it goes from “Lobby” to active mode.  We may require holding or confirmation on “PLAY” for safety.  

- **Session UI:** Once started, the “countdown” UI appears.  It might be an always-on-top window (like other timers) or an in-game overlay (if the game is running).  It should show time remaining and allow emergency cancel (with high friction).  Since the actual power action happens after timer ends, the session UI must allow abort or adjust, and should remain visible or easily accessible (like a tray icon or overlay).  

- **Deployers/Launchers:** These are scripts or `.bat` files used by devs to deploy or run the timer (e.g. Desktop shortcuts).  They should offer debug vs production modes (DryRun vs Launch).  In UI terms, maybe a “Test Mode” toggle in settings so that developer-run timers don’t actually shut down.  

- **LuxGrid RGB:** Optional RGB lighting system.  The UI could include an on/off toggle or show RGB status.  E.g. Lights Out could flash colors through LuxGrid to indicate time left or warnings.  Since LuxGrid is optional, the UI should allow disabling it.  

- **Notifications:** Windows toasts (via `SteamUtils::SetOverlayNotificationPosition`) can be used for final countdown or errors.  E.g. notify “Clear for Lights Out” or “Shutdown Cancelled”.  We should plan where to show notices (Steam overlay? Windows 10/11 native?)  

- **Audit Log / History:** Possibly an in-app log view (or file) listing past sessions, any crashes or cancelled actions.  The UI can have a “History” tab.  This gives trust: “hey, nothing weird happened last time”.  

- **Next-Morning Proof Screen:** When the PC is turned back on after Lights Out, a summary splash could show: “11:32 PM – Shutdown executed. Streak: 4 nights.”  This could be a small window or notification after login.  If the PC stays off (computer is off, so maybe display on next login), or it could email or just be on log.  In any case, it’s a UI / UX element to celebrate success.  

These touchpoints span from pre-session to post-session.  The design should be cohesive: e.g. colors/themes from Lobby to Session to Proof all match.  Steam controllers/keyboard shortcuts should work at each step, and safety is paramount (no hidden launches).  

# Proposed UI Feature Ideas  

Below are 25 concrete features, organized by category.  (Novel ideas are **bold**.)

**Trust / Clearance:** Features that ensure users are fully aware of the impending shutdown.  
- **Sleep Clearance Panel:** Before hitting PLAY, show a summary (“Clear for Lights Out” vs warnings) including power action, timer mode, blockers, etc. (see *Sleep Clearance* design below).  
- Safety Confirmation: Require a 3‑second hold or double-click to start the timer (to avoid mis-clicks).  
- Emergency Cancel Notice: Make the abort button clearly labeled and possibly limited (see Anti-Cancel).  
- **Wake-up Call / Morning Summary:** After execution, display a proof-of-play summary (time of shutdown, streaks, etc.).  
- “Dry Run” mode indicator: If user/test mode is on, clearly label it in UI (no actual shutdown).  
- Pre-run Checklist: Optionally, do a quick system check (e.g. “Are you really ready?” prompt).  

**Rituals / Modes:** Customizable presets and contexts for different scenarios.  
- Preset Modes: e.g. *“Gaming Mode”* (long timer, no confirmation), *“Movie Mode”* (medium, maybe dim lights), *“Bedtime Mode”* (shorter timer, strict stop).  
- “Tonight on Lights Out” mode: A fun title each evening.  
- Recurring Schedules: Allow scheduling Lights Out at regular bedtimes (leveraging Windows Task Scheduler maybe).  
- Wind-down Routine: Guided steps before start (e.g. “3-minute stretching reminder”).  
- Relaxation Sounds: (Out of scope for core app, but could play a lullaby track).  
- Thematic UI: E.g. “Cinema” theme dims the lights in Lobby, “Space” theme with stars, etc.  
- Gamification: Bedtime *achievements* or points for hitting targets (could belong in Monetization too).  

**Anti-Cancel Friction:** Discourage impulsive canceling.  
- **Cancel Puzzle:** When Cancel is pressed after initial warning, pop up a simple puzzle (math, memory) that must be solved to truly cancel (prevents groggy cancellations).  
- Long-press to Cancel: Require the cancel button to be held for 3 seconds (like emergency confirms).  
- Time-locked Cancel: After starting, disable cancel for first N minutes (if safety allows).  
- “I am sure” Checkbox: Ask user to type or check “I promise I want to cancel.”  
- Cooldown Snooze: Allow only 1 quick postpone per night (limiting repeat cancellations).  
- Anti-bypass: If a game is full-screen, use Steam overlay or taskbar to expose the cancel control (ensures user cannot hide the UI).  

**Proof / Analytics:** Feedback and motivation after use.  
- **Morning Report Screen:** On next login, display “Lights Out Success!” with stats (time off, saved energy, streak length).  
- Sleep Score: Rate the “health” of the shutdown (no blockers, on time) and display a score/letter.  
- Trends Graph: Show weekly/monthly sleep consistency (in vs out times).  
- Social Share: Optionally share “I turned off my PC at 11:00 PM!” with friends (requires link accounts, so we’d handle privacy).  
- Achievement Badges: E.g. “7-Day Bedtime Streak” (encouraging habit).  
- Post-Session Survey: Ask “Did you sleep well? Rate your night” to build user trust and data.  
- Energy Indicator: Estimate power saved (e.g. “5W for 6h = 0.03 kWh saved” maybe fun).  

**Integrations:** Connect Lights Out with other systems.  
- **Steam Overlay Timer:** In-game display of time left (taking advantage of Steam’s clock/timer overlay).  
- Steam Downloads: Detect if Steam is downloading; either postpone shutdown until complete, or warn the user.  
- OS Sleep/Wake Prevention: Use `SetThreadExecutionState` or other APIs to prevent sleep if timer is running.  
- Browser Extension: Alert or pause video playback when Lights Out is scheduled (e.g. stop Netflix/YouTube at cutoff).  
- Media Player Hooks: Pause music/video players at timer end (like SleepTimer app).  
- LuxGrid/Smart-Light Sync: Gradually dim smart lights or RGB strips as timer winds down (visual cue).  
- Calendar Sync: Import nightly schedule or put Lights Out as a calendar event.  
- Discord/Slack Status: Automatically set status to “Sleeping” once countdown starts.  
- Cloud Sync: Save user settings (for Premium users) to sync across devices (if multi-PC, requiring login).  

**Accessibility:** Ensuring UI works for all users.  
- High-Contrast Theme & Large Text: Configurable font sizes and color schemes (for visually impaired).  
- Screen Reader Support: Verbose ARIA labels or spoken announcements of countdown and status.  
- Audio Cues: Optionally play gentle tones or verbal countdown as time runs out.  
- Keyboard-Only Mode: All controls accessible without mouse (e.g. number keys to set time, Enter to start).  
- Vibration Feedback: If on a laptop with haptic engine, vibrate subtly before shutdown.  
- Colorblind-Friendly Indicators: Use shapes or text in addition to color (for colorblind users).  

**Onboarding / Help:** Guiding new users.  
- Setup Wizard: First-run tutorial that explains core concepts (SAFE mode, -DryRun).  
- “Handoff Prompt”: Quick summary of “Lobby first, 60s min, no -Launch” rules (like our AGENT-QUICKSTART in UI form).  
- Tooltips / Explainers: Contextual hints (e.g. hover over “DryRun” to explain it).  
- Demo Mode: A dummy run (no shutdown) to show how it works.  
- FAQ Panel: Common Qs (citing safety rules).  

**Monetization / Upgrade:** (Keep user value high; consider optional extras.)  
- “Pro” version unlocks detailed analytics and smart home features.  
- Cosmetic Themes: Additional UI skins (optional purchase).  
- Pet Mode: Virtual pet or mascot that says “Good night!” (quirky, for delight).  
- Donation Prompt: Non-intrusive “Support development” button (if app is free).  
- Branded DLCs: Partner with sleep apps or designers for theme packs (low priority).  
- Reward System: Unlock badges/cosmetics via usage (gamified, no actual paywall).  

Each feature should be validated against the safety rule: **never auto-shutdown without DryRun in dev mode**.  We’ll enforce this via our new lint tests.

# Novel Ideas (Unique to Lights Out)  

The following 6–8 ideas are **especially novel** in the market of sleep/timer apps:

1. **Sleep Clearance Panel (Trust/Clearance):** A pre-session checklist that reviews all conditions *before* the timer starts.  It displays **Power action**, **Timer mode**, **Auto-start status (lobby-first vs auto)**, **Running blockers** (apps preventing sleep), and **Media activity** (e.g. “Video playing”).  If all checks are good, it shows “**Clear for Lights Out**”; otherwise “**X may keep you awake**.”  *Novelty:* We didn’t find a desktop timer that summarises pre-shutdown risk factors.  *Value:* Builds user confidence (they know nothing urgent will interrupt).  *Risk:* Low (just reads system state).  *Complexity:* Medium (needs to query Windows for power blockers via `Get-PowerRequestBlockers`, check active media windows).  *Data:* Uses only local system status; no privacy concern.    

2. **Mandatory Anti-Cancel Puzzle (Anti-Cancel):** Instead of a simple “Are you sure?” dialog, Lights Out could present a brief challenge (e.g. solve 7*8 or match an icon) to confirm cancellation.  *Novelty:* Unlike apps that simply ask “Cancel?”, this seriously deters sleep-deprived clicks.  *Value:* Helps enforce bedtime decisions (gamey but effective).  *Risk:* Minimal, aside from user annoyance if sleep-deprived (should allow abort anyway).  *Complexity:* Low-medium (UI to display random question).  *Data:* No personal data, just random puzzle.  

3. **Morning Proof Dashboard (Proof/Analytics):** On next login, show “Lights Out Report”: e.g. “Last shutdown: 11:32 PM (last night) • Streak: 4 nights • Total screen-off time: 7h45m.”  Could include calendar chart of bedtimes, achievements (e.g. “2-week streak”), and suggested improvements.  *Novelty:* Sleep apps often track user’s own sleep, but a PC shutdown app with a “streak” is uncommon.  *Value:* Motivates consistency and shows tangible benefits.  *Risk:* Low (data is just usage stats).  *Complexity:* Medium (persist data between sessions, compute stats).  *Data:* Only local usage logs; could offer opt-in export (privacy benign).  

4. **Steam Overlay Integration (Integration):** While any Steam game is running, Lights Out could integrate into the Steam in-game overlay.  For example, hitting a custom shortcut (or using `ISteamFriends::ActivateGameOverlayToWebPage`) could bring up a mini-window showing the timer countdown or Sleep Clearance info, without leaving the game.  *Novelty:* PC sleep timers rarely tie into Steam’s overlay API.  *Value:* Very convenient for gamers who stay in full-screen – they can monitor Lights Out status mid-game.  *Risk:* Low (Steam overlay is user-activated).  *Complexity:* Medium-high (requires Steamworks integration or using the overlay web browser).  *Data:* No extra data; just overlay commands.  

5. **Browser/Media Guard (Integration):** A browser extension or background service that detects fullscreen media (e.g. YouTube, Netflix) and warns the user if Lights Out is about to end.  For example, if video is playing at timer end, pop up an overlay (“Lights Out is ready – pause video?”).  *Novelty:* No common PC app currently monitors all media for sleep timing.  *Value:* Prevents being jolted by an episode halfway through.  *Risk:* Moderate privacy (needs permission to read active tab or audio sessions).  *Complexity:* High (would need browser extension or hooking into media players).  *Data:* Could be done locally (no external server), but requires user permission to monitor apps.  

6. **Smart-Home “Bedtime Ritual” Mode (Integration):** Upon starting Lights Out, trigger connected devices: e.g. dim Philips Hue lights gradually, turn off smart TV or speakers, or start a white noise machine.  *Novelty:* Bridges PC sleep timer with IoT home automation (rare for a PC utility).  *Value:* Creates a true bedtime environment beyond the PC.  *Risk:* Low if user opt-in (need to authenticate devices).  *Complexity:* High (integrate with smart APIs like Philips Hue or IFTTT).  *Data:* Would require tokens to control user’s devices (security risk if mishandled).  

7. **Gamified Ritual/Avatar (Rituals/Monetization):** An avatar or pet (e.g. a “Sleepy Owl”) that appears in UI and “leads” the bedtime ritual (reminding to brush teeth, dim lights, etc.).  Earns badges or treats.  *Novelty:* Very uncommon for utility apps (more like kids’ apps).  *Value:* Can make the process fun for younger users or those who like gamification.  *Risk:* Very low (cosmetic).  *Complexity:* Low-medium (requires art/UI design).  *Data:* None.  *Monetization:* Could unlock outfits via purchase (but keep core free).  

8. **Advanced Voice/AI Assistant (Onboarding/Accessibility):** Use built-in voice recognition or an API to let user say “Hey Lights Out, start timer for 1 hour”.  Or have Lights Out read the Sleep Clearance report aloud.  *Novelty:* Voice-controlled shutdown timers are rare.  *Value:* Convenient hands-free control, helpful for accessibility.  *Risk:* Privacy (uses mic and possibly external API).  *Complexity:* High (speech-to-text integration, especially offline).  *Data:* Sensitive (audio), so it should be entirely local (e.g. Windows Speech).  

Each novel idea prioritizes user **value** (better trust, engagement, or fun) while considering **safety/privacy**.  For example, the Browser Guard and Smart-Home features require permissions, so they must be optional and transparent.  The core app requires no sensitive data (local usage only).  These innovations aim to distinguish Lights Out by adding playful and integrated experiences that motivate healthy bedtime habits.

# UI Flows for Top Ideas  

Below we detail the UI flow, screens, and interactions for the **top 8 features**.  Each section lists key states, user actions, error/fail states, and acceptance criteria.  (Mockup diagrams and flows are illustrative, not final art.)

## 1. Sleep Clearance Panel (Trust / Pre-PLAY)  

```
 *Fig: Illustration of a user (asleep at PC) hinting at a “Clear for Lights Out” message.*  

**Wireframe:** The Big Picture lobby shows a panel above PLAY:  

```
+--------------------------------------------------+
| 🌕 **Sleep Clearance**                            |
| Action: **Shutdown** @ 11:00 PM (Nightfall).      |
| Mode: Countdown (60 min)  ·  Auto-start: Lobby.  |
| ------------------------------------------------ |
| Status: ✅ No blockers detected.                  |
|         🔈 Video muted  ·  🔒 No unsaved docs.    |
| ------------------------------------------------ |
| [Play — Lights Out]                              |
+--------------------------------------------------+
```

- **Description:** Before PLAY is pressed, Lights Out gathers system state: which apps hold power requests, whether media is playing, etc.  It lists each check (action, mode, auto-start, blockers, download/stream warnings) with green “ok” or red “warning” icons.  If any warnings exist (e.g. “Steam download in progress”), it highlights them in red and changes the panel header to “⚠️ 2 items may keep PC awake.”  
- **User Actions:** The user reviews info.  If all is ✅, they proceed.  If warnings appear, they can cancel or “Override and PLAY anyway.”  
- **Error States:** If warnings exist and user tries to PLAY, show a confirmation modal: “X warning(s) detected. Proceed?” requiring confirmation.  
- **Acceptance:** Panel accurately reflects real-time state (test by opening a game or video, see warning appear).  Must not auto-dismiss; user must manually start timer.  According to plan, this should not launch SleepTimer.exe except in DryRun/testing mode.  

**Mermaid Flow:** System collects checks before launch.  

```mermaid
flowchart TD
    A[User opens Lights Out] --> B[Collect state: apps, media, settings]
    B --> C{Any warnings?}
    C -- Yes --> D[Panel shows warnings in red]
    C -- No  --> E[Panel shows "Clear for Lights Out" in green]
    D --> F[User can fix issues or override]
    E --> F
    F --> G[User presses PLAY (hold to confirm)]
    G --> H[Start countdown session]
```  

## 2. Hard-Cancel Confirmation (Anti-Cancel)  

```
+--------------------------------------------------+
| **Cancel Countdown?**                            |
| To prevent accidental cancel, solve to confirm:  |
|   7 × 6 = [  ?  ] ☐ (Solve and press Enter)      |
|                                                  |
| [Cancel Timer Anyway]    [Resume Countdown]      |
+--------------------------------------------------+
```

- **Description:** If the user clicks “Cancel” on the active countdown window, instead of immediately aborting, this dialog appears.  It shows a simple challenge (math question, memory phrase, or CAPTCHA-like field).  Only if the user answers correctly (or checks a special box) does Lights Out cancel; otherwise it ignores the attempt (or closes dialog).  The “Cancel Timer Anyway” button is disabled until correct answer is given (or hidden entirely, see design choice).  
- **User Actions:** User must solve the prompt or press-and-hold a confirm area (depending on variant).  If solved, the session aborts (countdown stops).  If user instead ignores or fails, the countdown continues.  
- **Error:** Wrong answer: show “Incorrect – try again” and re-enable input.  Time-out after some tries? Possibly just allow infinite tries to avoid frustration.  
- **Acceptance:** Ensure that rapid clicks on “Cancel” do not stop timer; only a correct puzzle answer does.  Test that tricky answers (e.g. blank, letters) are rejected.  This should deter casual abort.  

**ASCII Mockup (Cancel Puzzle):** Example screen layout.

```text
+-------------------------------------------+
|   Lights Out Cancellation                  |
|   Solve the puzzle to confirm cancellation:|
|                                           |
|   Q:  8 + 5 = [   ]   [Submit]            |
|                                           |
|   [X] I give up! (Enable only after answer)|
+-------------------------------------------+
```

**Mermaid Flow:**  

```mermaid
flowchart LR
    A[User clicks Cancel] --> B{Puzzle required?}
    B -- Yes --> C[Show puzzle dialog]
    C --> D{User submits answer}
    D -- Correct --> E[Stop timer, show "Cancelled"]
    D -- Incorrect --> F[Error message, keep dialog]
    B -- No --> E
    F --> C
```

## 3. Morning Proof Dashboard (Proof / Post-Session)  

```
 *Fig: Dawn over hills – metaphor for a new day and Lights Out’s morning report.*  

**Wireframe:** Upon next login (or after shutdown), display a screen:  

```
+--------------------------------------------+
| 🌅 **Lights Out Report**                   |
|                                            |
| Last Shutdown: *2026-06-03 10:45 PM*       |
| Slept 7.5 hours (bed at 10:45 PM, woke 6:15 AM) |
| Streak: 5 nights   |   Total SleepTime: 38h |
| 🚫 *0 cancels*    🚀 *5 starred habit days*   |
|                                            |
| [View Sleep Graph]   [OK, got it]           |
+--------------------------------------------+
```

- **Description:** A summary “card” with icons showing key stats: date/time of last LightsOut shutdown, total hours slept (estimated as time off), consecutive success streak, total successful nights, any sleep score.  Optionally, show a mini-chart (“View Sleep Graph”) of bedtimes over the past week.  
- **User Actions:** User can click “OK” to dismiss.  If they want details, they can open a full analytics screen or graph.  
- **Error:** If computer did not actually shut down (user canceled), show “Session canceled – no sleep logged.” (Possibly skip the report altogether).  
- **Acceptance:** Test by simulating a completed Lights Out (in DryRun mode) and rebooting; the report should pop up once.  Ensure it does NOT appear on each boot endlessly (once is enough).  

**Mermaid Flow:**  

```mermaid
flowchart TB
    A[PC boots up] --> B{Previous session completed?}
    B -- Yes --> C[Show Morning Proof screen with stats]
    B -- No  --> D[Do not show (either normal boot or no session)]
    C --> E[User clicks OK] --> F[Store stats, close screen]
```  

## 4. Steam In-Game Overlay (Integration)  

- **Wireframe:** When playing a game, the user can press a custom binding (or Shift+Tab to open overlay) to view a Lights Out window.  The overlay could have small tiles or a pop-up:  
   - One tile: **Time Left** (big countdown).  
   - Another: **Menu** (Pause, Cancel, Exit to Lobby).  
   - Optionally, **Clearance** info icon.  

```
+-----------------------------------------------+
| [Lights Out Overlay]                          |
|                                               |
|   ⏱  Time left: 34:21                         |
|   🔌 Action: Shutdown @ 11:00 PM              |
|   ✅  No blockers                              |
|                                               |
|   [⏸️ Pause Timer]  [❌ Cancel Timer] [💾 Lobby] |
+-----------------------------------------------+
```

- **Description:** Implements Lights Out controls inside the Steam overlay.  Could use `ActivateGameOverlay` calls or steamweb API.  Allows adjusting/canceling without alt-tabbing.  
- **User Actions:** Press overlay shortcut to open panel, use controller/keyboard to navigate.  
- **Acceptance:** Verify overlay appears correctly in several games (DirectX/OpenGL).  Ensure layout is legible on TV (Big Picture style).  (Citing Steamworks doc: no special requirements other than using Overlay API.)  

## 5. Steam Download-Aware Shutdown (Integration)  

- **Logic:** If a Steam download is active, Lights Out can optionally defer shutdown until download finishes or ask the user.  
- **UI Flow:**  In Sleep Clearance, add a check: “Steam Downloading: 20% done.”  
   - If enabled, either automatically extend timer or warn user with options: *“Wait for download / Shutdown now”*.  
   - Could pop up a notification mid-timer if a download starts.  

**Mermaid Flow:**  

```mermaid
flowchart TD
    A[Before PLAY] --> B{Is Steam downloading?}
    B -- Yes --> C[Add warning: "Downloading games (50%)"]
    C --> D{User choice: Wait / Ignore}
    D -- Wait --> E[Set auto-delay until 100%]
    D -- Ignore --> F[Proceed as normal (shutdown may pause download)]
    B -- No --> F
```  

- **Acceptance:** Test by starting a large Steam download and launching Lights Out.  If user chooses “Wait,” Lights Out should restart itself after completion (requiring a mini-scheduler or wake-timer).  

## 6. Browser Media Pause / Site Block (Integration)  

- **Wireframe:** When the timer is close to ending, show a popup (in-browser or overlay) if media is playing:  
```
+--------------------------------------------------+
| **Lights Out Reminder:** You have 1 minute left.  |
| Video playing on Chrome: “Stranger Things”        |
| [Pause Video] [Ignore]                           |
+--------------------------------------------------+
```  

- **Description:** A small web-overlay or system notification monitors media apps (YouTube, Netflix, Spotify) and warns the user.  It can attempt to pause via media keys or send JS commands (for example using a Chrome extension).  
- **Acceptance:** Prototype by playing a YouTube video, then have Lights Out notification fire 1 min before end.  Test that clicking “Pause” stops the video (e.g. sending media key or via the extension API).  Must not violate privacy – only active tab/or known apps are controlled.  

## 7. Ritual Selection Panel (Rituals/Modes)  

```
+--------------------------------+
| 🛏️ **Bedtime Mode**           |
| Automatically dim lights, stop |
| video 10min before timer.      |
|                                |
| 🌌 **Movie Mode**            |
| No dimming; allow one skip.    |
|                                |
| 🎮 **Gaming Mode**           |
| Longer timer, allow 2 extensions. |
|                                |
+--------------------------------+
| [Select Mode: Bedtime ▼]      |
| [  PLAY Tonight  ]            |
+--------------------------------+
```

- **Description:** In the Lobby, provide a dropdown or carousel of preset modes (Bedtime, Movie, Gaming, Custom).  Selecting a mode pre-fills timer settings and optionally toggles checks (e.g. “Movie” disables dimming).  
- **Acceptance:** Ensure selecting each mode updates the timer UI appropriately.  For example, Bedtime might set a shorter timer and turn on “blue-light filter” (if implemented), while Gaming sets a longer default.  

## 8. Onboarding Wizard (Onboarding)  

```
+-------------------------------------+
| **Welcome to Lights Out!**          |
| A quick setup will help you start.  |
|                                     |
| [Step 1: Choose Your Habit]         |
| • “Bedtime Sleep”: Aim for 8h/night |
| • “Weekly Gamer”: Off by midnight   |
| • Custom: [Set schedule manually]   |
|                                     |
| [Next →]                            |
+-------------------------------------+
```

- **Description:** The first time the app runs, walk the user through key settings: setting a nightly goal, choosing default action (sleep/shutdown/etc.), and explaining DryRun/Test mode.  This ensures users start with safe defaults.  
- **Acceptance:** On a fresh install or after clearing settings, the wizard should appear.  Skipping it leaves defaults (e.g. countdown 1h to shutdown).  Test that all wizard choices persist correctly.  

# Feasibility Matrix & Roadmap  

| **Idea**               | **Impact** | **Effort** | **Risk**        |
|------------------------|:----------:|:----------:|:---------------:|
| Sleep Clearance Panel  | High       | Medium     | Low             |
| Cancel Puzzle          | High       | Low        | Low (UX annoyance) |
| Morning Proof          | Medium     | Medium     | Low             |
| Steam Overlay Timer    | Medium     | Medium     | Low             |
| Download-Aware Delay   | Medium     | Medium     | Low             |
| Browser/Media Guard    | Medium     | High       | Med (permissions) |
| Ritual Presets         | Low        | Low        | Low             |
| Onboarding Wizard      | Medium     | Low        | Low             |
| Smart-Home Mode        | Low        | High       | Med (API keys)  |
| Gamification/Avatar    | Low        | Low        | Low             |
| Accessibility (ARIA)   | High       | Medium     | Low             |
| Monetization (themes)  | Low        | Low        | Low             |

> **Impact:** user value (High/Medium/Low); **Effort:** dev time (1–2wks / 2–4wks / 1+ mo); **Risk:** safety/privacy (Low/Med/High).

**3-Month Roadmap:** 

- **MVP (Month 1):** Implement core safety UI and lint tests.  Deliver Sleep Clearance panel, countdown UI, and Cancel confirmation.  Add `Get-PowerRequestBlockers` integration.  Write `Test-AgentSafety.ps1`.  *Tests:* CI-local verifies no auto-launch, Sleep Clearance state correctly reads power blockers; manual test of color-coded countdown.  

- **v1 (Month 2):** Add Morning Proof report, preset modes, onboarding wizard, and basic Steam overlay integration (use Steam overlay calls for timer display).  Introduce initial analytics (session logs).  *Tests:* Scripted “fake sessions” verify stats, Steam overlay test app.  Continue running CI-local for safety and new lint rules.  

- **v2 (Month 3):** Implement browser/media guard (if feasible), download-aware shutdown, and possibly simple smart-home (Hue) support.  Polish UX (graphics, accessibility).  Consider monetization UI (premium toggle).  *Milestones:* 
   - **End Month2:** Sleep Clearance and Cancel fully functional (CI passing).  
   - **Mid Month3:** Morning Proof active, presets, onboarding complete.  
   - **End Month3:** Advanced integrations (Steam/downloads, optionally Hue).  
   - **Testing:** Extensive manual tests for each new feature; use `Test-SleepTimer.ps1` to simulate countdowns; ensure no releases without DryRun by lint.  

This roadmap balances quick wins (safety-critical UI) with stretch goals.  MVP focuses on trust (clearance, no accidental shutdown).  v1 builds user engagement (reports, modes) while solidifying platform integration.  v2 adds “moat” features like streaming integration and smart devices.  

Overall, these enhancements make Lights Out a *sleep and bedtime control hub* rather than a plain timer. The novel UI elements (clearance panel, proof dashboard, anti-cancel rituals) set it apart from generic shutdown timers, aligning with users’ real-world sleep needs and Steam-centric gaming habits.