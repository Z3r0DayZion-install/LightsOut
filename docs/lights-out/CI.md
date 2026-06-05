# Lights Out CI

CI validates and builds Lights Out **without launching real shutdown**. All automated runs treat power as blocked.

---

## Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| **Lights Out CI** | [`.github/workflows/lights-out-ci.yml`](../../.github/workflows/lights-out-ci.yml) | Docs lint, safety gates, safe build (installs ps2exe) |
| **Lights Out Release CI** | [`.github/workflows/sleep-timer-ci.yml`](../../.github/workflows/sleep-timer-ci.yml) | Full release build, installer, publish |

### Lights Out CI triggers

- `push` to `main` / `master`
- `pull_request`
- `workflow_dispatch`

### What runs

1. `Test-AgentSafety.ps1` — static lint for unsafe `SleepTimer.exe` launches
2. `Test-SleepTimer.ps1` — parse gates, classic-ui-lock, logic tests
3. `Test-Docs.ps1` — doc links, required files, doc safety lint
4. `CI-Local.ps1` — full safe build (no GUI, no deploy `-Launch`)
5. Unsafe-launch grep across workflows and scripts
6. Upload `ci-artifacts/` if present

---

## What must never happen in CI

| Forbidden | Why |
|-----------|-----|
| Launch `SleepTimer.exe` without `-DryRun` / Demo | Could trigger real shutdown |
| `Deploy-SleepTimer-Desktop.ps1 -Launch` | Auto-starts live timer |
| `shutdown /s`, `Stop-Computer`, etc. | Real power outside app gates |
| Lower 60s minimum for convenience | Safety regression |
| Change `Do-PowerAction` / `Test-NoPowerAction` | Power gate bypass |

---

## Required environment variables

```text
SLEEPTIMER_CI=1
SLEEPTIMER_DRY_RUN=1
```

Set in GitHub Actions `env:` block and local CI scripts. `Test-NoPowerAction` consults these (and `-DryRun` / `-Demo` flags).

---

## Local CI equivalent

```powershell
$env:SLEEPTIMER_CI = '1'
$env:SLEEPTIMER_DRY_RUN = '1'
.\scripts\Test-AgentSafety.ps1
.\scripts\Test-SleepTimer.ps1
.\scripts\Test-Docs.ps1
.\scripts\CI-Local.ps1
```

---

## Artifact behavior

| Path | Contents |
|------|----------|
| `ci-artifacts\local-{timestamp}\` | Per-run build outputs |
| `ci-artifacts\latest\` | Symlink/copy of most recent run |
| `dist\Release\` | Portable `SleepTimer.exe`, SHA256, BUILD_INFO |

Artifacts include `CI_REPORT.txt` confirming no GUI launch.

GitHub Actions uploads `ci-artifacts/` from Lights Out CI workflow (retention: 14 days).

---

## Failure triage

| Failure | Likely cause | Fix |
|---------|--------------|-----|
| `Test-AgentSafety` | Script/doc launches exe without DryRun | Add `-DryRun` or `USER_LAUNCHER` marker |
| `Test-Docs` | Missing doc file or bad README link | Create doc or fix link |
| `classic-ui-lock` | Theme/launcher regression | Restore Classic default unless `-SteamUi` |
| `parse:SleepTimer-Tonight.ps1` | PowerShell syntax error | Fix source parse error |
| `ps2exe` not found | Module missing on runner | `Install-Module ps2exe` (release workflow) |
| Inno Setup missing | Local only — CI skips installer | Install Inno Setup locally or use `-SkipInstaller` |

---

## Permissions

Workflows use least privilege:

```yaml
permissions:
  contents: read
```

Release publish job escalates to `contents: write` only when attaching GitHub release assets.

---

## Related

- [`SAFETY-MODEL.md`](SAFETY-MODEL.md)
- [`RELEASE-CHECKLIST.md`](RELEASE-CHECKLIST.md)
- [`../agent-handbook/07-SAFETY-AND-TESTING.md`](../agent-handbook/07-SAFETY-AND-TESTING.md)
