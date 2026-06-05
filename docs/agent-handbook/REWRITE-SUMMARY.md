# Lights Out handbook rewrite - summary
## What changed
- Converted the set from reference notes into an agent command system.
- Made canonical boundaries louder: `SleepTimer-Tonight.ps1`, `modules\LightsOut.*.psm1`, `Desktop\Lights Out\SleepTimer.exe`.
- Added stricter safety language around `-DryRun`, `SLEEPTIMER_CI=1`, deploy without `-Launch`, and production 60-second minimum.
- Strengthened product positioning: Lights Out is PC bedtime control, not just a shutdown timer.
- Added a roadmap direction around Sleep Clearance, next-morning proof, better Tonight modes, and trust/distribution.
- Added `AGENT-QUICKSTART.md` for fast code-agent handoff.

## Files rewritten
- `00-README.md`
- `01-PRODUCT-VISION.md`
- `02-ARCHITECTURE.md`
- `03-UI-AND-THEMES.md`
- `04-SETTINGS-AND-DATA.md`
- `05-FEATURES-SHIPPED.md`
- `06-FEATURES-PLANNED.md`
- `07-SAFETY-AND-TESTING.md`
- `08-DEPLOY-AND-BUILD.md`
- `09-MODULES-REFERENCE.md`
- `10-CLI-AND-AUTOMATION.md`
- `11-LUXGRID-INTEGRATION.md`
- `12-TROUBLESHOOTING.md`
- `13-GLOSSARY.md`
- `AGENT-QUICKSTART.md`
