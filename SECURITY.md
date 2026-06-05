# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 5.x     | ✅        |
| 3.9.x   | ✅        |
| < 3.6   | ❌        |

## Reporting a vulnerability

**Lights Out** is a local-only Windows timer — it does not listen on network ports or send telemetry.

If you find a security issue (e.g. power action bypass, unsafe defaults):

1. **Do not** open a public issue for exploitable details
2. Email or DM the maintainer via [GitHub profile](https://github.com/Z3r0DayZion-install)
3. Include: version, Windows build, steps to reproduce, impact

We aim to respond within 7 days.

## Scope

- `SleepTimer-Tonight.ps1` / `SleepTimer.exe` power-action paths
- Dry-run / CI safety gates (`Test-NoPowerAction`)
- Installer behavior

Out of scope: LuxGrid Studio, legacy `SleepTimer.ps1`, third-party OpenRGB.
