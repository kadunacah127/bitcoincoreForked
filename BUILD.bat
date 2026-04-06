@echo off
setlocal

:: ============================================================================
:: Bitcoin Core Windows Build Script - v4.0 (Network/SSL Fixes)
:: ============================================================================

title Bitcoin Core Builder v4.0
color 0A

echo.
echo ============================================================================
echo                    BITCOIN CORE WINDOWS BUILD v4.0
echo                        (With Network/SSL Fixes)
echo ============================================================================
echo.

:: Get the directory where this script is located
set "SOURCE_DIR=%~dp0"
set "SOURCE_DIR=%SOURCE_DIR:~0,-1%"
set "BUILD_DIR=%SOURCE_DIR%\build"
set "VCPKG_DIR=C:\vcpkg"

echo [INFO] Source: %SOURCE_DIR%
echo [INFO] Build:  %BUILD_DIR%
echo.

:: ============================================================================
:: STEP 0: Fix Network/SSL Issues
:: ============================================================================
echo [STEP 0/4] Fixing network and SSL settings...

:: Configure Git to use Windows certificate store (fixes SSL errors)
git config --global http.sslBackend schannel
git config --global http.postBuffer 524288000
git config --global core.longpaths true

:: Clear any proxy settings that might interfere
set "HTTP_PROXY="
set "HTTPS_PROXY="
set "ALL_PROXY="
set "NO_PROXY="

:: Set Windows to handle SSL
set "GIT_SSL_NO_VERIFY=false"
set "CURL_SSL_BACKEND=schannel"

:: Reset network
ipconfig /flushdns >nul 2>&1

echo [OK] Network settings configured
echo.

:: ============================================================================
:: STEP 1: Load Visual Studio FIRST
:: ============================================================================
echo [STEP 1/4] Loading Visual Studio environment...

set "VS_VCVARS="

for %%p in (
    "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
) do (
    if exist "%%~p" set "VS_VCVARS=%%~p"
)

if not defined VS_VCVARS (
    echo [ERROR] Visual Studio 2022 not found!
    goto :failed
)

:: Load VS environment
call "%VS_VCVARS%" x64 >nul 2>&1

:: Return to source directory
cd /d "%SOURCE_DIR%"

:: Verify VS is loaded by checking for cl.exe
where cl.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Visual Studio environment not loaded properly
    goto :failed
)

echo [OK] Visual Studio 2022 loaded
echo.

:: ============================================================================
:: STEP 2: Update and Fix vcpkg
:: ============================================================================
echo [STEP 2/4] Preparing vcpkg...

cd /d "%VCPKG_DIR%"

:: Update vcpkg
echo         Updating vcpkg...
git pull 2>nul

:: Re-bootstrap to ensure it's working
echo         Bootstrapping vcpkg...
call bootstrap-vcpkg.bat -disableMetrics >nul 2>&1

:: Clear ALL caches to start fresh
echo         Clearing all caches...
if exist "%VCPKG_DIR%\buildtrees" rmdir /s /q "%VCPKG_DIR%\buildtrees" 2>nul
if exist "%VCPKG_DIR%\downloads" rmdir /s /q "%VCPKG_DIR%\downloads" 2>nul
if exist "%VCPKG_DIR%\packages" rmdir /s /q "%VCPKG_DIR%\packages" 2>nul
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%" 2>nul

:: Return to source
cd /d "%SOURCE_DIR%"

echo [OK] vcpkg ready
echo.

:: ============================================================================
:: STEP 3: Configure
:: ============================================================================
echo [STEP 3/4] Configuring build...
echo.
echo         NOTE: This downloads dependencies and may take 30-60 minutes.
echo         If downloads fail, the script will show troubleshooting steps.
echo.

:: Set vcpkg environment
set "VCPKG_ROOT=%VCPKG_DIR%"

:: Run CMake
cmake -S "%SOURCE_DIR%" -B "%BUILD_DIR%" -G "Visual Studio 17 2022" -A x64 -DCMAKE_TOOLCHAIN_FILE="%VCPKG_DIR%/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-windows-static -DBUILD_GUI=OFF -DBUILD_TESTS=OFF -DBUILD_BENCH=OFF -DWITH_ZMQ=OFF -DENABLE_WALLET=ON

if errorlevel 1 (
    echo.
    echo [ERROR] Configuration failed - likely a download error
    echo.
    goto :network_help
)

echo.
echo [OK] Configuration complete
echo.

:: ============================================================================
:: STEP 4: Build
:: ============================================================================
echo [STEP 4/4] Building Bitcoin Core...
echo         This takes 15-30 minutes...
echo.

cmake --build "%BUILD_DIR%" --config Release --parallel 8

if errorlevel 1 (
    echo.
    echo [ERROR] Build failed
    goto :failed
)

:: ============================================================================
:: SUCCESS
:: ============================================================================
echo.
echo ============================================================================
echo                         BUILD SUCCESSFUL!
echo ============================================================================
echo.

if exist "%BUILD_DIR%\src\Release\bitcoind.exe" (
    echo Executables location: %BUILD_DIR%\src\Release\
    echo.
    dir /b "%BUILD_DIR%\src\Release\*.exe" 2>nul
) else (
    echo Executables location: %BUILD_DIR%\bin\Release\
    echo.
    dir /b "%BUILD_DIR%\bin\Release\*.exe" 2>nul
)

echo.
echo ============================================================================
goto :end

:: ============================================================================
:: NETWORK TROUBLESHOOTING
:: ============================================================================
:network_help
echo ============================================================================
echo                    DOWNLOAD/NETWORK ERROR
echo ============================================================================
echo.
echo The build failed because vcpkg could not download packages.
echo.
echo TRY THESE FIXES:
echo.
echo 1. DISABLE VPN - If you're using a VPN, turn it off and retry
echo.
echo 2. DISABLE PROXY - Run these commands in Admin CMD:
echo    set HTTP_PROXY=
echo    set HTTPS_PROXY=
echo    netsh winhttp reset proxy
echo.
echo 3. DISABLE ANTIVIRUS - Temporarily disable Windows Defender or
echo    your antivirus, then retry
echo.
echo 4. USE MOBILE HOTSPOT - Connect to phone hotspot instead of 
echo    current network, then retry
echo.
echo 5. CHANGE DNS - Use Google DNS:
echo    - Open Network Settings
echo    - Change adapter settings
echo    - Properties ^> IPv4 ^> Use DNS: 8.8.8.8 and 8.8.4.4
echo.
echo 6. MANUAL RETRY - Sometimes just running again works:
echo    Close this window and run BUILD.bat again
echo.
echo ============================================================================
goto :end

:failed
echo.
echo ============================================================================
echo                           BUILD FAILED
echo ============================================================================
echo.

:end
echo.
echo Press any key to exit...
pause >nul
