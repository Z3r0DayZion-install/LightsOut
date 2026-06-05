# Demo Mode v1

**Status:** Shipped  
**Module:** `modules/LightsOut.Demo.psm1`

Demo Mode is a safe marketing and manual-test path. It shows the full bedtime loop without waiting overnight or risking shutdown.

## CLI

```powershell
SleepTimer.exe -Demo -NoAutoStart
SleepTimer.exe -Demo -DryRun -Seconds 90 -Start
SleepTimer.exe -Demo -LastLightSequence ExitTheGrid
```

| Switch | Behavior |
|--------|----------|
| `-Demo` | Enables Demo Mode; **implies `-DryRun`** |
| `-NoAutoStart` | Default in Demo unless `-Start` or duration args imply a run |
| `-Seconds` / `-Minutes` | Sets countdown length (DryRun min timer still applies — 3s floor) |
| `-Start` | Auto-starts session for short visual demo |
| `-LastLightSequence` | Override Last Light sequence for demo run |

Environment: `SLEEPTIMER_DEMO=1` (also implies DryRun).

## Safety (unchanged gates)

- `Test-NoPowerAction` and `Do-PowerAction` are **not modified**.
- Demo forces `$script:DryRun = $true`, so power actions remain blocked.
- `Write-AuditLog` and `Save-Settings` **no-op** in Demo Mode — no pollution of real log or settings.
- Sample Morning Proof uses `EventKey = demo-morning-proof`; dismiss does not write `MorningProofLastSeen`.

## Lobby experience

```text
DEMO MODE banner
Trust badges: DEMO MODE · DRY-RUN SAFE · LOCAL ONLY · …
Tonight Preview (Clearance: Clear · Ending · Proof)
Tonight Cards on LIB
Sample Morning Proof (dismiss to return to Tonight Preview)
Ring tag: DEMO
```

Demo is **not** the default desktop launcher. Live bedtime use: `Lights Out.bat` → `-ClassicUi -NoAutoStart`.

## Full loop (with `-Start`)

```text
Night Lobby → Sleep Clearance → PLAY → Session → Last Light → Power gates → Morning Proof
```

All terminal paths log as dry-run when the session completes (no `actions.log` writes in Demo).

## Related

| Doc | Use |
|-----|-----|
| [`COHESION-ROADMAP.md`](COHESION-ROADMAP.md) | Priority + cohesion phase |
| [`AGENT-QUICKSTART.md`](../agent-handbook/AGENT-QUICKSTART.md) | Safe launch examples |
