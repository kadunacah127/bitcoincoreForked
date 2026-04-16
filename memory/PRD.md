# Bitcoin Core Patched Build - PRD

## Original Problem Statement
Deep scan of cloned Bitcoin Core repository to check if files are ready for compiling and making a .exe file on Windows.

**Updated Goal:** Build a patched Windows `.exe` of Bitcoin Core v23.0 (from user's forked repo) that bypasses the "GenerateNewKey: AddKey failed" error, allowing a corrupted/encrypted legacy `wallet.dat` to load in the `bitcoin-qt` GUI.

## Target Repository
- **Fork:** https://github.com/kadunacah127/bitcoincoreForked (Bitcoin Core v23.0)
- **Build System:** Autotools (autogen.sh / configure / make)
- **Build Environment:** Google Colab (Ubuntu) -> cross-compile to Windows x86_64
- **Cross-compiler:** MinGW-w64 (x86_64-w64-mingw32)

## User's Core Problem
- User has an encrypted legacy `wallet.dat` (Berkeley DB format)
- Loading it in standard Bitcoin Core throws: `GenerateNewKey: AddKey failed` (code -4)
- The wallet DB has some corruption in its key records
- Standard Bitcoin Core aborts on this error

## Solution Strategy
Patch the Bitcoin Core v23.0 source to:
1. Not crash on AddKey failures in GenerateNewKey
2. Not abort wallet loading on CORRUPT DB status
3. Downgrade key corruption errors to warnings
4. Allow the GUI (bitcoin-qt) to open so user can access wallet data

## Pre-existing Patches in Forked Repo
The forked repo already has these modifications:
- `CWallet::IsLocked()` always returns false
- `CWallet::Unlock()` always succeeds (passphrase bypass)
- `CWallet::Lock()` is a no-op
- `LegacyScriptPubKeyMan::CheckDecryptionKey()` always returns true
- `DescriptorScriptPubKeyMan::CheckDecryptionKey()` always returns true

## Patches Applied by Colab Script
1. **scriptpubkeyman.cpp**: `GenerateNewKey` throw → LogPrintf warning
2. **scriptpubkeyman.cpp**: `DeriveNewSeed` throw → LogPrintf warning
3. **wallet.cpp**: `CWallet::Create` CORRUPT handler → warning instead of nullptr
4. **walletdb.cpp**: All `result = DBErrors::CORRUPT` → NONCRITICAL_ERROR
5. **walletdb.cpp**: Direct `return DBErrors::CORRUPT` → NONCRITICAL_ERROR
6. **walletdb.cpp**: Early-return on non-LOAD_OK → only abort on truly fatal

## Implemented
- [x] Full repository structure scan (Jan 2026)
- [x] Critical files verification
- [x] Git integrity check
- [x] Dependencies validation
- [x] Windows build documentation review
- [x] Local Windows build scripts (abandoned - network/SSL issues)
- [x] Colab CLI-only build scripts (v1, v2)
- [x] wallet.dat hex analysis (confirmed encrypted Berkeley DB)
- [x] C++ patch identification for wallet error bypass
- [x] **Colab GUI build script with patches** (COLAB_PATCHED_GUI_BUILD.txt)

## Files
- `/app/COLAB_PATCHED_GUI_BUILD.txt` - Complete Colab script for patched GUI build
- `/app/COLAB_BUILD_INSTRUCTIONS.txt` - Old CLI-only build (v1)
- `/app/COLAB_BUILD_INSTRUCTIONS_v2.txt` - Old CLI-only build (v2)
- `/app/BUILD.bat` - Abandoned local build script

## Next Steps
1. User runs the Colab GUI script to build bitcoin-qt.exe
2. User downloads and runs the patched bitcoin-qt.exe on Windows
3. User loads wallet.dat via the GUI
4. User exports private keys via `dumpwallet` command in console
5. User imports keys into a fresh, working wallet

## Key Differences: CLI vs GUI Script
| Feature | Old Script | New Script |
|---------|-----------|------------|
| Qt GUI | `NO_QT=1` (disabled) | Qt5 built in depends |
| Build system | CMake | Autotools (autogen/configure/make) |
| Configure | `cmake -B build` | `./configure --with-gui=yes` |
| Output | bitcoind.exe only | bitcoin-qt.exe + CLI tools |
| Build time | ~2 hours | ~3-4 hours |
| Repository | BitcoinCoreCloned | bitcoincoreForked |
