# Detailed Windows Build Guide for Bitcoin Core

This guide provides step-by-step instructions to build Bitcoin Core executables (.exe) on Windows.

---

## Table of Contents
1. [System Requirements](#system-requirements)
2. [Installing Prerequisites](#installing-prerequisites)
3. [Getting the Source Code](#getting-the-source-code)
4. [Building Bitcoin Core](#building-bitcoin-core)
5. [Build Options](#build-options)
6. [Troubleshooting](#troubleshooting)
7. [Post-Build Steps](#post-build-steps)

---

## System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Windows 10 (64-bit) | Windows 11 (64-bit) |
| RAM | 8 GB | 16 GB |
| Disk Space | 20 GB free | 50 GB free |
| CPU | 4 cores | 8+ cores |

---

## Installing Prerequisites

### Step 1: Install Visual Studio 2022/2026

**Option A: Using winget (Recommended)**

Open PowerShell as Administrator:
```powershell
winget install --id Microsoft.VisualStudio.2022.Community --override "--wait --quiet --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Component.Git --includeRecommended"
```

**Option B: Manual Installation**

1. Download from: https://visualstudio.microsoft.com/downloads/
2. Run installer
3. Select **"Desktop development with C++"** workload
4. Ensure these are checked:
   - MSVC v143 (or latest) C++ x64/x86 build tools
   - Windows SDK (latest)
   - C++ CMake tools for Windows
   - Git for Windows

### Step 2: Install Python 3.10+

```powershell
winget install Python.Python.3.12
```

Verify:
```powershell
python --version
```

### Step 3: Install CMake (if not included with VS)

```powershell
winget install Kitware.CMake
```

Or download from: https://cmake.org/download/

**Important:** During installation, select "Add CMake to system PATH"

Verify:
```powershell
cmake --version
```

### Step 4: Install Git (if not included with VS)

```powershell
winget install Git.Git
```

---

## Getting the Source Code

### Option 1: Clone Repository

Open **Developer PowerShell for VS 2022** (search in Start Menu):

```powershell
cd C:\
git clone https://github.com/kadunacah127/BitcoinCoreCloned.git
cd BitcoinCoreCloned
git checkout master
```

### Option 2: Download ZIP

1. Go to https://github.com/kadunacah127/BitcoinCoreCloned
2. Click **Code** → **Download ZIP**
3. Extract to `C:\BitcoinCoreCloned`

**Important:** 
- Avoid paths with spaces (use `C:\BitcoinCore` not `C:\Bitcoin Core`)
- Keep path short (avoid deeply nested folders)

---

## Building Bitcoin Core

### Open Developer PowerShell

1. Press Windows key
2. Search for **"Developer PowerShell for VS 2022"**
3. Right-click → **Run as Administrator**

### Navigate to Source

```powershell
cd C:\BitcoinCoreCloned
```

### Configure the Build

**Standard Build (with GUI, static linking):**
```powershell
cmake -B build --preset vs2022-static
```

**If you don't have preset, use manual configuration:**
```powershell
# First, setup vcpkg if not done
git clone https://github.com/microsoft/vcpkg.git C:\vcpkg
C:\vcpkg\bootstrap-vcpkg.bat
$env:VCPKG_ROOT = "C:\vcpkg"

# Configure
cmake -B build -G "Visual Studio 17 2022" -A x64 `
    -DCMAKE_TOOLCHAIN_FILE="C:\vcpkg\scripts\buildsystems\vcpkg.cmake" `
    -DVCPKG_TARGET_TRIPLET="x64-windows-static" `
    -DBUILD_GUI=ON `
    -DENABLE_WALLET=ON
```

> **Note:** First configuration takes 15-45 minutes as vcpkg downloads and builds dependencies.

### Build the Executables

```powershell
cmake --build build --config Release --parallel 8
```

Replace `8` with your CPU core count for faster builds.

### Verify Build Success

```powershell
Get-ChildItem build\bin\Release\*.exe
```

Expected output:
```
bitcoind.exe
bitcoin-qt.exe
bitcoin-cli.exe
bitcoin-tx.exe
bitcoin-wallet.exe
bitcoin-util.exe
```

---

## Build Options

### Build Configurations

| Configuration | Command |
|--------------|---------|
| Release (optimized) | `cmake --build build --config Release` |
| Debug (for development) | `cmake --build build --config Debug` |
| RelWithDebInfo | `cmake --build build --config RelWithDebInfo` |

### CMake Options

| Option | Default | Description |
|--------|---------|-------------|
| `-DBUILD_GUI=ON` | ON | Build bitcoin-qt.exe (GUI wallet) |
| `-DBUILD_DAEMON=ON` | ON | Build bitcoind.exe |
| `-DBUILD_CLI=ON` | ON | Build bitcoin-cli.exe |
| `-DENABLE_WALLET=ON` | ON | Enable wallet functionality |
| `-DBUILD_TESTS=ON` | ON | Build test executables |
| `-DWITH_ZMQ=ON` | OFF | Enable ZeroMQ notifications |
| `-DBUILD_BENCH=OFF` | OFF | Build benchmark tool |

### Quick Build (No GUI, No Tests)

For faster compilation:
```powershell
cmake -B build --preset vs2022-static -DBUILD_GUI=OFF -DBUILD_TESTS=OFF -DBUILD_BENCH=OFF
cmake --build build --config Release --parallel 8
```

### Minimal Build (CLI tools only)

```powershell
cmake -B build -G "Visual Studio 17 2022" -A x64 `
    -DCMAKE_TOOLCHAIN_FILE="C:\vcpkg\scripts\buildsystems\vcpkg.cmake" `
    -DVCPKG_TARGET_TRIPLET="x64-windows-static" `
    -DBUILD_GUI=OFF `
    -DBUILD_TESTS=OFF `
    -DBUILD_BENCH=OFF `
    -DWITH_ZMQ=OFF `
    -DENABLE_WALLET=ON

cmake --build build --config Release --parallel 8
```

---

## Troubleshooting

### Error: "Buildtrees path is too long"

```powershell
cmake -B build --preset vs2022-static -DVCPKG_INSTALL_OPTIONS="--x-buildtrees-root=C:\vbt"
```

### Error: "Paths with embedded space"

Move your source to a path without spaces:
```powershell
Move-Item "C:\Bitcoin Core" "C:\BitcoinCore"
cd C:\BitcoinCore
```

Or set alternate vcpkg directory:
```powershell
cmake -B build --preset vs2022-static -DVCPKG_INSTALLED_DIR="C:\vcpkg_pkgs"
```

### Error: "CMake not found"

Add CMake to PATH:
```powershell
$env:Path += ";C:\Program Files\CMake\bin"
```

Or reinstall CMake with "Add to PATH" option.

### Error: "Installer failed with exit code: 1603"

1. Run as Administrator
2. Close all Visual Studio instances
3. Restart computer
4. Try again

### Slow Build Performance

1. **Add exclusions to Windows Defender:**
   - Settings → Windows Security → Virus & threat protection
   - Manage settings → Exclusions → Add exclusion
   - Add: `C:\BitcoinCoreCloned` and `C:\vcpkg`

2. **Use parallel builds:**
   ```powershell
   cmake --build build --config Release --parallel 16
   ```

3. **Disable GUI and tests for faster iteration:**
   ```powershell
   cmake -B build ... -DBUILD_GUI=OFF -DBUILD_TESTS=OFF
   ```

### vcpkg Issues

**Reset vcpkg cache:**
```powershell
Remove-Item -Recurse -Force C:\vcpkg\installed
Remove-Item -Recurse -Force C:\vcpkg\buildtrees
cmake -B build --preset vs2022-static
```

**Update vcpkg:**
```powershell
cd C:\vcpkg
git pull
.\bootstrap-vcpkg.bat
```

---

## Post-Build Steps

### Install to a Directory

```powershell
cmake --install build --config Release --prefix C:\Bitcoin
```

With debug symbols stripped (smaller files):
```powershell
cmake --install build --config Release --prefix C:\Bitcoin --strip
```

### Create Windows Installer

1. Install NSIS:
   ```powershell
   winget install NSIS.NSIS
   ```

2. Build installer:
   ```powershell
   cmake --build build --target deploy --config Release
   ```

3. Find installer in `build\` directory.

### Run Tests

```powershell
ctest --test-dir build --build-config Release --parallel 8
```

### Verify Executables

```powershell
.\build\bin\Release\bitcoind.exe --version
.\build\bin\Release\bitcoin-cli.exe --version
.\build\bin\Release\bitcoin-qt.exe --version
```

---

## Output Files Reference

| Executable | Purpose |
|------------|---------|
| `bitcoind.exe` | Full node daemon (runs in background) |
| `bitcoin-qt.exe` | GUI wallet application |
| `bitcoin-cli.exe` | Command-line RPC interface |
| `bitcoin-tx.exe` | Transaction creation/manipulation |
| `bitcoin-wallet.exe` | Offline wallet management |
| `bitcoin-util.exe` | Utility functions |

---

## Quick Reference Commands

```powershell
# Full build with GUI
cmake -B build --preset vs2022-static
cmake --build build --config Release -j 8

# Quick build without GUI
cmake -B build --preset vs2022-static -DBUILD_GUI=OFF -DBUILD_TESTS=OFF
cmake --build build --config Release -j 8

# Install
cmake --install build --config Release --prefix C:\Bitcoin --strip

# Clean rebuild
Remove-Item -Recurse -Force build
cmake -B build --preset vs2022-static
cmake --build build --config Release -j 8
```

---

## Need Help?

- Bitcoin Core documentation: https://github.com/bitcoin/bitcoin/tree/master/doc
- Bitcoin Stack Exchange: https://bitcoin.stackexchange.com
- Bitcoin Core GitHub Issues: https://github.com/bitcoin/bitcoin/issues
