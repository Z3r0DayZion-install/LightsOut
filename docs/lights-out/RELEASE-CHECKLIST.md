# Lights Out release checklist

Use this RC checklist before shipping a new version. **No real shutdown during QA.**

Version file: [`VERSION`](../../VERSION)  
Changelog: [`CHANGELOG.md`](../../CHANGELOG.md)

---

## 1. Static tests

```powershell
.\scripts\Test-AgentSafety.ps1
.\scripts\Test-SleepTimer.ps1
.\scripts\Test-Docs.ps1
```

All must pass with **0 failures**.

---

## 2. CI

```powershell
.\scripts\CI-Local.ps1
```

Confirm:

- [ ] `ci-artifacts\latest\CI_REPORT.txt` shows success
- [ ] `dist\Release\SleepTimer.exe` built
- [ ] `dist\Release\SHA256.txt` captured
- [ ] No GUI launch during CI
- [ ] No real power action possible (`SLEEPTIMER_CI=1`)

GitHub: confirm [`.github/workflows/lights-out-ci.yml`](../../.github/workflows/lights-out-ci.yml) and [`sleep-timer-ci.yml`](../../.github/workflows/sleep-timer-ci.yml) green.

---

## 3. Deploy

```powershell
.\scripts\Deploy-SleepTimer-Desktop.ps1
```

Confirm:

- [ ] `Desktop\Lights Out\SleepTimer.exe` updated
- [ ] `modules\LightsOut.*.psm1` copied
- [ ] `Lights Out.bat` → `-ClassicUi -NoAutoStart` (live)
- [ ] `Lights Out Premium Preview.bat` → `-SteamUi -DryRun -NoAutoStart`
- [ ] `Desktop\Lights Out.lnk` → Classic live
- [ ] Deploy did **not** use `-Launch`

---

## 4. Desktop smoke (manual — DryRun only)

```powershell
Get-Process SleepTimer -ErrorAction SilentlyContinue | Stop-Process -Force
```

### Classic dry-run

```powershell
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-ClassicUi','-DryRun','-NoAutoStart'
```

- [ ] Window title: **Sleep Timer** (Classic)
- [ ] Timer amount visible first
- [ ] Quick chips include 23m
- [ ] START shows `START · N min`
- [ ] DryRun banner visible

### Steam dry-run

```powershell
Start-Process "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ArgumentList '-SteamUi','-DryRun','-NoAutoStart'
```

- [ ] Window title: **Lights Out** (Steam)
- [ ] Wider dark layout (~480px)
- [ ] LIB/SCH/SET sidebar or equivalent
- [ ] Tonight Preview / trust badges visible
- [ ] **Not** the simple Classic timer layout

### Premium Preview launcher

Double-click `Desktop\Lights Out Premium Preview.bat`:

- [ ] Opens Steam/Night Lobby (not Classic)
- [ ] DryRun active (no real power)

---

## 5. Safety verification

- [ ] `Test-NoPowerAction` unchanged
- [ ] `Do-PowerAction` unchanged
- [ ] 60s minimum still enforced in production
- [ ] `Ctrl+Shift+S` emergency cancel works in DryRun
- [ ] Final confirm dialog appears at timer zero in DryRun
- [ ] **No real shutdown** occurred during any QA step

---

## 6. Docs sync

- [ ] [`VERSION`](../../VERSION) matches [`CHANGELOG.md`](../../CHANGELOG.md) header
- [ ] [`README.md`](../../README.md) version/roadmap current
- [ ] [`PRODUCT.md`](../../PRODUCT.md) version current
- [ ] Installer `.iss` version synced (if shipping installer)
- [ ] WinGet manifest synced (if publishing)

---

## 7. SHA256 capture

```powershell
Get-FileHash "dist\Release\SleepTimer.exe" -Algorithm SHA256
```

- [ ] Hash recorded in `dist\Release\SHA256.txt`
- [ ] Hash attached to GitHub release notes

---

## 8. Live bedtime (human only — after QA)

Only after all DryRun checks pass:

```powershell
& "$env:USERPROFILE\Desktop\Lights Out\SleepTimer.exe" -ClassicUi -NoAutoStart
```

Real shutdown testing is **one human run** — never automated.

---

## Related

- [`SAFETY-MODEL.md`](SAFETY-MODEL.md)
- [`CI.md`](CI.md)
- [`RC-LOCKED.md`](RC-LOCKED.md)
