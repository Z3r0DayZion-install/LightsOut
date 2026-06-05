# Lights Out — GitHub export

This folder is a **standalone product bundle** for publishing to a dedicated repo (e.g. `KickA/LightsOut`).

## Quick publish

```powershell
cd windsurf-project
.\scripts\Prepare-LightsOut-GitHub.ps1
# → dist\LightsOut-GitHub\  (ready to git init + push)
```

Or use the monorepo README at `../README.md` on ForgeCore_OS.

## Contents after prepare script

- `README.md` — sales page
- `LICENSE`, `CHANGELOG.md`, `VERSION`
- `docs/lights-out/` — banner, logo, icons
- `packaging/winget/` — WinGet manifest
- `.github/` — issue templates

## Release

```powershell
.\scripts\Publish-GitHubRelease.ps1
```
