# 📁 Proposed Repository Structure

Split the codebase into **4 separate repositories** for better maintainability and modularity.

## Repository Overview

```
GitHub/Organization:
│
├── SleepTimer-Core          (Standalone Timer Engine)
├── RGB-Controller           (Standalone RGB System)
├── SleepTimer-GUI           (Full Windows GUI)
└── SleepTimer-SDK           (Shared Libraries)
```

---

## Repo 1: SleepTimer-Core
**Purpose:** Minimal timer engine - no dependencies

```
sleeptimer-core/
├── src/
│   └── SleepTimer-Core.ps1      (800 lines)
├── tests/
│   └── Core.Tests.ps1
├── docs/
│   ├── API.md                   # Public API reference
│   └── EVENTS.md                # Event system docs
├── examples/
│   ├── Basic-Usage.ps1
│   └── Module-Integration.ps1
├── .github/
│   └── workflows/
│       └── ci.yml
├── README.md
├── LICENSE
└── SleepTimer-Core.psd1         # PowerShell module manifest
```

**Dependencies:** None
**Size:** ~50 KB
**Role:** The "brain" - timer logic only

**Usage:**
```powershell
# Install from PSGallery (future)
Install-Module SleepTimer-Core

# Use as module
Import-Module SleepTimer-Core
Start-TimerEngine -Minutes 30 -Action Shutdown
```

---

## Repo 2: RGB-Controller
**Purpose:** RGB visualization system - works with any data source

```
rgb-controller/
├── src/
│   ├── RGB-Controller.ps1       (600 lines)
│   ├── OpenRGB-Client.ps1     # OpenRGB wrapper
│   ├── Effects/
│   │   ├── Gradient.ps1
│   │   ├── Pulse.ps1
│   │   ├── Wave.ps1
│   │   └── Rainbow.ps1
│   └── Zones/
│       ├── Zone-Keyboard.ps1
│       ├── Zone-Mouse.ps1
│       └── Zone-Strip.ps1
├── tests/
│   └── RGB.Tests.ps1
├── docs/
│   ├── DEVICES.md               # Supported devices
│   ├── EFFECTS.md               # Effect reference
│   └── INTEGRATION.md           # How to integrate
├── examples/
│   ├── Thermal-Display.ps1
│   ├── Audio-Visualizer.ps1
│   └── Custom-Zones.ps1
├── .github/
│   └── workflows/
│       └── ci.yml
├── README.md
├── LICENSE
└── RGB-Controller.psd1
```

**Dependencies:** OpenRGB (external)
**Size:** ~100 KB
**Role:** The "display" - RGB visualization only

**Usage:**
```powershell
# Install from PSGallery (future)
Install-Module RGB-Controller

# Use with SleepTimer-Core events
Import-Module RGB-Controller
Start-RGBWatcher -EventPath "$env:TEMP\SleepTimer\Events"

# Or standalone thermal display
Start-ThermalDisplay
```

---

## Repo 3: SleepTimer-GUI
**Purpose:** Full-featured Windows GUI application

```
sleeptimer-gui/
├── src/
│   ├── SleepTimer-GUI.ps1       (Main GUI)
│   ├── Forms/
│   │   ├── MainForm.ps1
│   │   ├── SettingsDialog.ps1
│   │   ├── ProfileManager.ps1
│   │   └── HistoryViewer.ps1
│   ├── Controls/
│   │   ├── CountdownDisplay.ps1
│   │   ├── CustomButton.ps1
│   │   └── ThemeEngine.ps1
│   └── Resources/
│       ├── Icons/
│       └── Sounds/
├── tests/
│   └── GUI.Tests.ps1
├── docs/
│   ├── USER-GUIDE.md
│   ├── THEMES.md
│   └── TROUBLESHOOTING.md
├── installers/
│   ├── Windows-Installer.ps1
│   └── Build-Script.ps1
├── .github/
│   └── workflows/
│       └── build.yml
├── README.md
├── LICENSE
└── SleepTimer-GUI.psd1
```

**Dependencies:** 
- SleepTimer-Core (submodule or PSGallery)
- RGB-Controller (optional, via PSGallery)
**Size:** ~500 KB
**Role:** The "user interface" - complete Windows app

**Installation:**
```powershell
# Download release
.\Install-SleepTimer.ps1

# Or from Microsoft Store (future)
```

---

## Repo 4: SleepTimer-SDK (Shared Components)
**Purpose:** Common libraries used by all repos

```
sleeptimer-sdk/
├── src/
│   ├── EventSystem/
│   │   ├── EventPublisher.ps1
│   │   ├── EventSubscriber.ps1
│   │   └── EventBus.ps1
│   ├── Utilities/
│   │   ├── TimeFormatting.ps1
│   │   ├── RegistryTools.ps1
│   │   ├── FileOperations.ps1
│   │   └── Logging.ps1
│   └── CommonTypes/
│       ├── TimerState.ps1
│       ├── RGBColor.ps1
│       └── ZoneTypes.ps1
├── tests/
│   └── SDK.Tests.ps1
├── docs/
│   └── SDK-Reference.md
├── README.md
├── LICENSE
└── SleepTimer-SDK.psd1
```

**Dependencies:** None
**Size:** ~30 KB
**Role:** The "shared libraries" - common utilities

**Usage:**
```powershell
# Used internally by other repos
Import-Module SleepTimer-SDK
```

---

## Dependency Graph

```
┌─────────────────────────────────────────────────────────┐
│                  SleepTimer-SDK                        │
│              (Shared Libraries)                        │
└─────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ SleepTimer-Core │ │ RGB-Controller  │ │  Other Apps     │
│   (Timer Logic) │ │  (RGB Display)  │ │  (Future)       │
└─────────────────┘ └─────────────────┘ └─────────────────┘
         │                   │
         │                   │
         │                   │
         └─────────┬─────────┘
                   │
                   ▼
        ┌─────────────────────┐
        │   SleepTimer-GUI    │
        │  (Full Application) │
        └─────────────────────┘
```

---

## Version Compatibility

| Core Version | RGB Version | GUI Version | Compatible? |
|--------------|-------------|-------------|-------------|
| 3.x          | 2.x         | 3.x         | ✅ Yes      |
| 3.x          | 1.x         | 3.x         | ⚠️ Partial  |
| 2.x          | 2.x         | 3.x         | ❌ No       |

**Semantic Versioning:**
- Major: Breaking changes in API/events
- Minor: New features, backward compatible
- Patch: Bug fixes only

---

## Repository Relationships

### Submodules Approach
```bash
# SleepTimer-GUI includes Core and RGB as submodules
sleeptimer-gui/
├── modules/
│   ├── sleeptimer-core (submodule @ v3.1)
│   └── rgb-controller  (submodule @ v2.0)
```

### Package Manager Approach
```powershell
# SleepTimer-GUI depends on packages
# SleepTimer-GUI.psd1
@{
    RequiredModules = @(
        @{ ModuleName = "SleepTimer-Core"; ModuleVersion = "3.0" }
        @{ ModuleName = "RGB-Controller"; ModuleVersion = "2.0"; Optional = $true }
    )
}
```

---

## Development Workflow

### Clone All Repos
```powershell
# Create workspace
mkdir SleepTimer-Workspace
cd SleepTimer-Workspace

# Clone all repos
git clone https://github.com/yourorg/sleeptimer-sdk.git
git clone https://github.com/yourorg/sleeptimer-core.git
git clone https://github.com/yourorg/rgb-controller.git
git clone https://github.com/yourorg/sleeptimer-gui.git

# Link them together (using local paths)
# This is done via PowerShell module paths
```

### Development Structure
```
SleepTimer-Workspace/
├── sleeptimer-sdk/          # Work on shared libs
├── sleeptimer-core/         # Work on timer engine
├── rgb-controller/          # Work on RGB system
└── sleeptimer-gui/          # Work on GUI (links to above)
```

---

## Build & Release Process

### Individual Repo Builds
```yaml
# sleeptimer-core/.github/workflows/release.yml
name: Release Core
on:
  push:
    tags: ['v*']
jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Tests
        run: ./tests/Core.Tests.ps1
      - name: Publish to PSGallery
        run: Publish-Module -Path . -NuGetApiKey $env:PSGALLERY_TOKEN
```

### Unified Release
```yaml
# sleeptimer-gui/.github/workflows/release.yml
name: Release GUI Suite
on:
  push:
    tags: ['v*']
jobs:
  build:
    runs-on: windows-latest
    steps:
      - name: Checkout Core
        uses: actions/checkout@v3
        with:
          repository: yourorg/sleeptimer-core
          path: modules/core
          ref: v3.1
      
      - name: Checkout RGB
        uses: actions/checkout@v3
        with:
          repository: yourorg/rgb-controller
          path: modules/rgb
          ref: v2.0
      
      - name: Build Installer
        run: ./installers/Build-Installer.ps1
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: SleepTimer-Pro-Setup.exe
```

---

## Issue Tracking

### Per Repo
- **SleepTimer-Core:** Timer bugs, API changes, performance
- **RGB-Controller:** Device support, effects, colors
- **SleepTimer-GUI:** UI bugs, themes, user experience
- **SleepTimer-SDK:** Shared utility bugs

### Cross-Cutting Concerns
For issues spanning multiple repos:
1. Create issue in primary affected repo
2. Reference related repos
3. Tag with `cross-repo` label

---

## Contribution Guidelines

### For Core Contributors
```
1. Fork the specific repo
2. Create feature branch
3. Test against dependent repos
4. Submit PR to that repo only
```

### For Full Suite Contributors
```
1. Fork all repos
2. Create coordinated branches
3. Test full integration
4. Submit PRs to each repo with references
```

---

## Migration from Monolith

### Current State (Monolith)
```
windsurf-project/
├── SleepTimer.ps1         (1660 lines)
├── RGB-*.ps1              (4 files)
└── *.md                   (docs)
```

### Target State (Multi-Repo)
```
sleeptimer-core/           (extraction from lines 1-500)
├── SleepTimer-Core.ps1

rgb-controller/            (extraction from RGB files)
├── RGB-Controller.ps1

sleeptimer-gui/            (extraction from lines 500-1660)
├── SleepTimer-GUI.ps1

sleeptimer-sdk/            (extraction of common functions)
├── SDK/
```

### Migration Script
```powershell
# 1. Identify common functions
# 2. Extract to SDK
# 3. Refactor Core to use SDK
# 4. Refactor RGB to use SDK
# 5. Refactor GUI to use SDK + Core + RGB
# 6. Test everything together
# 7. Archive monolith repo
```

---

## Benefits of Separation

| Aspect | Monolith | Multi-Repo |
|--------|----------|------------|
| **Clone Time** | Slow (all or nothing) | Fast (just what you need) |
| **Build Time** | Long | Short per repo |
| **Test Scope** | Everything | Focused |
| **Issue Tracking** | Mixed | Organized |
| **Contributors** | Need full context | Can specialize |
| **Release Cycle** | Tied together | Independent |
| **Dependencies** | Implicit | Explicit |

---

## Action Items

### Phase 1: Preparation
- [ ] Create 4 new GitHub repos
- [ ] Set up CI/CD for each
- [ ] Create SleepTimer-SDK with common functions
- [ ] Write migration scripts

### Phase 2: Extraction
- [ ] Port SleepTimer-Core (extract from main file)
- [ ] Port RGB-Controller (consolidate RGB files)
- [ ] Port SleepTimer-GUI (extract GUI portions)

### Phase 3: Integration
- [ ] Update GUI to use Core + RGB as dependencies
- [ ] Test full integration
- [ ] Create unified installer

### Phase 4: Deprecation
- [ ] Archive monolith repo
- [ ] Update documentation
- [ ] Announce to users

---

## Quick Start Commands (Future)

```bash
# User wants just the timer
git clone https://github.com/yourorg/sleeptimer-core.git

# User wants full suite
git clone https://github.com/yourorg/sleeptimer-gui.git
cd sleeptimer-gui
git submodule update --init

# Developer wants everything
mkdir workspace && cd workspace
git clone https://github.com/yourorg/sleeptimer-sdk.git
git clone https://github.com/yourorg/sleeptimer-core.git
git clone https://github.com/yourorg/rgb-controller.git
git clone https://github.com/yourorg/sleeptimer-gui.git
```

This structure enables **true modularity** with clear boundaries and independent evolution! 🏗️
