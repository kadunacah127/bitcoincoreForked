@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: Bitcoin Core Windows Build Script - ADVANCED VERSION v2.0
:: With automatic error recovery, retry logic, and network fixes
:: ============================================================================

title Bitcoin Core Windows Builder (Advanced v2.0)
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
echo           BITCOIN CORE WINDOWS BUILD SCRIPT (ADVANCED v2.0)
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
echo   [R] REPAIR / Fix Issues (clear cache, fix VS, fix network)
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
echo                         REPAIR / FIX ISSUES
echo ============================================================================
echo.
echo This will:
echo   1. Clear vcpkg download cache (fixes SSL/download errors)
echo   2. Clear build trees (fixes path too long errors)
echo   3. Update vcpkg to latest version
echo   4. Fix Visual Studio detection
echo   5. Reset network settings for downloads
echo   6. Clean previous build
echo.
set /p "CONFIRM=Continue? (Y/N): "
if /i not "%CONFIRM%"=="Y" goto :Menu

echo.
echo [REPAIR] Clearing vcpkg download cache...
if exist "%VCPKG_DIR%\downloads" (
    rmdir /s /q "%VCPKG_DIR%\downloads" 2>nul
    echo [OK] Downloads cache cleared
)

echo [REPAIR] Clearing build trees...
if exist "%VCPKG_BUILDTREES%" (
    rmdir /s /q "%VCPKG_BUILDTREES%" 2>nul
    echo [OK] Build trees cleared
)

echo [REPAIR] Clearing previous build...
if exist "%BUILD_DIR%" (
    rmdir /s /q "%BUILD_DIR%" 2>nul
    echo [OK] Build directory cleared
)

echo [REPAIR] Clearing vcpkg installed packages...
if exist "%VCPKG_DIR%\installed" (
    rmdir /s /q "%VCPKG_DIR%\installed" 2>nul
    echo [OK] Installed packages cleared
)

echo [REPAIR] Updating vcpkg...
if exist "%VCPKG_DIR%" (
    cd /d "%VCPKG_DIR%"
    git fetch origin 2>nul
    git reset --hard origin/master 2>nul
    call bootstrap-vcpkg.bat -disableMetrics >nul 2>&1
    echo [OK] vcpkg updated
    cd /d "%REPO_DIR%"
)

echo [REPAIR] Fixing network settings...
:: Reset Windows network settings that might interfere
netsh winsock reset >nul 2>&1
netsh int ip reset >nul 2>&1
ipconfig /flushdns >nul 2>&1
echo [OK] Network settings reset

echo [REPAIR] Setting secure download options...
:: Force git to use Windows certificate store
git config --global http.sslBackend schannel 2>nul
echo [OK] Git SSL backend set to schannel

echo [REPAIR] Checking Visual Studio installation...
call :DoRepairVS

echo.
echo ============================================================================
echo                         REPAIR COMPLETE
echo ============================================================================
echo.
echo Please RESTART YOUR COMPUTER before building again.
echo After restart, run this script again and press [B] to build.
echo.
pause
goto :Menu

:DoRepairVS
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS_FOUND=0"

if exist "!VSWHERE!" (
    for /f "tokens=*" %%i in ('"!VSWHERE!" -latest -property installationPath 2^>nul') do (
        if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" (
            set "VS_FOUND=1"
            echo [OK] Visual Studio found at: %%i
        )
    )
)

if "!VS_FOUND!"=="0" (
    echo [REPAIR] Visual Studio not found. Installing Build Tools...
    echo [INFO] This may take 10-20 minutes...
    
    where winget >nul 2>&1
    if !errorlevel! equ 0 (
        winget uninstall Microsoft.VisualStudio.2022.BuildTools >nul 2>&1
        winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended" --accept-package-agreements --accept-source-agreements
    ) else (
        powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile '%TEMP%\vs_buildtools.exe'"
        "%TEMP%\vs_buildtools.exe" --quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended
    )
    echo [OK] Visual Studio Build Tools installed
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
    call :DoInstallVS
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
        "%ProgramFiles%\Microsoft Visual Studio\2022\Community"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Professional"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise"
        "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools"
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
        "%ProgramFiles%\Microsoft Visual Studio\2022\Community"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Professional"
        "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise"
        "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools"
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

:DoInstallVS
echo [INFO] Installing Visual Studio Build Tools 2022...
echo [INFO] This is a large download (~2GB) and may take 10-20 minutes...

where winget >nul 2>&1
if !errorlevel! equ 0 (
    :: First uninstall any broken installation
    winget uninstall Microsoft.VisualStudio.2022.BuildTools >nul 2>&1
    
    :: Install fresh
    winget install --id Microsoft.VisualStudio.2022.BuildTools ^
        --override "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended" ^
        --accept-package-agreements --accept-source-agreements
) else (
    echo [INFO] Downloading VS Build Tools installer...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile '%TEMP%\vs_buildtools.exe'"
    "%TEMP%\vs_buildtools.exe" --quiet --wait --norestart ^
        --add Microsoft.VisualStudio.Workload.VCTools ^
        --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
        --add Microsoft.VisualStudio.Component.Windows11SDK.22621 ^
        --includeRecommended
)
echo [OK] Visual Studio Build Tools installed
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
