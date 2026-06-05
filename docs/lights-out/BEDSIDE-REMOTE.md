# Bedside Remote™ — design

**Status:** Spec only (not implemented)  
**Product:** Lights Out PC (`SleepTimer-Tonight.ps1`)  
**Optional action label:** Remote Unplug  
**Pairs with:** Sleep Clearance, Morning Proof, Night Lobby session loop

---

## Product purpose

Bedside Remote lets the user **start, pause, resume, snooze, cancel, and check status** from a phone while in bed — without cloud accounts or leaving the keyboard path as the only control surface.

| Problem | Bedside Remote |
|---------|----------------|
| Timer started at desk; user already in bed | Phone control on same LAN |
| Getting up to snooze/cancel | Snooze / cancel from phone |
| Another cloud sleep app | Local-only; token + QR pairing |

**Positioning:** Optional **local LAN utility** — not core timer value. Lights Out must work fully with remote disabled.

---

## Recommended model (v1)

Local-only web remote:

- PC app runs a **tiny local HTTP server** (loopback or LAN — see security).
- User scans **QR code** from SET page.
- Phone opens LAN page with embedded token.
- **No cloud. No account. No public internet exposure by default.**

Example URL:

```text
http://192.168.x.x:38741/?token=8F3K-91QX
```

---

## Phone UI v1

```text
LIGHTS OUT PC
Bedside Remote

Status: Lobby
Tonight: 24 min · Shutdown
Clearance: Clear

[START TONIGHT]

[SNOOZE +5]  [PAUSE]
[CANCEL SESSION]
[OPEN CINEMA]
```

When Morning Proof showing:

```text
Last run: Mission complete
[DISMISS PROOF]
```

Dry-run mode must be visible on phone status (`Testing — no shutdown`).

---

## Desktop UI placement

### SET page / Options

```text
Bedside Remote
[ ] Enable Remote
[ Show QR Code ]
Status: Local only · Paired device allowed
[ Reset Pairing ]
```

### Header pill (optional)

```text
REMOTE OFF | REMOTE READY | PHONE CONNECTED
```

---

## API shape (v1)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/` | Mobile UI (HTML) |
| GET | `/api/status` | JSON state |
| POST | `/api/start` | Same path as desktop PLAY |
| POST | `/api/pause` | Existing pause |
| POST | `/api/resume` | Existing resume |
| POST | `/api/snooze` | Existing snooze (+300/+600 per body) |
| POST | `/api/cancel` | Existing cancel / emergency-safe cancel |
| POST | `/api/cinema` | Open Cinema if session active |
| POST | `/api/dismiss-proof` | Write `MorningProofLastSeen` |

All POST endpoints require valid token (header `X-LightsOut-Token` or query param — prefer header).

### Status payload (conceptual)

```json
{
  "phase": "lobby|session|paused|last_light|morning_proof",
  "card": "weeknight",
  "action": "Shutdown",
  "remainingSeconds": 1420,
  "clearanceStatus": "clear|warn",
  "dryRun": false,
  "remoteEnabled": true
}
```

---

## Command routing (critical)

Remote commands **must** call existing safe desktop paths:

| Remote command | Internal behavior |
|----------------|-------------------|
| start | Same as PLAY — `Invoke-StartTimer` + gates |
| pause | Existing pause path |
| resume | Existing resume path |
| snooze | Existing snooze + `Test-AllowSnooze` |
| cancel | Existing cancel; never block emergency semantics |
| cinema | `Show-BigPicture` when allowed |
| dismiss proof | `Dismiss-MorningProof` |

**Never** create a remote-only power action path. **Never** call `Do-PowerAction` from HTTP handlers.

---

## Settings

| Key | Default | Meaning |
|-----|---------|---------|
| `RemoteEnabled` | `false` | Master switch |
| `RemotePort` | `38741` | Local HTTP port |
| `RemotePairingTokenHash` | `''` | Hashed token (not plaintext in settings) |
| `RemoteAllowLan` | `true` | When false, bind localhost only |
| `RemoteRequireToken` | `true` | Reject requests without token |
| `RemoteLastPairedAt` | `''` | ISO timestamp of last QR show/regenerate |

Token generation: show once on QR display; store hash only (SHA256 or similar).

---

## Security / safety rules

1. **Token required** for every mutating request.
2. **Reset / revoke token** in SET clears old phone sessions.
3. **Bind localhost by default**; LAN only when `RemoteAllowLan` explicitly enabled.
4. **No UPnP**, no port forwarding helpers, **no cloud relay** in v1.
5. Remote start follows **same PLAY path** (Clearance does not block; existing warns apply).
6. Remote cancel **always allowed** (same as desktop cancel semantics).
7. Remote **cannot** call `Do-PowerAction` directly.
8. Remote **cannot** bypass `Test-NoPowerAction`.
9. Remote **cannot** bypass final confirm at timer zero.
10. Remote **cannot** lower 60s minimum.
11. **No public internet exposure by default** — document that user must not port-forward.
12. Rate-limit POST endpoints lightly (abuse on LAN).

---

## Architecture notes

Prefer implementation in `modules/LightsOut.Remote.psm1`:

- `Start-BedsideRemoteServer` / `Stop-BedsideRemoteServer`
- `Get-BedsideRemoteStatus`
- `Invoke-BedsideRemoteCommand` — dispatches to main-script scriptblocks registered at startup

HTTP server options (implementation choice):

- `System.Net.HttpListener` in PowerShell (no new deps) — preferred for v1.
- Run on UI thread via async/background job with **marshal back to UI thread** for WinForms timer commands.

Main script registers callbacks:

```powershell
Register-BedsideRemoteHandlers @{
    Start = { Invoke-StartTimer ... }
    Pause = { Stop-Timer -Reason pause ... }
    ...
}
```

---

## LuxGrid

Optional status event `remote.connected` — v1.1 only. Not required for remote v1.

---

## v1 scope vs later

### v1

| Item | In |
|------|-----|
| Enable + QR + token | Yes |
| Status + start/pause/resume/snooze/cancel | Yes |
| Cinema open | Yes |
| Dismiss Morning Proof | Yes |
| Localhost-only default | Yes |
| LAN when opted in | Yes |

### v1.1+

- PWA install prompt / home-screen icon
- mDNS discovery (`lightsout.local`) — careful with security
- Per-device tokens
- Remote view of Last Light progress (read-only)
- LuxGrid `remote.connected` pulse

### Out of scope v1

- Cloud relay / account login
- Push notifications off-LAN
- Remote **force shutdown** without final confirm
- Remote disable emergency cancel

---

## Tests needed

### Unit / integration (no real exe launch)

| Test | Assert |
|------|--------|
| Token required | POST without token → 401 |
| Invalid token | 403 |
| Remote disabled | All mutating routes → 503 |
| Start routes to mock PLAY handler | handler invoked once |
| No handler calls Do-PowerAction | static grep / mock |
| Status JSON schema | required fields present |
| Token hash storage | plaintext not in settings file |

Use `HttpListener` on ephemeral port in tests; no GUI.

### Static

| Test | Assert |
|------|--------|
| `Test-AgentSafety.ps1` | No unsafe remote launch patterns |
| Remote module | No direct `Do-PowerAction` string in HTTP handlers |

---

## Implementation sketch (when approved)

| Step | File | Change |
|------|------|--------|
| 1 | `modules/LightsOut.Remote.psm1` | Server + routing |
| 2 | `SleepTimer-Tonight.ps1` | Register handlers; SET UI; QR |
| 3 | `static/remote/` or embedded HTML | Phone UI |
| 4 | `Test-BedsideRemote-Logic.ps1` | Token + routing tests |
| 5 | `07-SAFETY-AND-TESTING.md` | Remote safety section |

---

## Definition of done (v1)

- [ ] Remote off by default; enable in SET.
- [ ] QR pairs phone with token; reset revokes.
- [ ] All commands use desktop safe paths.
- [ ] Final confirm and power gates unchanged at timer end.
- [ ] Dry-run visible on phone.
- [ ] No cloud dependency.
- [ ] Validation scripts pass; remote tests do not launch exe.

---

## Related docs

| Doc | Use |
|-----|-----|
| [`AGENT-IDEA-BRIEF.md`](AGENT-IDEA-BRIEF.md) | Build order (after Tonight Cards) |
| [`../agent-handbook/02-ARCHITECTURE.md`](../agent-handbook/02-ARCHITECTURE.md) | Module boundaries |
| [`../agent-handbook/07-SAFETY-AND-TESTING.md`](../agent-handbook/07-SAFETY-AND-TESTING.md) | Power gates |

---

## One-line summary

**Bedside Remote = optional local HTTP + QR token phone UI that dispatches to existing PLAY/pause/snooze/cancel paths — never a separate shutdown pipeline.**
