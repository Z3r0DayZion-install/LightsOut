# LuxGrid™ Build Spec — Real RGB Zone Engine

## Mission

Build **LuxGrid™**, a local-first Windows RGB dashboard engine that turns keyboard/mouse RGB zones into live system signals.

This is NOT just a sleep timer feature.

The sleep timer is only the first module.

The main product is:

> LuxGrid™ — turn your keyboard, mouse, and RGB devices into a live signal grid.

Examples:
- Arrow keys = CPU temperature
- QWERTY row = timer countdown
- F-keys = GPU temperature
- Number row = RAM usage
- Mouse = highest warning state
- WASD = active mode / gaming status
- Full keyboard = sleep fade-out ritual

## Hard Rule

Do not fake RGB support.

The first working milestone must prove real hardware control through OpenRGB or a clearly logged simulator fallback.

Required proof:
1. Detect OpenRGB SDK server.
2. Connect to local RGB service.
3. List detected RGB devices.
4. Select a keyboard or mouse device.
5. Change at least one real LED/color.
6. Save a device map.
7. Replay a saved profile.
8. Show logs proving connection, device count, selected device, and color update result.

If real hardware is unavailable, build a simulator mode, but label it clearly as simulator mode.

No fake claims.

---

# Product Names

## Main App

**LuxGrid Studio™**

The visual app where the user selects keyboard/mouse zones, assigns data sources, chooses effects, and previews RGB output.

## Engine

**LuxGrid Core™**

The backend RGB controller that talks to OpenRGB, manages device maps, profiles, effects, and event subscriptions.

## SDK

**LuxGrid SDK™**

Shared event schema and local event bridge so other apps can send data into LuxGrid.

## First Integration

**Snoozurp Bridge™**

A small integration that sends sleep timer countdown events into LuxGrid.

---

# Recommended Repo Structure

Start as a monorepo for speed and internal consistency:

```txt
luxgrid/
├── README.md
├── package.json
├── pnpm-workspace.yaml
├── apps/
│   └── luxgrid-studio/
│       ├── package.json
│       ├── src/
│       │   ├── main/
│       │   ├── renderer/
│       │   └── preload/
│       └── README.md
├── packages/
│   ├── luxgrid-core/
│   │   ├── package.json
│   │   ├── src/
│   │   │   ├── openrgb/
│   │   │   ├── devices/
│   │   │   ├── zones/
│   │   │   ├── effects/
│   │   │   ├── profiles/
│   │   │   ├── metrics/
│   │   │   └── index.ts
│   │   └── README.md
│   ├── luxgrid-sdk/
│   │   ├── package.json
│   │   ├── src/
│   │   │   ├── events/
│   │   │   ├── schemas/
│   │   │   ├── bridge/
│   │   │   └── index.ts
│   │   └── README.md
│   └── luxgrid-simulator/
│       ├── package.json
│       ├── src/
│       └── README.md
├── integrations/
│   └── snoozurp-bridge/
│       ├── package.json
│       ├── src/
│       └── README.md
├── docs/
│   ├── DEVICE_PROOF.md
│   ├── EVENT_SCHEMA.md
│   ├── RGB_ZONE_MODEL.md
│   ├── OPENRGB_SETUP.md
│   └── MVP_CHECKLIST.md
└── validation-artifacts/
    └── README.md
```

---

# Stack

Use:

```txt
Runtime: Node.js 22+
Desktop: Electron + Vite + React + TypeScript
UI: React + Tailwind
State: Zustand or simple local state
Storage: JSON files under %LOCALAPPDATA%/LuxGrid
Hardware: OpenRGB SDK server first
Metrics: Windows local system metrics first
Testing: Vitest for units, Playwright for UI smoke tests
```

Avoid overengineering.

This needs to become usable fast.

---

# Local Data Paths

Use this Windows app-data structure:

```txt
%LOCALAPPDATA%/LuxGrid/
├── settings.json
├── devices.json
├── profiles/
│   ├── default.json
│   ├── thermal-hud.json
│   ├── sleep-ritual.json
│   └── gaming-hud.json
├── maps/
│   └── keyboard-map.json
├── logs/
│   ├── app.log
│   ├── openrgb.log
│   └── events.log
└── validation/
    ├── latest-device-proof.json
    └── latest-profile-proof.json
```

---

# MVP Priority Order

## Phase 1 — Real OpenRGB Connection

Build this before the fancy UI.

Create package:

```txt
packages/luxgrid-core/src/openrgb/
```

Required files:

```txt
OpenRgbClient.ts
OpenRgbTypes.ts
OpenRgbConnection.ts
OpenRgbDeviceService.ts
```

Required functions:

```ts
connectOpenRgb(options): Promise<OpenRgbConnectionResult>
disconnectOpenRgb(): Promise<void>
getOpenRgbStatus(): Promise<OpenRgbStatus>
listRgbDevices(): Promise<RgbDevice[]>
setDeviceColor(deviceId, color): Promise<RgbCommandResult>
setLedColor(deviceId, ledIndex, color): Promise<RgbCommandResult>
setZoneColor(deviceId, zoneId, color): Promise<RgbCommandResult>
```

Connection config:

```ts
type OpenRgbConfig = {
  host: string; // default 127.0.0.1
  port: number; // default 6742, but user-editable
  clientName: string; // LuxGrid
  timeoutMs: number;
};
```

Must include:

```txt
- connection timeout handling
- reconnect button support
- device discovery
- error logging
- simulator fallback
- no crash if OpenRGB is not running
```

Output proof file:

```txt
%LOCALAPPDATA%/LuxGrid/validation/latest-device-proof.json
```

Proof JSON:

```json
{
  "timestamp": "ISO_DATE",
  "mode": "openrgb | simulator",
  "connected": true,
  "host": "127.0.0.1",
  "port": 6742,
  "deviceCount": 2,
  "devices": [
    {
      "id": "device-0",
      "name": "Keyboard Name",
      "type": "keyboard",
      "ledCount": 104,
      "zoneCount": 1
    }
  ],
  "testCommand": {
    "target": "device-0",
    "color": "#00ffcc",
    "result": "success"
  }
}
```

---

# Phase 2 — Simulator Mode

Build simulator mode in parallel so UI development is not blocked by hardware.

Create:

```txt
packages/luxgrid-simulator/
```

Simulator must expose fake devices:

```txt
- Full-size keyboard
- TKL keyboard
- Mouse
- Light strip
```

Keyboard simulator must render a visual keyboard grid.

Each key must support:

* key label
* row
* column
* led index
* current color
* selected state
* assigned zone id

This simulator is also used for UI preview.

---

# Phase 3 — RGB Zone Model

Create a simple, strict zone model.

```ts
type LuxGridZone = {
  id: string;
  name: string;
  deviceId: string;
  keys: LuxGridKeyTarget[];
  source: LuxGridSource;
  effect: LuxGridEffect;
  palette: LuxGridPalette;
  enabled: boolean;
  priority: number;
};
```

Key target:

```ts
type LuxGridKeyTarget = {
  label: string;       // "Q", "W", "ArrowUp"
  ledIndex?: number;   // hardware LED index if known
  row?: number;
  column?: number;
};
```

Sources:

```ts
type LuxGridSource =
  | { type: "static"; color: string }
  | { type: "cpu_temp"; minC: number; maxC: number }
  | { type: "gpu_temp"; minC: number; maxC: number }
  | { type: "cpu_usage"; min: number; max: number }
  | { type: "memory_usage"; min: number; max: number }
  | { type: "battery"; min: number; max: number }
  | { type: "timer_progress"; eventChannel: string }
  | { type: "timer_remaining"; eventChannel: string }
  | { type: "audio_level" }
  | { type: "network_activity" }
  | { type: "custom_event"; eventName: string };
```

Effects:

```ts
type LuxGridEffect =
  | { type: "solid" }
  | { type: "gradient" }
  | { type: "pulse"; speedMs: number }
  | { type: "blink"; speedMs: number }
  | { type: "breath"; speedMs: number }
  | { type: "progress_fill"; direction: "left_to_right" | "right_to_left" | "center_out" }
  | { type: "warning_flash"; threshold: number };
```

Palettes:

```ts
type LuxGridPalette =
  | { type: "heat"; cool: string; normal: string; warm: string; hot: string; critical: string }
  | { type: "cyber"; primary: string; secondary: string; danger: string }
  | { type: "night"; start: string; end: string }
  | { type: "custom"; stops: { value: number; color: string }[] };
```

---

# Phase 4 — Built-In Profiles

Ship with these profiles:

## Thermal HUD

```txt
Arrow keys = CPU temp
F1-F12 = GPU temp
Number row = memory usage
Mouse = highest alert state
```

## Sleep Ritual

```txt
QWERTY row = timer countdown
Entire keyboard dims over time
Final 2 minutes = slow pulse
Final 30 seconds = red warning pulse
Complete = fade to black
```

## Gaming HUD

```txt
WASD = static accent
Arrow keys = CPU temp
F-keys = GPU temp
Mouse = system alert
```

## NeuralOS Status

```txt
Esc = global alert state
F1-F4 = active module status
F5-F8 = background tasks
F9-F12 = network/download state
```

## Minimal Night Mode

```txt
All keys dim
Only arrows show CPU temp
Mouse stays low brightness
```

---

# Phase 5 — System Metrics

Create:

```txt
packages/luxgrid-core/src/metrics/
```

Required:

```ts
getCpuUsage(): Promise<number>
getMemoryUsage(): Promise<number>
getBatteryStatus(): Promise<BatteryStatus>
getCpuTemperature(): Promise<MetricResult<number>>
getGpuTemperature(): Promise<MetricResult<number>>
```

Important:

CPU/GPU temperature may not always be available on Windows without helper tools.

Implement metric result like this:

```ts
type MetricResult<T> = {
  available: boolean;
  value?: T;
  source?: string;
  error?: string;
};
```

If temperature is unavailable:

* do not crash
* show "metric unavailable"
* allow simulator value
* allow manual test slider in Studio

---

# Phase 6 — Event Bridge / SDK

Create:

```txt
packages/luxgrid-sdk/
```

Purpose:

Allow Snoozurp, NeuralOS, NeuralShell, and future apps to send events into LuxGrid.

Use local JSON event folder first for simplicity.

Event folder:

```txt
%LOCALAPPDATA%/LuxGrid/events/inbox/
```

Processed folder:

```txt
%LOCALAPPDATA%/LuxGrid/events/processed/
```

Event schema:

```ts
type LuxGridEvent = {
  id: string;
  timestamp: string;
  sourceApp: string;
  eventName: string;
  channel: string;
  payload: Record<string, unknown>;
};
```

Timer event examples:

```json
{
  "id": "evt_001",
  "timestamp": "2026-05-23T22:30:00.000Z",
  "sourceApp": "Snoozurp",
  "eventName": "timer.tick",
  "channel": "sleep",
  "payload": {
    "timerName": "Sleep Ritual",
    "totalSeconds": 1800,
    "remainingSeconds": 900,
    "percentRemaining": 50,
    "phase": "countdown"
  }
}
```

Warning event:

```json
{
  "id": "evt_002",
  "timestamp": "2026-05-23T22:58:00.000Z",
  "sourceApp": "Snoozurp",
  "eventName": "timer.warning",
  "channel": "sleep",
  "payload": {
    "remainingSeconds": 120,
    "severity": "warning"
  }
}
```

Complete event:

```json
{
  "id": "evt_003",
  "timestamp": "2026-05-23T23:00:00.000Z",
  "sourceApp": "Snoozurp",
  "eventName": "timer.completed",
  "channel": "sleep",
  "payload": {
    "result": "completed"
  }
}
```

---

# Phase 7 — LuxGrid Studio UI

Build a real UI after hardware/simulator foundations exist.

Main layout:

```txt
┌─────────────────────────────────────────────────────────────┐
│ LuxGrid Studio                    OpenRGB: Connected ●      │
├───────────────┬───────────────────────────────┬─────────────┤
│ Profiles      │ Keyboard / Device Grid         │ Zone Editor │
│               │                               │             │
│ Thermal HUD   │ [visual keyboard layout]       │ Zone Name   │
│ Sleep Ritual  │                               │ Source      │
│ Gaming HUD    │ Click keys to assign zones     │ Effect      │
│ NeuralOS      │                               │ Palette     │
│               │                               │ Preview     │
├───────────────┴───────────────────────────────┴─────────────┤
│ Logs / Proof / Event Monitor                                 │
└─────────────────────────────────────────────────────────────┘
```

UI requirements:

```txt
- Dark premium NeuralOS-style UI
- Device status top-right
- OpenRGB connection panel
- Device picker
- Visual keyboard grid
- Mouse device panel
- Zone list
- Add/edit/delete zone
- Click keys to assign to selected zone
- Source selector
- Effect selector
- Palette selector
- Live preview button
- Save profile
- Load profile
- Export profile
- Import profile
- Event monitor
- Log viewer
- Hardware proof button
```

Do not overdesign first.

Make it functional.

---

# Phase 8 — Snoozurp Bridge

Create:

```txt
integrations/snoozurp-bridge/
```

This is a small bridge that sends timer events into LuxGrid.

Required CLI:

```bash
node snoozurp-bridge.js start --name "Sleep Ritual" --seconds 1800
node snoozurp-bridge.js tick --remaining 900 --total 1800
node snoozurp-bridge.js warning --remaining 120
node snoozurp-bridge.js cancel
node snoozurp-bridge.js complete
```

The bridge writes LuxGrid events into:

```txt
%LOCALAPPDATA%/LuxGrid/events/inbox/
```

This proves LuxGrid works without needing the full sleep timer app finished.

---

# Phase 9 — Validation Tasks

Create a validation command:

```bash
pnpm validate:luxgrid
```

It should produce:

```txt
validation-artifacts/luxgrid-validation-YYYY-MM-DD-HHMM/
├── DEVICE_PROOF.json
├── PROFILE_PROOF.json
├── EVENT_PROOF.json
├── OPENRGB_STATUS.txt
├── UI_SCREENSHOT.png
└── SUMMARY.md
```

Validation checklist:

```txt
[ ] App starts
[ ] OpenRGB connection attempted
[ ] If OpenRGB unavailable, simulator mode activates
[ ] Devices listed
[ ] Device proof JSON created
[ ] Keyboard simulator renders
[ ] Zone can be created
[ ] Keys can be assigned to zone
[ ] Source can be selected
[ ] Effect can be selected
[ ] Profile can be saved
[ ] Profile can be loaded
[ ] Snoozurp timer event can be consumed
[ ] QWERTY zone reacts to timer event
[ ] Arrow zone reacts to CPU/temp test value
[ ] Logs are written
[ ] No fake "connected" state
```

---

# Initial Commands

Use pnpm.

```bash
mkdir luxgrid
cd luxgrid
pnpm init
pnpm add -D typescript tsx vitest eslint prettier
pnpm add electron vite react react-dom zustand zod
pnpm add -D @types/node @types/react @types/react-dom
```

Create workspace:

```yaml
packages:
  - "apps/*"
  - "packages/*"
  - "integrations/*"
```

Root scripts:

```json
{
  "scripts": {
    "dev": "pnpm --filter luxgrid-studio dev",
    "build": "pnpm -r build",
    "test": "pnpm -r test",
    "validate:luxgrid": "tsx scripts/validate-luxgrid.ts"
  }
}
```

---

# First Deliverable

The first deliverable is NOT the final UI.

The first deliverable is:

```txt
LuxGrid Core Hardware Proof MVP
```

Must include:

```txt
1. OpenRGB connection module
2. Simulator fallback
3. Device list command
4. Set color command
5. Proof JSON output
6. Minimal Studio window showing:
   - Connection state
   - Device list
   - Test color button
   - Simulator keyboard
```

Expected command:

```bash
pnpm dev
```

Expected user result:

```txt
LuxGrid Studio opens.
User clicks Connect.
If OpenRGB is running, devices appear.
User clicks Test Color.
Keyboard/mouse changes color.
If no OpenRGB, simulator keyboard changes color and app says SIMULATOR MODE.
```

---

# Quality Bar

This must feel like a real NeuralOS-side product, not a throwaway script.

Required qualities:

```txt
- Local-first
- No cloud dependency
- No fake device support
- Clean logs
- Persistent settings
- Exportable profiles
- Modular packages
- Strict event schemas
- Clear simulator vs hardware mode
- Works as standalone app
- Can later integrate with Snoozurp, NeuralOS, NeuralShell
```

---

# Visual Direction

Style should feel like:

```txt
NeuralOS utility
dark glass panels
cyan/purple/green signal colors
clean grid layout
premium but not bloated
technical dashboard energy
```

Avoid:

```txt
cheap rainbow toy look
fake gamer clutter
overanimated nonsense
unreadable neon overload
```

---

# Final Product Direction

LuxGrid should eventually become:

```txt
A universal RGB signal system for keyboard, mouse, lights, and system events.
```

Not just:

```txt
A sleep timer RGB add-on.
```

Build it like the RGB engine can power:

```txt
- Snoozurp sleep rituals
- NeuralOS alerts
- NeuralShell build status
- CPU/GPU thermal dashboards
- download progress
- music/audio visualizer
- smart-light sync
- gaming HUDs
- focus/ritual modes
```

---

# Agent Execution Rule

Work in this order:

1. Build core OpenRGB connection.
2. Build simulator fallback.
3. Build device proof command.
4. Build minimal Studio UI.
5. Build zone model.
6. Build profile save/load.
7. Build event bridge.
8. Build Snoozurp timer event demo.
9. Build richer UI.

Do not skip to beautiful UI before hardware proof exists.

The product is only real when LuxGrid can change actual RGB hardware or clearly proves simulator-only mode.
