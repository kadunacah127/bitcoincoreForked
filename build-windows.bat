@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: Bitcoin Core Windows Build Script
:: Automatically checks requirements, installs missing dependencies, and builds
:: ============================================================================

title Bitcoin Core Windows Builder
color 0A

echo.
echo ============================================================================
echo                    BITCOIN CORE WINDOWS BUILD SCRIPT
echo ============================================================================
echo.

:: Configuration
set "REPO_DIR=%~dp0"
set "VCPKG_DIR=C:\vcpkg"
set "BUILD_DIR=%REPO_DIR%build"
set "INSTALL_DIR=C:\Bitcoin"
set "BUILD_GUI=OFF"
set "BUILD_TESTS=OFF"
set "PARALLEL_JOBS=8"

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Not running as Administrator. Some installations may fail.
    echo [INFO] Right-click this script and select "Run as administrator"
    echo.
    pause
)

:: ============================================================================
:: STEP 1: Check and Install Requirements
:: ============================================================================

echo [STEP 1/6] Checking requirements...
echo.

:: Check Windows version
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo [INFO] Windows Version: %VERSION%

:: ----------------------------------------------------------------------------
:: Check/Install Git
:: ----------------------------------------------------------------------------
echo [CHECK] Git...
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [MISSING] Git not found. Installing...
    call :InstallGit
) else (
    for /f "tokens=3" %%v in ('git --version') do echo [OK] Git %%v found
)

:: ----------------------------------------------------------------------------
:: Check/Install Python
:: ----------------------------------------------------------------------------
echo [CHECK] Python...
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [MISSING] Python not found. Installing...
    call :InstallPython
) else (
    for /f "tokens=2" %%v in ('python --version 2^>^&1') do echo [OK] Python %%v found
)

:: ----------------------------------------------------------------------------
:: Check/Install CMake
:: ----------------------------------------------------------------------------
echo [CHECK] CMake...
where cmake >nul 2>&1
if %errorlevel% neq 0 (
    echo [MISSING] CMake not found. Installing...
    call :InstallCMake
) else (
    for /f "tokens=3" %%v in ('cmake --version ^| findstr /i "cmake version"') do echo [OK] CMake %%v found
)

:: ----------------------------------------------------------------------------
:: Check/Install Visual Studio Build Tools
:: ----------------------------------------------------------------------------
echo [CHECK] Visual Studio / Build Tools...
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS_FOUND=0"

if exist "%VSWHERE%" (
    for /f "tokens=*" %%i in ('"%VSWHERE%" -latest -property installationPath 2^>nul') do (
        if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" (
            set "VS_PATH=%%i"
            set "VS_FOUND=1"
            echo [OK] Visual Studio found at: %%i
        )
    )
)

if "%VS_FOUND%"=="0" (
    echo [MISSING] Visual Studio Build Tools not found. Installing...
    call :InstallVS
)

:: ----------------------------------------------------------------------------
:: Check/Setup vcpkg
:: ----------------------------------------------------------------------------
echo [CHECK] vcpkg...
if not exist "%VCPKG_DIR%\vcpkg.exe" (
    echo [MISSING] vcpkg not found. Installing...
    call :InstallVcpkg
) else (
    echo [OK] vcpkg found at %VCPKG_DIR%
)

echo.
echo [STEP 1/6] Requirements check complete!
echo.

:: ============================================================================
:: STEP 2: Setup Build Environment
:: ============================================================================

echo [STEP 2/6] Setting up build environment...

:: Find and setup VS environment
if exist "%VSWHERE%" (
    for /f "tokens=*" %%i in ('"%VSWHERE%" -latest -property installationPath 2^>nul') do (
        set "VS_PATH=%%i"
    )
)

if defined VS_PATH (
    if exist "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" (
        echo [INFO] Loading Visual Studio environment...
        call "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
    )
)

:: Set vcpkg environment
set "VCPKG_ROOT=%VCPKG_DIR%"
set "PATH=%VCPKG_DIR%;%PATH%"

echo [OK] Build environment ready
echo.

:: ============================================================================
:: STEP 3: Verify Source Code
:: ============================================================================

echo [STEP 3/6] Verifying source code...

cd /d "%REPO_DIR%"

if not exist "CMakeLists.txt" (
    echo [ERROR] CMakeLists.txt not found!
    echo [ERROR] Please run this script from the Bitcoin Core source directory.
    goto :Error
)

if not exist "src\bitcoind.cpp" (
    echo [ERROR] Source files not found!
    echo [ERROR] This doesn't appear to be a valid Bitcoin Core repository.
    goto :Error
)

echo [OK] Source code verified
echo.

:: ============================================================================
:: STEP 4: Configure Build
:: ============================================================================

echo [STEP 4/6] Configuring build...
echo [INFO] This may take 15-45 minutes on first run (downloading dependencies)
echo.

:: Clean previous build if exists
if exist "%BUILD_DIR%" (
    echo [INFO] Cleaning previous build...
    rmdir /s /q "%BUILD_DIR%" 2>nul
)

:: Determine Visual Studio version
set "VS_GENERATOR=Visual Studio 17 2022"
if exist "%VSWHERE%" (
    for /f "tokens=1" %%v in ('"%VSWHERE%" -latest -property catalog_productLineVersion 2^>nul') do (
        if "%%v"=="2022" set "VS_GENERATOR=Visual Studio 17 2022"
        if "%%v"=="2019" set "VS_GENERATOR=Visual Studio 16 2019"
    )
)

echo [INFO] Using generator: %VS_GENERATOR%
echo [INFO] Build GUI: %BUILD_GUI%
echo [INFO] Build Tests: %BUILD_TESTS%
echo.

:: Configure with CMake
cmake -B "%BUILD_DIR%" -G "%VS_GENERATOR%" -A x64 ^
    -DCMAKE_TOOLCHAIN_FILE="%VCPKG_DIR%\scripts\buildsystems\vcpkg.cmake" ^
    -DVCPKG_TARGET_TRIPLET="x64-windows-static" ^
    -DVCPKG_INSTALL_OPTIONS="--x-buildtrees-root=C:\vbt" ^
    -DBUILD_GUI=%BUILD_GUI% ^
    -DBUILD_TESTS=%BUILD_TESTS% ^
    -DBUILD_BENCH=OFF ^
    -DWITH_ZMQ=OFF ^
    -DENABLE_WALLET=ON

if %errorlevel% neq 0 (
    echo [ERROR] CMake configuration failed!
    goto :Error
)

echo.
echo [OK] Configuration complete
echo.

:: ============================================================================
:: STEP 5: Build
:: ============================================================================

echo [STEP 5/6] Building Bitcoin Core...
echo [INFO] Using %PARALLEL_JOBS% parallel jobs
echo [INFO] This may take 15-60 minutes depending on your system
echo.

cmake --build "%BUILD_DIR%" --config Release --parallel %PARALLEL_JOBS%

if %errorlevel% neq 0 (
    echo [ERROR] Build failed!
    goto :Error
)

echo.
echo [OK] Build complete!
echo.

:: ============================================================================
:: STEP 6: Verify and Report
:: ============================================================================

echo [STEP 6/6] Verifying build output...
echo.

set "EXE_COUNT=0"
set "EXE_DIR=%BUILD_DIR%\bin\Release"

if not exist "%EXE_DIR%" set "EXE_DIR=%BUILD_DIR%\src\Release"

echo [INFO] Looking for executables in: %EXE_DIR%
echo.

if exist "%EXE_DIR%\bitcoind.exe" (
    echo [OK] bitcoind.exe - Full node daemon
    set /a EXE_COUNT+=1
)
if exist "%EXE_DIR%\bitcoin-cli.exe" (
    echo [OK] bitcoin-cli.exe - Command-line interface
    set /a EXE_COUNT+=1
)
if exist "%EXE_DIR%\bitcoin-tx.exe" (
    echo [OK] bitcoin-tx.exe - Transaction utility
    set /a EXE_COUNT+=1
)
if exist "%EXE_DIR%\bitcoin-wallet.exe" (
    echo [OK] bitcoin-wallet.exe - Wallet tool
    set /a EXE_COUNT+=1
)
if exist "%EXE_DIR%\bitcoin-util.exe" (
    echo [OK] bitcoin-util.exe - Utility tool
    set /a EXE_COUNT+=1
)
if exist "%EXE_DIR%\bitcoin-qt.exe" (
    echo [OK] bitcoin-qt.exe - GUI wallet
    set /a EXE_COUNT+=1
)

echo.
if %EXE_COUNT% gtr 0 (
    echo ============================================================================
    echo                         BUILD SUCCESSFUL!
    echo ============================================================================
    echo.
    echo   Executables built: %EXE_COUNT%
    echo   Location: %EXE_DIR%
    echo.
    echo   To install to %INSTALL_DIR%, run:
    echo   cmake --install "%BUILD_DIR%" --config Release --prefix "%INSTALL_DIR%" --strip
    echo.
    echo ============================================================================
) else (
    echo [WARNING] No executables found. Check build output above for errors.
)

goto :End

:: ============================================================================
:: INSTALLATION FUNCTIONS
:: ============================================================================

:InstallGit
echo [INSTALL] Downloading Git...
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
) else (
    echo [INFO] Downloading Git installer...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe' -OutFile '%TEMP%\git-installer.exe'"
    echo [INFO] Installing Git (please follow the installer)...
    "%TEMP%\git-installer.exe" /VERYSILENT /NORESTART
)
:: Refresh PATH
set "PATH=%PATH%;C:\Program Files\Git\cmd"
goto :eof

:InstallPython
echo [INSTALL] Downloading Python...
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget install --id Python.Python.3.12 -e --silent --accept-package-agreements --accept-source-agreements
) else (
    echo [INFO] Downloading Python installer...
    powershell -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe' -OutFile '%TEMP%\python-installer.exe'"
    echo [INFO] Installing Python...
    "%TEMP%\python-installer.exe" /quiet InstallAllUsers=1 PrependPath=1
)
:: Refresh PATH
set "PATH=%PATH%;C:\Python312;C:\Python312\Scripts"
goto :eof

:InstallCMake
echo [INSTALL] Downloading CMake...
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget install --id Kitware.CMake -e --silent --accept-package-agreements --accept-source-agreements
) else (
    echo [INFO] Downloading CMake installer...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-windows-x86_64.msi' -OutFile '%TEMP%\cmake-installer.msi'"
    echo [INFO] Installing CMake...
    msiexec /i "%TEMP%\cmake-installer.msi" /quiet /norestart ADD_CMAKE_TO_PATH=System
)
:: Refresh PATH
set "PATH=%PATH%;C:\Program Files\CMake\bin"
goto :eof

:InstallVS
echo [INSTALL] Downloading Visual Studio Build Tools...
echo [INFO] This is a large download (~2GB) and may take a while...
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended" --accept-package-agreements --accept-source-agreements
) else (
    echo [INFO] Downloading VS Build Tools installer...
    powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile '%TEMP%\vs_buildtools.exe'"
    echo [INFO] Installing Visual Studio Build Tools (this may take 10-20 minutes)...
    "%TEMP%\vs_buildtools.exe" --quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended
)
goto :eof

:InstallVcpkg
echo [INSTALL] Setting up vcpkg...
if not exist "%VCPKG_DIR%" (
    git clone https://github.com/microsoft/vcpkg.git "%VCPKG_DIR%"
)
cd /d "%VCPKG_DIR%"
call bootstrap-vcpkg.bat -disableMetrics
cd /d "%REPO_DIR%"
set "VCPKG_ROOT=%VCPKG_DIR%"
goto :eof

:Error
echo.
echo ============================================================================
echo                            BUILD FAILED
echo ============================================================================
echo.
echo Please check the error messages above.
echo.
echo Common fixes:
echo   1. Run this script as Administrator
echo   2. Ensure you have at least 20GB free disk space
echo   3. Add this folder to Windows Defender exclusions
echo   4. Check your internet connection
echo.
pause
exit /b 1

:End
echo.
echo Press any key to exit...
pause >nul
exit /b 0
