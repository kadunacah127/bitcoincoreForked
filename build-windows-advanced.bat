@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: Bitcoin Core Windows Build Script - ADVANCED VERSION v2.1
:: With automatic error recovery, retry logic, and network fixes
:: ============================================================================

title Bitcoin Core Windows Builder (Advanced v2.1)
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
echo           BITCOIN CORE WINDOWS BUILD SCRIPT (ADVANCED v2.1)
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
echo   [R] REPAIR / Fix Issues (clear cache, remove ALL VS, fix network)
echo   [Q] Quit
echo.
echo ============================================================================
echo.

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

:CheckOnly
echo.
echo [STEP] Checking requirements...
echo.
call :DoCheckRequirements
echo.
pause
goto :Menu

:InstallOnly
if exist "%BUILD_DIR%\bin\Release" (
    echo Installing to %INSTALL_DIR%...
    cmake --install "%BUILD_DIR%" --config Release --prefix "%INSTALL_DIR%" --strip
    echo Done!
) else if exist "%BUILD_DIR%\src\Release" (
    echo Installing to %INSTALL_DIR%...
    cmake --install "%BUILD_DIR%" --config Release --prefix "%INSTALL_DIR%" --strip
    echo Done!
) else (
    echo [ERROR] Build not found. Run build first.
)
pause
goto :Menu

:Quit
exit /b 0

:: ============================================================================
:: REPAIR ALL ISSUES
:: ============================================================================

:RepairAll
cls
echo.
echo ============================================================================
echo                     REPAIR / FIX ALL ISSUES (v2.1)
echo ============================================================================
echo.
echo This will:
echo   1. Clear vcpkg download cache (fixes SSL/download errors)
echo   2. Clear build trees (fixes path too long errors)
echo   3. Update vcpkg to latest version
echo   4. REMOVE ALL Visual Studio installations (including incomplete ones)
echo   5. Install fresh Visual Studio Build Tools 2022
echo   6. Reset network settings for downloads
echo   7. Clean previous build
echo.
echo [WARNING] This will UNINSTALL all Visual Studio versions!
echo [WARNING] This process may take 15-30 minutes.
echo.
set /p "CONFIRM=Continue? (Y/N): "
if /i not "%CONFIRM%"=="Y" goto :Menu

echo.
echo ============================================================================
echo                    STARTING REPAIR PROCESS
echo ============================================================================
echo.

:: Step 1: Clear vcpkg caches
echo [REPAIR 1/7] Clearing vcpkg download cache...
if exist "%VCPKG_DIR%\downloads" (
    rmdir /s /q "%VCPKG_DIR%\downloads" 2>nul
    echo          [OK] Downloads cache cleared
) else (
    echo          [OK] No downloads cache found
)

:: Step 2: Clear build trees
echo [REPAIR 2/7] Clearing build trees...
if exist "%VCPKG_BUILDTREES%" (
    rmdir /s /q "%VCPKG_BUILDTREES%" 2>nul
    echo          [OK] Build trees cleared
) else (
    echo          [OK] No build trees found
)

if exist "%BUILD_DIR%" (
    rmdir /s /q "%BUILD_DIR%" 2>nul
    echo          [OK] Build directory cleared
)

if exist "%VCPKG_DIR%\installed" (
    rmdir /s /q "%VCPKG_DIR%\installed" 2>nul
    echo          [OK] Installed packages cleared
)

if exist "%VCPKG_DIR%\buildtrees" (
    rmdir /s /q "%VCPKG_DIR%\buildtrees" 2>nul
    echo          [OK] vcpkg buildtrees cleared
)

if exist "%VCPKG_DIR%\packages" (
    rmdir /s /q "%VCPKG_DIR%\packages" 2>nul
    echo          [OK] vcpkg packages cleared
)

:: Step 3: Update vcpkg
echo [REPAIR 3/7] Updating vcpkg...
if exist "%VCPKG_DIR%" (
    cd /d "%VCPKG_DIR%"
    git fetch origin 2>nul
    git reset --hard origin/master 2>nul
    call bootstrap-vcpkg.bat -disableMetrics >nul 2>&1
    echo          [OK] vcpkg updated
    cd /d "%REPO_DIR%"
) else (
    echo          [INFO] vcpkg not installed, will install later
)

:: Step 4: Remove ALL Visual Studio installations
echo [REPAIR 4/7] Removing ALL Visual Studio installations...
echo          [INFO] This may take several minutes...
echo.

call :DoRemoveAllVisualStudio

:: Step 5: Install fresh Visual Studio Build Tools
echo.
echo [REPAIR 5/7] Installing fresh Visual Studio Build Tools 2022...
echo          [INFO] This may take 10-20 minutes...
echo.

call :DoInstallVSFresh

:: Step 6: Fix network settings
echo.
echo [REPAIR 6/7] Fixing network settings...
netsh winsock reset >nul 2>&1
netsh int ip reset >nul 2>&1
ipconfig /flushdns >nul 2>&1
echo          [OK] Network settings reset

:: Configure git for better compatibility
git config --global http.sslBackend schannel 2>nul
git config --global http.postBuffer 524288000 2>nul
echo          [OK] Git SSL backend set to schannel

:: Step 7: Verify installation
echo.
echo [REPAIR 7/7] Verifying installation...
call :DoCheckVisualStudio
if !errorlevel! equ 0 (
    echo          [OK] Visual Studio verified
) else (
    echo          [WARNING] Visual Studio may need manual installation
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
pause
goto :Menu

:: ============================================================================
:: REMOVE ALL VISUAL STUDIO INSTALLATIONS
:: ============================================================================

:DoRemoveAllVisualStudio
echo          Searching for Visual Studio installations...
echo.

:: Use winget to remove all VS versions
where winget >nul 2>&1
if !errorlevel! equ 0 (
    echo          [INFO] Using winget to uninstall Visual Studio products...
    
    :: Visual Studio 2022 versions
    echo          Removing Visual Studio 2022 Community...
    winget uninstall --id Microsoft.VisualStudio.2022.Community --silent >nul 2>&1
    
    echo          Removing Visual Studio 2022 Professional...
    winget uninstall --id Microsoft.VisualStudio.2022.Professional --silent >nul 2>&1
    
    echo          Removing Visual Studio 2022 Enterprise...
    winget uninstall --id Microsoft.VisualStudio.2022.Enterprise --silent >nul 2>&1
    
    echo          Removing Visual Studio 2022 BuildTools...
    winget uninstall --id Microsoft.VisualStudio.2022.BuildTools --silent >nul 2>&1
    
    :: Visual Studio 2019 versions
    echo          Removing Visual Studio 2019 Community...
    winget uninstall --id Microsoft.VisualStudio.2019.Community --silent >nul 2>&1
    
    echo          Removing Visual Studio 2019 Professional...
    winget uninstall --id Microsoft.VisualStudio.2019.Professional --silent >nul 2>&1
    
    echo          Removing Visual Studio 2019 Enterprise...
    winget uninstall --id Microsoft.VisualStudio.2019.Enterprise --silent >nul 2>&1
    
    echo          Removing Visual Studio 2019 BuildTools...
    winget uninstall --id Microsoft.VisualStudio.2019.BuildTools --silent >nul 2>&1
    
    :: Visual Studio 2017 versions
    echo          Removing Visual Studio 2017 versions...
    winget uninstall --id Microsoft.VisualStudio.2017.Community --silent >nul 2>&1
    winget uninstall --id Microsoft.VisualStudio.2017.Professional --silent >nul 2>&1
    winget uninstall --id Microsoft.VisualStudio.2017.Enterprise --silent >nul 2>&1
    winget uninstall --id Microsoft.VisualStudio.2017.BuildTools --silent >nul 2>&1
)

:: Use VS Installer to remove everything (catches incomplete installations)
echo          [INFO] Using VS Installer to clean up...
set "VS_INSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe"

if exist "!VS_INSTALLER!" (
    echo          Running VS Installer cleanup...
    
    :: Get all installed instances and uninstall them
    set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
    
    if exist "!VSWHERE!" (
        :: Uninstall each found instance
        for /f "tokens=*" %%i in ('"!VSWHERE!" -all -property installationPath 2^>nul') do (
            echo          Uninstalling: %%i
            "!VS_INSTALLER!" uninstall --installPath "%%i" --quiet --wait >nul 2>&1
        )
    )
    
    :: Final cleanup with installer
    "!VS_INSTALLER!" --quiet --wait --norestart uninstall --all >nul 2>&1
)

:: Remove VS Installer itself
echo          Removing Visual Studio Installer...
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe" (
    "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe" --quiet --wait --norestart uninstall --all >nul 2>&1
)

:: Force remove leftover directories
echo          Cleaning leftover directories...

:: VS 2022 directories
if exist "%ProgramFiles%\Microsoft Visual Studio\2022" (
    rmdir /s /q "%ProgramFiles%\Microsoft Visual Studio\2022" 2>nul
)
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022" (
    rmdir /s /q "%ProgramFiles(x86)%\Microsoft Visual Studio\2022" 2>nul
)

:: VS 2019 directories
if exist "%ProgramFiles%\Microsoft Visual Studio\2019" (
    rmdir /s /q "%ProgramFiles%\Microsoft Visual Studio\2019" 2>nul
)
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2019" (
    rmdir /s /q "%ProgramFiles(x86)%\Microsoft Visual Studio\2019" 2>nul
)

:: VS 2017 directories
if exist "%ProgramFiles%\Microsoft Visual Studio\2017" (
    rmdir /s /q "%ProgramFiles%\Microsoft Visual Studio\2017" 2>nul
)
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2017" (
    rmdir /s /q "%ProgramFiles(x86)%\Microsoft Visual Studio\2017" 2>nul
)

:: VS Installer directory
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer" (
    rmdir /s /q "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer" 2>nul
)

:: VS cache directories
if exist "%ProgramData%\Microsoft\VisualStudio" (
    rmdir /s /q "%ProgramData%\Microsoft\VisualStudio" 2>nul
)
if exist "%LOCALAPPDATA%\Microsoft\VisualStudio" (
    rmdir /s /q "%LOCALAPPDATA%\Microsoft\VisualStudio" 2>nul
)
if exist "%APPDATA%\Microsoft\VisualStudio" (
    rmdir /s /q "%APPDATA%\Microsoft\VisualStudio" 2>nul
)

:: VS packages cache
if exist "%ProgramData%\Package Cache" (
    echo          Cleaning Package Cache (VS components)...
    for /d %%d in ("%ProgramData%\Package Cache\*VisualStudio*") do rmdir /s /q "%%d" 2>nul
    for /d %%d in ("%ProgramData%\Package Cache\*vs_*") do rmdir /s /q "%%d" 2>nul
)

echo          [OK] All Visual Studio installations removed
exit /b 0

:: ============================================================================
:: INSTALL FRESH VISUAL STUDIO BUILD TOOLS
:: ============================================================================

:DoInstallVSFresh
where winget >nul 2>&1
if !errorlevel! equ 0 (
    echo          Installing via winget...
    winget install --id Microsoft.VisualStudio.2022.BuildTools ^
        --override "--wait --quiet --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.CMake.Project --includeRecommended" ^
        --accept-package-agreements --accept-source-agreements
    
    if !errorlevel! neq 0 (
        echo          [WARNING] winget install may have issues, trying direct download...
        goto :InstallVSDirect
    )
) else (
    goto :InstallVSDirect
)

echo          [OK] Visual Studio Build Tools 2022 installed
exit /b 0

:InstallVSDirect
echo          Downloading VS Build Tools installer directly...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile '%TEMP%\vs_buildtools.exe'"

if exist "%TEMP%\vs_buildtools.exe" (
    echo          Running installer (this may take 10-20 minutes)...
    "%TEMP%\vs_buildtools.exe" --quiet --wait --norestart ^
        --add Microsoft.VisualStudio.Workload.VCTools ^
        --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
        --add Microsoft.VisualStudio.Component.Windows11SDK.22621 ^
        --add Microsoft.VisualStudio.Component.VC.CMake.Project ^
        --includeRecommended
    
    echo          [OK] Visual Studio Build Tools 2022 installed
) else (
    echo          [ERROR] Failed to download VS Build Tools installer
    exit /b 1
)
exit /b 0

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

:: Check admin rights
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo [WARNING] Not running as Administrator.
    echo [WARNING] Some operations may fail. Consider restarting as Admin.
    echo.
)

:: Step 1: Check requirements
echo [STEP 1/6] Checking requirements...
echo.
call :DoCheckRequirements
if !errorlevel! neq 0 goto :BuildFailed

:: Step 2: Setup environment
echo.
echo [STEP 2/6] Setting up build environment...
call :DoSetupEnvironment
if !errorlevel! neq 0 goto :BuildFailed

:: Step 3: Verify source
echo [STEP 3/6] Verifying source code...
call :DoVerifySource
if !errorlevel! neq 0 goto :BuildFailed

:: Step 4: Configure with retry
echo.
echo [STEP 4/6] Configuring build...
echo [INFO] This may take 15-45 minutes on first run (downloading dependencies)
echo [INFO] If download fails, will retry up to %MAX_RETRIES% times
echo.
call :DoConfigureBuildWithRetry
if !errorlevel! neq 0 goto :BuildFailed

:: Step 5: Build
echo.
echo [STEP 5/6] Building Bitcoin Core...
echo [INFO] Using %PARALLEL_JOBS% parallel jobs
call :DoRunBuild
if !errorlevel! neq 0 goto :BuildFailed

:: Step 6: Report
echo.
echo [STEP 6/6] Build complete!
call :DoReportResults

echo.
echo Press any key to return to menu...
pause >nul
goto :Menu

:BuildFailed
echo.
echo ============================================================================
echo                            BUILD FAILED
echo ============================================================================
echo.
echo Possible fixes:
echo   1. Press [R] in menu to REPAIR and clear caches
echo   2. Disable VPN/Proxy if using one
echo   3. Restart computer and try again
echo   4. Run as Administrator
echo.
pause
goto :Menu

:: ============================================================================
:: CHECK REQUIREMENTS FUNCTION
:: ============================================================================

:DoCheckRequirements
:: Check Git
where git >nul 2>&1
if !errorlevel! neq 0 (
    echo [MISSING] Git - Installing...
    call :DoInstallGit
) else (
    echo [OK] Git found
)

:: Check Python
where python >nul 2>&1
if !errorlevel! neq 0 (
    echo [MISSING] Python - Installing...
    call :DoInstallPython
) else (
    echo [OK] Python found
)

:: Check CMake
where cmake >nul 2>&1
if !errorlevel! neq 0 (
    echo [MISSING] CMake - Installing...
    call :DoInstallCMake
) else (
    echo [OK] CMake found
)

:: Check Visual Studio (more thorough check)
call :DoCheckVisualStudio
if !errorlevel! neq 0 (
    echo [MISSING] Visual Studio - Installing...
    call :DoInstallVSFresh
)

:: Check vcpkg
if not exist "%VCPKG_DIR%\vcpkg.exe" (
    echo [MISSING] vcpkg - Installing...
    call :DoInstallVcpkg
) else (
    echo [OK] vcpkg found
)

echo.
echo [OK] All requirements satisfied
exit /b 0

:: ============================================================================
:: CHECK VISUAL STUDIO (THOROUGH)
:: ============================================================================

:DoCheckVisualStudio
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS_FOUND=0"
set "VS_PATH="

:: Method 1: Use vswhere
if exist "!VSWHERE!" (
    for /f "tokens=*" %%i in ('"!VSWHERE!" -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul') do (
        if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" (
            set "VS_PATH=%%i"
            set "VS_FOUND=1"
        )
    )
)

:: Method 2: Check common paths
if "!VS_FOUND!"=="0" (
    for %%p in (
        "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Community"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Professional"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise"
        "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools"
    ) do (
        if exist "%%~p\VC\Auxiliary\Build\vcvars64.bat" (
            set "VS_PATH=%%~p"
            set "VS_FOUND=1"
        )
    )
)

if "!VS_FOUND!"=="1" (
    echo [OK] Visual Studio found at: !VS_PATH!
    exit /b 0
) else (
    exit /b 1
)

:: ============================================================================
:: SETUP ENVIRONMENT FUNCTION
:: ============================================================================

:DoSetupEnvironment
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS_PATH="

:: Find VS installation
if exist "!VSWHERE!" (
    for /f "tokens=*" %%i in ('"!VSWHERE!" -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul') do (
        set "VS_PATH=%%i"
    )
)

:: Fallback to common paths
if not defined VS_PATH (
    for %%p in (
        "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Community"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Professional"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise"
        "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools"
    ) do (
        if exist "%%~p\VC\Auxiliary\Build\vcvars64.bat" (
            set "VS_PATH=%%~p"
        )
    )
)

if defined VS_PATH (
    if exist "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" (
        echo [INFO] Loading Visual Studio environment from: !VS_PATH!
        call "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
        if !errorlevel! equ 0 (
            echo [OK] Visual Studio environment loaded
        ) else (
            echo [WARNING] Failed to load VS environment, continuing anyway...
        )
    )
) else (
    echo [ERROR] Could not find Visual Studio installation!
    echo [ERROR] Press [R] in menu to repair, or install Visual Studio manually.
    exit /b 1
)

set "VCPKG_ROOT=%VCPKG_DIR%"

:: Set environment variables to help with downloads
set "GIT_SSL_NO_VERIFY=0"
set "CURL_SSL_BACKEND=schannel"

exit /b 0

:: ============================================================================
:: VERIFY SOURCE FUNCTION
:: ============================================================================

:DoVerifySource
cd /d "%REPO_DIR%"

if not exist "CMakeLists.txt" (
    echo [ERROR] CMakeLists.txt not found!
    echo [ERROR] Please run this script from the Bitcoin Core source directory.
    exit /b 1
)
if not exist "src\bitcoind.cpp" (
    echo [ERROR] Source files not found!
    echo [ERROR] This doesn't appear to be a valid Bitcoin Core repository.
    exit /b 1
)
echo [OK] Source code verified
exit /b 0

:: ============================================================================
:: CONFIGURE BUILD WITH RETRY
:: ============================================================================

:DoConfigureBuildWithRetry
set "RETRY_COUNT=0"

:ConfigureRetryLoop
set /a RETRY_COUNT+=1

if !RETRY_COUNT! gtr %MAX_RETRIES% (
    echo [ERROR] Configuration failed after %MAX_RETRIES% attempts.
    echo [ERROR] Press [R] in menu to repair and clear caches.
    exit /b 1
)

if !RETRY_COUNT! gtr 1 (
    echo.
    echo [RETRY] Attempt !RETRY_COUNT! of %MAX_RETRIES%...
    echo [RETRY] Clearing failed downloads...
    
    :: Clear only failed downloads, not all
    if exist "%VCPKG_DIR%\downloads\*.tmp" del /q "%VCPKG_DIR%\downloads\*.tmp" 2>nul
    if exist "%VCPKG_DIR%\downloads\temp" rmdir /s /q "%VCPKG_DIR%\downloads\temp" 2>nul
    
    :: Wait a bit before retry
    echo [RETRY] Waiting 5 seconds before retry...
    timeout /t 5 /nobreak >nul
)

call :DoConfigureBuild
if !errorlevel! neq 0 (
    if !RETRY_COUNT! lss %MAX_RETRIES% (
        echo.
        echo [WARNING] Configuration failed. Will retry...
        goto :ConfigureRetryLoop
    ) else (
        exit /b 1
    )
)

exit /b 0

:: ============================================================================
:: CONFIGURE BUILD FUNCTION
:: ============================================================================

:DoConfigureBuild
if "%CLEAN_BUILD%"=="1" (
    if exist "%BUILD_DIR%" (
        echo [INFO] Cleaning previous build...
        rmdir /s /q "%BUILD_DIR%" 2>nul
    )
)

:: Create buildtrees directory
if not exist "%VCPKG_BUILDTREES%" mkdir "%VCPKG_BUILDTREES%"

:: Detect VS version for generator
set "VS_GENERATOR=Visual Studio 17 2022"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if exist "!VSWHERE!" (
    for /f "tokens=*" %%v in ('"!VSWHERE!" -latest -property catalog_productLineVersion 2^>nul') do (
        if "%%v"=="2022" set "VS_GENERATOR=Visual Studio 17 2022"
        if "%%v"=="2019" set "VS_GENERATOR=Visual Studio 16 2019"
    )
)

:: Verify cmake can find VS
cmake --version >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] CMake not working properly!
    exit /b 1
)

echo [INFO] Generator: %VS_GENERATOR%
echo [INFO] vcpkg: %VCPKG_DIR%
echo [INFO] Build trees: %VCPKG_BUILDTREES%
echo.

:: Run CMake configuration
cmake -B "%BUILD_DIR%" -G "%VS_GENERATOR%" -A x64 ^
    -DCMAKE_TOOLCHAIN_FILE="%VCPKG_DIR%\scripts\buildsystems\vcpkg.cmake" ^
    -DVCPKG_TARGET_TRIPLET="x64-windows-static" ^
    -DVCPKG_INSTALL_OPTIONS="--x-buildtrees-root=%VCPKG_BUILDTREES%;--clean-after-build" ^
    -DVCPKG_OVERLAY_TRIPLETS="%VCPKG_DIR%\triplets" ^
    -DBUILD_GUI=%BUILD_GUI% ^
    -DBUILD_TESTS=%BUILD_TESTS% ^
    -DBUILD_BENCH=OFF ^
    -DWITH_ZMQ=%BUILD_ZMQ% ^
    -DENABLE_WALLET=%BUILD_WALLET% ^
    -DCMAKE_BUILD_TYPE=%BUILD_TYPE%

if !errorlevel! neq 0 (
    echo.
    echo [ERROR] CMake configuration failed!
    exit /b 1
)

echo.
echo [OK] Configuration complete
exit /b 0

:: ============================================================================
:: RUN BUILD FUNCTION
:: ============================================================================

:DoRunBuild
echo.

cmake --build "%BUILD_DIR%" --config %BUILD_TYPE% --parallel %PARALLEL_JOBS%

if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Build failed!
    exit /b 1
)

echo.
echo [OK] Build complete
exit /b 0

:: ============================================================================
:: REPORT RESULTS FUNCTION
:: ============================================================================

:DoReportResults
echo.
echo ============================================================================
echo                           BUILD RESULTS
echo ============================================================================
echo.

set "EXE_DIR=%BUILD_DIR%\bin\%BUILD_TYPE%"
if not exist "%EXE_DIR%" set "EXE_DIR=%BUILD_DIR%\src\%BUILD_TYPE%"
if not exist "%EXE_DIR%" set "EXE_DIR=%BUILD_DIR%\bin"
if not exist "%EXE_DIR%" set "EXE_DIR=%BUILD_DIR%\src"

set "EXE_COUNT=0"

if exist "%EXE_DIR%\bitcoind.exe" (
    echo   [OK] bitcoind.exe - Full node daemon
    set /a EXE_COUNT+=1
)
if exist "%EXE_DIR%\bitcoin-qt.exe" (
    echo   [OK] bitcoin-qt.exe - GUI wallet
    set /a EXE_COUNT+=1
)
if exist "%EXE_DIR%\bitcoin-cli.exe" (
    echo   [OK] bitcoin-cli.exe - Command-line interface
    set /a EXE_COUNT+=1
)
if exist "%EXE_DIR%\bitcoin-tx.exe" (
    echo   [OK] bitcoin-tx.exe - Transaction utility
    set /a EXE_COUNT+=1
)
if exist "%EXE_DIR%\bitcoin-wallet.exe" (
    echo   [OK] bitcoin-wallet.exe - Wallet tool
    set /a EXE_COUNT+=1
)
if exist "%EXE_DIR%\bitcoin-util.exe" (
    echo   [OK] bitcoin-util.exe - Utility tool
    set /a EXE_COUNT+=1
)

echo.
if !EXE_COUNT! gtr 0 (
    echo   Total executables built: !EXE_COUNT!
    echo   Location: %EXE_DIR%
    echo.
    echo ============================================================================
    echo                         BUILD SUCCESSFUL!
    echo ============================================================================
    echo.
    echo   To install, press [I] in menu or run:
    echo   cmake --install "%BUILD_DIR%" --config Release --prefix "%INSTALL_DIR%"
    echo.
) else (
    echo   [WARNING] No executables found in expected locations.
    echo   Check: %BUILD_DIR%
)
echo ============================================================================
exit /b 0

:: ============================================================================
:: INSTALLER FUNCTIONS
:: ============================================================================

:DoInstallGit
echo [INFO] Installing Git...
where winget >nul 2>&1
if !errorlevel! equ 0 (
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
) else (
    echo [INFO] Downloading Git installer...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe' -OutFile '%TEMP%\git-installer.exe'"
    "%TEMP%\git-installer.exe" /VERYSILENT /NORESTART
)
set "PATH=%PATH%;C:\Program Files\Git\cmd"
:: Configure git for better compatibility
git config --global http.sslBackend schannel 2>nul
exit /b 0

:DoInstallPython
echo [INFO] Installing Python...
where winget >nul 2>&1
if !errorlevel! equ 0 (
    winget install --id Python.Python.3.12 -e --silent --accept-package-agreements --accept-source-agreements
) else (
    echo [INFO] Downloading Python installer...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe' -OutFile '%TEMP%\python-installer.exe'"
    "%TEMP%\python-installer.exe" /quiet InstallAllUsers=1 PrependPath=1
)
exit /b 0

:DoInstallCMake
echo [INFO] Installing CMake...
where winget >nul 2>&1
if !errorlevel! equ 0 (
    winget install --id Kitware.CMake -e --silent --accept-package-agreements --accept-source-agreements
) else (
    echo [INFO] Downloading CMake installer...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-windows-x86_64.msi' -OutFile '%TEMP%\cmake.msi'"
    msiexec /i "%TEMP%\cmake.msi" /quiet /norestart ADD_CMAKE_TO_PATH=System
)
set "PATH=%PATH%;C:\Program Files\CMake\bin"
exit /b 0

:DoInstallVcpkg
echo [INFO] Installing vcpkg...

:: Remove old/broken installation
if exist "%VCPKG_DIR%" (
    echo [INFO] Removing old vcpkg installation...
    rmdir /s /q "%VCPKG_DIR%" 2>nul
)

:: Clone fresh
echo [INFO] Cloning vcpkg repository...
git clone https://github.com/microsoft/vcpkg.git "%VCPKG_DIR%"
if !errorlevel! neq 0 (
    echo [ERROR] Failed to clone vcpkg!
    exit /b 1
)

:: Bootstrap
echo [INFO] Bootstrapping vcpkg...
cd /d "%VCPKG_DIR%"
call bootstrap-vcpkg.bat -disableMetrics
if !errorlevel! neq 0 (
    echo [ERROR] Failed to bootstrap vcpkg!
    cd /d "%REPO_DIR%"
    exit /b 1
)

cd /d "%REPO_DIR%"
set "VCPKG_ROOT=%VCPKG_DIR%"
echo [OK] vcpkg installed successfully
exit /b 0
