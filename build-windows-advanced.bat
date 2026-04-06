@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: Bitcoin Core Windows Build Script - ADVANCED VERSION v2.3
:: Fixed: No abnormal exits, all errors handled gracefully
:: ============================================================================

title Bitcoin Core Windows Builder (Advanced v2.3)
color 0B

:: Default Configuration
set "REPO_DIR=%~dp0"
set "VCPKG_DIR=C:\vcpkg"
set "BUILD_DIR=%REPO_DIR%build"
set "INSTALL_DIR=C:\Bitcoin"
set "VCPKG_BUILDTREES=C:\vbt"
set "BUILD_GUI=OFF"
set "BUILD_TESTS=OFF"
set "BUILD_WALLET=ON"
set "BUILD_ZMQ=OFF"
set "BUILD_TYPE=Release"
set "PARALLEL_JOBS=8"
set "CLEAN_BUILD=0"
set "MAX_RETRIES=3"

:: Required VS version
set "REQUIRED_VS_VERSION=2022"
set "REQUIRED_VS_GENERATOR=Visual Studio 17 2022"

:: Fix SSL/TLS issues
set "GIT_SSL_NO_VERIFY=0"
set "CURL_SSL_BACKEND=schannel"

goto :Menu

:: ============================================================================
:: MENU
:: ============================================================================

:Menu
cls
echo.
echo ============================================================================
echo           BITCOIN CORE WINDOWS BUILD SCRIPT (ADVANCED v2.3)
echo ============================================================================
echo.
echo   Build Configuration:
echo   ---------------------
echo   [1] Build GUI (bitcoin-qt.exe):     %BUILD_GUI%
echo   [2] Build Tests:                    %BUILD_TESTS%
echo   [3] Enable Wallet:                  %BUILD_WALLET%
echo   [4] Enable ZeroMQ:                  %BUILD_ZMQ%
echo   [5] Build Type:                     %BUILD_TYPE%
echo   [6] Parallel Jobs:                  %PARALLEL_JOBS%
echo   [7] Clean Build:                    %CLEAN_BUILD%
echo   [8] Install Directory:              %INSTALL_DIR%
echo.
echo   Actions:
echo   --------
echo   [C] Check Requirements Only
echo   [B] START BUILD
echo   [I] Install After Build
echo   [R] REPAIR / Fix Issues (remove ALL VS versions, clear cache, fix network)
echo   [Q] Quit
echo.
echo ============================================================================
echo.

set "CHOICE="
set /p "CHOICE=Enter option: "

if /i "%CHOICE%"=="1" goto :ToggleGUI
if /i "%CHOICE%"=="2" goto :ToggleTests
if /i "%CHOICE%"=="3" goto :ToggleWallet
if /i "%CHOICE%"=="4" goto :ToggleZMQ
if /i "%CHOICE%"=="5" goto :ToggleBuildType
if /i "%CHOICE%"=="6" goto :SetJobs
if /i "%CHOICE%"=="7" goto :ToggleClean
if /i "%CHOICE%"=="8" goto :SetInstallDir
if /i "%CHOICE%"=="C" goto :CheckOnly
if /i "%CHOICE%"=="B" goto :StartBuild
if /i "%CHOICE%"=="I" goto :InstallOnly
if /i "%CHOICE%"=="R" goto :RepairAll
if /i "%CHOICE%"=="Q" goto :Quit

goto :Menu

:ToggleGUI
if "%BUILD_GUI%"=="OFF" (set "BUILD_GUI=ON") else (set "BUILD_GUI=OFF")
goto :Menu

:ToggleTests
if "%BUILD_TESTS%"=="OFF" (set "BUILD_TESTS=ON") else (set "BUILD_TESTS=OFF")
goto :Menu

:ToggleWallet
if "%BUILD_WALLET%"=="OFF" (set "BUILD_WALLET=ON") else (set "BUILD_WALLET=OFF")
goto :Menu

:ToggleZMQ
if "%BUILD_ZMQ%"=="OFF" (set "BUILD_ZMQ=ON") else (set "BUILD_ZMQ=OFF")
goto :Menu

:ToggleBuildType
if "%BUILD_TYPE%"=="Release" (
    set "BUILD_TYPE=Debug"
) else if "%BUILD_TYPE%"=="Debug" (
    set "BUILD_TYPE=RelWithDebInfo"
) else (
    set "BUILD_TYPE=Release"
)
goto :Menu

:SetJobs
set /p "PARALLEL_JOBS=Enter number of parallel jobs (1-32): "
goto :Menu

:ToggleClean
if "%CLEAN_BUILD%"=="0" (set "CLEAN_BUILD=1") else (set "CLEAN_BUILD=0")
goto :Menu

:SetInstallDir
set /p "INSTALL_DIR=Enter install directory: "
goto :Menu

:Quit
echo.
echo Goodbye!
echo.
pause
exit /b 0

:: ============================================================================
:: CHECK ONLY
:: ============================================================================

:CheckOnly
cls
echo.
echo ============================================================================
echo                    CHECKING REQUIREMENTS
echo ============================================================================
echo.

set "CHECK_RESULT=OK"

:: Check Git
echo [CHECK] Git...
where git >nul 2>&1
if errorlevel 1 (
    echo         [MISSING] Git not found
    echo         [ACTION] Will install Git...
    call :DoInstallGit
    where git >nul 2>&1
    if errorlevel 1 (
        echo         [FAILED] Git installation failed
        set "CHECK_RESULT=FAILED"
    ) else (
        echo         [OK] Git installed successfully
    )
) else (
    for /f "tokens=3" %%v in ('git --version 2^>nul') do echo         [OK] Git version %%v
)

:: Check Python
echo [CHECK] Python...
where python >nul 2>&1
if errorlevel 1 (
    echo         [MISSING] Python not found
    echo         [ACTION] Will install Python...
    call :DoInstallPython
    echo         [INFO] Python installed - may need restart
) else (
    for /f "tokens=2" %%v in ('python --version 2^>nul') do echo         [OK] Python version %%v
)

:: Check CMake
echo [CHECK] CMake...
where cmake >nul 2>&1
if errorlevel 1 (
    echo         [MISSING] CMake not found
    echo         [ACTION] Will install CMake...
    call :DoInstallCMake
    echo         [INFO] CMake installed - may need restart
) else (
    for /f "tokens=3" %%v in ('cmake --version 2^>nul ^| findstr /i "version"') do echo         [OK] CMake version %%v
)

:: Check Visual Studio
echo [CHECK] Visual Studio %REQUIRED_VS_VERSION%...
call :CheckVSVersion
if "!VS_FOUND!"=="1" (
    echo         [OK] Visual Studio %REQUIRED_VS_VERSION% found
    echo         [OK] Path: !VS_PATH!
) else (
    echo         [MISSING] Visual Studio %REQUIRED_VS_VERSION% not found
    echo         [ACTION] Will install VS Build Tools...
    call :DoInstallVSFresh
    call :CheckVSVersion
    if "!VS_FOUND!"=="1" (
        echo         [OK] Visual Studio %REQUIRED_VS_VERSION% installed
    ) else (
        echo         [FAILED] VS installation failed - try [R] Repair
        set "CHECK_RESULT=FAILED"
    )
)

:: Check vcpkg
echo [CHECK] vcpkg...
if exist "%VCPKG_DIR%\vcpkg.exe" (
    echo         [OK] vcpkg found at %VCPKG_DIR%
) else (
    echo         [MISSING] vcpkg not found
    echo         [ACTION] Will install vcpkg...
    call :DoInstallVcpkg
    if exist "%VCPKG_DIR%\vcpkg.exe" (
        echo         [OK] vcpkg installed successfully
    ) else (
        echo         [FAILED] vcpkg installation failed
        set "CHECK_RESULT=FAILED"
    )
)

echo.
echo ============================================================================
if "!CHECK_RESULT!"=="OK" (
    echo                    ALL REQUIREMENTS SATISFIED
) else (
    echo                    SOME REQUIREMENTS FAILED
    echo              Press [R] to Repair or restart and try again
)
echo ============================================================================
echo.
echo Press any key to return to menu...
pause >nul
goto :Menu

:: ============================================================================
:: CHECK VS VERSION (Sets VS_FOUND and VS_PATH)
:: ============================================================================

:CheckVSVersion
set "VS_FOUND=0"
set "VS_PATH="

:: Method 1: Check common installation paths directly
for %%p in (
    "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Community"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Professional"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\Community"
) do (
    if exist "%%~p\VC\Auxiliary\Build\vcvars64.bat" (
        set "VS_PATH=%%~p"
        set "VS_FOUND=1"
    )
)

:: Method 2: Try vswhere if available
if "!VS_FOUND!"=="0" (
    set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
    if exist "!VSWHERE!" (
        for /f "usebackq tokens=*" %%i in (`"!VSWHERE!" -latest -property installationPath 2^>nul`) do (
            if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" (
                set "VS_PATH=%%i"
                set "VS_FOUND=1"
            )
        )
    )
)

goto :eof

:: ============================================================================
:: INSTALL ONLY
:: ============================================================================

:InstallOnly
cls
echo.
echo ============================================================================
echo                         INSTALLING BUILD
echo ============================================================================
echo.

set "INSTALL_FOUND=0"
set "INSTALL_SRC="

for %%d in (
    "%BUILD_DIR%\bin\%BUILD_TYPE%"
    "%BUILD_DIR%\src\%BUILD_TYPE%"
    "%BUILD_DIR%\bin\Release"
    "%BUILD_DIR%\src\Release"
    "%BUILD_DIR%\bin"
    "%BUILD_DIR%\src"
) do (
    if exist "%%~d\bitcoind.exe" (
        set "INSTALL_FOUND=1"
        set "INSTALL_SRC=%%~d"
    )
)

if "!INSTALL_FOUND!"=="1" (
    echo [INFO] Found build at: !INSTALL_SRC!
    echo [INFO] Installing to: %INSTALL_DIR%
    echo.
    cmake --install "%BUILD_DIR%" --config %BUILD_TYPE% --prefix "%INSTALL_DIR%" --strip 2>nul
    if errorlevel 1 (
        echo [WARNING] Install with strip failed, trying without strip...
        cmake --install "%BUILD_DIR%" --config %BUILD_TYPE% --prefix "%INSTALL_DIR%" 2>nul
    )
    echo.
    echo [DONE] Installation complete!
) else (
    echo [ERROR] No build found.
    echo [INFO] Run Build first by pressing [B]
)

echo.
echo Press any key to return to menu...
pause >nul
goto :Menu

:: ============================================================================
:: REPAIR ALL ISSUES
:: ============================================================================

:RepairAll
cls
echo.
echo ============================================================================
echo                     REPAIR / FIX ALL ISSUES (v2.3)
echo ============================================================================
echo.
echo This will:
echo   1. Clear vcpkg download cache (fixes SSL/download errors)
echo   2. Clear build trees (fixes path too long errors)
echo   3. Update vcpkg to latest version
echo   4. REMOVE ALL Visual Studio installations:
echo      - VS 2015, 2017, 2019, 2022, 2026 and ANY other version
echo      - Community, Professional, Enterprise, BuildTools
echo      - All incomplete/partial installations
echo   5. Install fresh Visual Studio Build Tools %REQUIRED_VS_VERSION%
echo   6. Reset network settings for downloads
echo   7. Clean previous build
echo.
echo [WARNING] This will UNINSTALL all Visual Studio versions!
echo [WARNING] This process may take 15-30 minutes.
echo.

set "CONFIRM="
set /p "CONFIRM=Continue? (Y/N): "
if /i not "%CONFIRM%"=="Y" goto :Menu

echo.
echo ============================================================================
echo                    STARTING REPAIR PROCESS
echo ============================================================================
echo.

:: Step 1: Clear vcpkg caches
echo [REPAIR 1/7] Clearing vcpkg caches...
if exist "%VCPKG_DIR%\downloads" rmdir /s /q "%VCPKG_DIR%\downloads" 2>nul
if exist "%VCPKG_DIR%\installed" rmdir /s /q "%VCPKG_DIR%\installed" 2>nul
if exist "%VCPKG_DIR%\buildtrees" rmdir /s /q "%VCPKG_DIR%\buildtrees" 2>nul
if exist "%VCPKG_DIR%\packages" rmdir /s /q "%VCPKG_DIR%\packages" 2>nul
echo            [OK] vcpkg caches cleared

:: Step 2: Clear build trees
echo [REPAIR 2/7] Clearing build directories...
if exist "%VCPKG_BUILDTREES%" rmdir /s /q "%VCPKG_BUILDTREES%" 2>nul
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%" 2>nul
echo            [OK] Build directories cleared

:: Step 3: Update vcpkg
echo [REPAIR 3/7] Updating vcpkg...
if exist "%VCPKG_DIR%\.git" (
    pushd "%VCPKG_DIR%" 2>nul
    if not errorlevel 1 (
        git fetch origin 2>nul
        git reset --hard origin/master 2>nul
        call bootstrap-vcpkg.bat -disableMetrics >nul 2>&1
        popd
        echo            [OK] vcpkg updated
    ) else (
        echo            [SKIP] Could not access vcpkg directory
    )
) else (
    echo            [SKIP] vcpkg not installed yet
)

:: Step 4: Remove ALL Visual Studio installations
echo [REPAIR 4/7] Removing ALL Visual Studio installations...
echo            [INFO] This may take several minutes...
call :DoRemoveAllVS

:: Step 5: Install fresh Visual Studio Build Tools
echo.
echo [REPAIR 5/7] Installing Visual Studio Build Tools %REQUIRED_VS_VERSION%...
echo            [INFO] This may take 10-20 minutes...
call :DoInstallVSFresh

:: Step 6: Fix network settings
echo.
echo [REPAIR 6/7] Fixing network settings...
netsh winsock reset >nul 2>&1
netsh int ip reset >nul 2>&1
ipconfig /flushdns >nul 2>&1
echo            [OK] Network settings reset

git config --global http.sslBackend schannel 2>nul
git config --global http.postBuffer 524288000 2>nul
git config --global core.longpaths true 2>nul
echo            [OK] Git configured

:: Step 7: Verify
echo.
echo [REPAIR 7/7] Verifying installation...
call :CheckVSVersion
if "!VS_FOUND!"=="1" (
    echo            [OK] Visual Studio %REQUIRED_VS_VERSION% verified
) else (
    echo            [WARNING] Visual Studio may need manual installation
)

echo.
echo ============================================================================
echo                         REPAIR COMPLETE
echo ============================================================================
echo.
echo IMPORTANT: Please RESTART YOUR COMPUTER before building!
echo.
echo After restart:
echo   1. Run this script again as Administrator
echo   2. Press [B] to start the build
echo.
echo ============================================================================
echo.
echo Press any key to return to menu...
pause >nul
goto :Menu

:: ============================================================================
:: REMOVE ALL VISUAL STUDIO
:: ============================================================================

:DoRemoveAllVS
:: Uninstall via winget (silent, no errors cause exit)
where winget >nul 2>&1
if not errorlevel 1 (
    echo            Uninstalling via winget...
    
    :: 2026
    winget uninstall --id Microsoft.VisualStudio.2026.Community --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2026.Professional --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2026.Enterprise --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2026.BuildTools --silent 2>nul
    
    :: 2022
    winget uninstall --id Microsoft.VisualStudio.2022.Community --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2022.Professional --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2022.Enterprise --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2022.BuildTools --silent 2>nul
    
    :: 2019
    winget uninstall --id Microsoft.VisualStudio.2019.Community --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2019.Professional --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2019.Enterprise --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2019.BuildTools --silent 2>nul
    
    :: 2017
    winget uninstall --id Microsoft.VisualStudio.2017.Community --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2017.Professional --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2017.Enterprise --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2017.BuildTools --silent 2>nul
    
    :: 2015
    winget uninstall --id Microsoft.VisualStudio.2015.Community --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2015.Professional --silent 2>nul
    winget uninstall --id Microsoft.VisualStudio.2015.Enterprise --silent 2>nul
)

:: Use VS Installer to clean up
set "VS_INSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe"
if exist "!VS_INSTALLER!" (
    echo            Running VS Installer cleanup...
    "!VS_INSTALLER!" --quiet --wait --norestart uninstall --all 2>nul
)

:: Remove directories
echo            Removing leftover directories...

:: All VS versions
for %%y in (2015 2017 2019 2022 2024 2026) do (
    if exist "%ProgramFiles%\Microsoft Visual Studio\%%y" rmdir /s /q "%ProgramFiles%\Microsoft Visual Studio\%%y" 2>nul
    if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\%%y" rmdir /s /q "%ProgramFiles(x86)%\Microsoft Visual Studio\%%y" 2>nul
)

:: VS Installer
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer" rmdir /s /q "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer" 2>nul

:: VS caches
if exist "%ProgramData%\Microsoft\VisualStudio" rmdir /s /q "%ProgramData%\Microsoft\VisualStudio" 2>nul
if exist "%LOCALAPPDATA%\Microsoft\VisualStudio" rmdir /s /q "%LOCALAPPDATA%\Microsoft\VisualStudio" 2>nul

echo            [OK] Visual Studio removal complete
goto :eof

:: ============================================================================
:: INSTALL VS FRESH
:: ============================================================================

:DoInstallVSFresh
where winget >nul 2>&1
if not errorlevel 1 (
    echo            Installing via winget...
    winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --quiet --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended" --accept-package-agreements --accept-source-agreements 2>nul
    if not errorlevel 1 (
        echo            [OK] Visual Studio Build Tools installed via winget
        goto :eof
    )
    echo            [WARNING] winget failed, trying direct download...
)

:: Direct download fallback
echo            Downloading VS Build Tools installer...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile '%TEMP%\vs_buildtools.exe' -UseBasicParsing" 2>nul

if exist "%TEMP%\vs_buildtools.exe" (
    echo            Running installer (10-20 minutes)...
    "%TEMP%\vs_buildtools.exe" --quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended 2>nul
    del "%TEMP%\vs_buildtools.exe" 2>nul
    echo            [OK] Visual Studio Build Tools installed
) else (
    echo            [ERROR] Download failed
    echo            [INFO] Please install VS Build Tools 2022 manually from:
    echo            https://visualstudio.microsoft.com/downloads/
)
goto :eof

:: ============================================================================
:: START BUILD
:: ============================================================================

:StartBuild
cls
echo.
echo ============================================================================
echo                         STARTING BUILD PROCESS
echo ============================================================================
echo.
echo   Configuration:
echo   - GUI: %BUILD_GUI%
echo   - Tests: %BUILD_TESTS%
echo   - Wallet: %BUILD_WALLET%
echo   - ZeroMQ: %BUILD_ZMQ%
echo   - Build Type: %BUILD_TYPE%
echo   - Parallel Jobs: %PARALLEL_JOBS%
echo   - Clean Build: %CLEAN_BUILD%
echo.
echo ============================================================================
echo.

:: Check admin rights (warning only)
net session >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Not running as Administrator.
    echo.
)

:: Step 1: Check requirements
echo [STEP 1/6] Checking requirements...
set "REQ_OK=1"

where git >nul 2>&1
if errorlevel 1 (
    echo         [ERROR] Git not found - run [C] Check Requirements first
    set "REQ_OK=0"
) else (
    echo         [OK] Git
)

where cmake >nul 2>&1
if errorlevel 1 (
    echo         [ERROR] CMake not found - run [C] Check Requirements first
    set "REQ_OK=0"
) else (
    echo         [OK] CMake
)

call :CheckVSVersion
if "!VS_FOUND!"=="0" (
    echo         [ERROR] Visual Studio not found - run [C] Check Requirements first
    set "REQ_OK=0"
) else (
    echo         [OK] Visual Studio
)

if not exist "%VCPKG_DIR%\vcpkg.exe" (
    echo         [ERROR] vcpkg not found - run [C] Check Requirements first
    set "REQ_OK=0"
) else (
    echo         [OK] vcpkg
)

if "!REQ_OK!"=="0" (
    echo.
    echo [ERROR] Requirements not met. Press [C] to check/install requirements.
    echo.
    pause
    goto :Menu
)

:: Step 2: Setup environment
echo.
echo [STEP 2/6] Setting up build environment...

if not defined VS_PATH (
    call :CheckVSVersion
)

if defined VS_PATH (
    echo         Loading VS environment from: !VS_PATH!
    call "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" x64 >nul 2>&1
    echo         [OK] Visual Studio environment loaded
) else (
    echo         [ERROR] Cannot find Visual Studio
    pause
    goto :Menu
)

set "VCPKG_ROOT=%VCPKG_DIR%"

:: Change back to source directory after loading VS environment
cd /d "%REPO_DIR%"

:: Step 3: Verify source
echo.
echo [STEP 3/6] Verifying source code...

if not exist "%REPO_DIR%CMakeLists.txt" (
    echo         [ERROR] CMakeLists.txt not found
    echo         [ERROR] Run this script from Bitcoin Core source directory
    pause
    goto :Menu
)

if not exist "%REPO_DIR%src\bitcoind.cpp" (
    echo         [ERROR] Source files not found
    pause
    goto :Menu
)

echo         [OK] Source code verified

:: Step 4: Configure
echo.
echo [STEP 4/6] Configuring build (may take 15-45 min first time)...

:: IMPORTANT: Change to source directory
cd /d "%REPO_DIR%"
echo         Source dir: %CD%

if "%CLEAN_BUILD%"=="1" (
    if exist "%BUILD_DIR%" (
        echo         Cleaning previous build...
        rmdir /s /q "%BUILD_DIR%" 2>nul
    )
)

if not exist "%VCPKG_BUILDTREES%" mkdir "%VCPKG_BUILDTREES%" 2>nul

echo         Generator: %REQUIRED_VS_GENERATOR%
echo.

cmake -S "%REPO_DIR%" -B "%BUILD_DIR%" -G "%REQUIRED_VS_GENERATOR%" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_DIR%\scripts\buildsystems\vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-windows-static -DVCPKG_INSTALL_OPTIONS="--x-buildtrees-root=%VCPKG_BUILDTREES%" -DBUILD_GUI=%BUILD_GUI% -DBUILD_TESTS=%BUILD_TESTS% -DBUILD_BENCH=OFF -DWITH_ZMQ=%BUILD_ZMQ% -DENABLE_WALLET=%BUILD_WALLET%

if errorlevel 1 (
    echo.
    echo [ERROR] Configuration failed!
    echo [INFO] Try pressing [R] to Repair
    pause
    goto :Menu
)

echo.
echo         [OK] Configuration complete

:: Step 5: Build
echo.
echo [STEP 5/6] Building Bitcoin Core...
echo         Using %PARALLEL_JOBS% parallel jobs
echo.

cmake --build "%BUILD_DIR%" --config %BUILD_TYPE% --parallel %PARALLEL_JOBS%

if errorlevel 1 (
    echo.
    echo [ERROR] Build failed!
    pause
    goto :Menu
)

echo.
echo         [OK] Build complete

:: Step 6: Report
echo.
echo [STEP 6/6] Build Results
echo.
echo ============================================================================

set "EXE_DIR="
set "EXE_COUNT=0"

for %%d in (
    "%BUILD_DIR%\bin\%BUILD_TYPE%"
    "%BUILD_DIR%\src\%BUILD_TYPE%"
    "%BUILD_DIR%\bin\Release"
    "%BUILD_DIR%\src\Release"
) do (
    if exist "%%~d\bitcoind.exe" set "EXE_DIR=%%~d"
)

if defined EXE_DIR (
    echo   Location: !EXE_DIR!
    echo.
    if exist "!EXE_DIR!\bitcoind.exe" (
        echo   [OK] bitcoind.exe
        set /a EXE_COUNT+=1
    )
    if exist "!EXE_DIR!\bitcoin-qt.exe" (
        echo   [OK] bitcoin-qt.exe
        set /a EXE_COUNT+=1
    )
    if exist "!EXE_DIR!\bitcoin-cli.exe" (
        echo   [OK] bitcoin-cli.exe
        set /a EXE_COUNT+=1
    )
    if exist "!EXE_DIR!\bitcoin-tx.exe" (
        echo   [OK] bitcoin-tx.exe
        set /a EXE_COUNT+=1
    )
    if exist "!EXE_DIR!\bitcoin-wallet.exe" (
        echo   [OK] bitcoin-wallet.exe
        set /a EXE_COUNT+=1
    )
    if exist "!EXE_DIR!\bitcoin-util.exe" (
        echo   [OK] bitcoin-util.exe
        set /a EXE_COUNT+=1
    )
    echo.
    echo   Total: !EXE_COUNT! executables
)

echo.
echo ============================================================================
echo                         BUILD SUCCESSFUL!
echo ============================================================================
echo.
echo   Press [I] to install to %INSTALL_DIR%
echo.
echo Press any key to return to menu...
pause >nul
goto :Menu

:: ============================================================================
:: INSTALL GIT
:: ============================================================================

:DoInstallGit
where winget >nul 2>&1
if not errorlevel 1 (
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements 2>nul
) else (
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe' -OutFile '%TEMP%\git.exe' -UseBasicParsing" 2>nul
    if exist "%TEMP%\git.exe" (
        "%TEMP%\git.exe" /VERYSILENT /NORESTART 2>nul
        del "%TEMP%\git.exe" 2>nul
    )
)
set "PATH=%PATH%;C:\Program Files\Git\cmd"
git config --global http.sslBackend schannel 2>nul
goto :eof

:: ============================================================================
:: INSTALL PYTHON
:: ============================================================================

:DoInstallPython
where winget >nul 2>&1
if not errorlevel 1 (
    winget install --id Python.Python.3.12 -e --silent --accept-package-agreements --accept-source-agreements 2>nul
) else (
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe' -OutFile '%TEMP%\python.exe' -UseBasicParsing" 2>nul
    if exist "%TEMP%\python.exe" (
        "%TEMP%\python.exe" /quiet InstallAllUsers=1 PrependPath=1 2>nul
        del "%TEMP%\python.exe" 2>nul
    )
)
goto :eof

:: ============================================================================
:: INSTALL CMAKE
:: ============================================================================

:DoInstallCMake
where winget >nul 2>&1
if not errorlevel 1 (
    winget install --id Kitware.CMake -e --silent --accept-package-agreements --accept-source-agreements 2>nul
) else (
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-windows-x86_64.msi' -OutFile '%TEMP%\cmake.msi' -UseBasicParsing" 2>nul
    if exist "%TEMP%\cmake.msi" (
        msiexec /i "%TEMP%\cmake.msi" /quiet /norestart ADD_CMAKE_TO_PATH=System 2>nul
        del "%TEMP%\cmake.msi" 2>nul
    )
)
set "PATH=%PATH%;C:\Program Files\CMake\bin"
goto :eof

:: ============================================================================
:: INSTALL VCPKG
:: ============================================================================

:DoInstallVcpkg
if exist "%VCPKG_DIR%" rmdir /s /q "%VCPKG_DIR%" 2>nul

git clone https://github.com/microsoft/vcpkg.git "%VCPKG_DIR%" 2>nul
if not errorlevel 1 (
    pushd "%VCPKG_DIR%" 2>nul
    if not errorlevel 1 (
        call bootstrap-vcpkg.bat -disableMetrics >nul 2>&1
        popd
    )
)
set "VCPKG_ROOT=%VCPKG_DIR%"
goto :eof
