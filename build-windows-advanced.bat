@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: Bitcoin Core Windows Build Script - ADVANCED VERSION
:: Full control over build options with interactive menu
:: ============================================================================

title Bitcoin Core Windows Builder (Advanced)
color 0B

:: Default Configuration
set "REPO_DIR=%~dp0"
set "VCPKG_DIR=C:\vcpkg"
set "BUILD_DIR=%REPO_DIR%build"
set "INSTALL_DIR=C:\Bitcoin"
set "BUILD_GUI=OFF"
set "BUILD_TESTS=OFF"
set "BUILD_WALLET=ON"
set "BUILD_ZMQ=OFF"
set "BUILD_TYPE=Release"
set "PARALLEL_JOBS=8"
set "CLEAN_BUILD=0"

:: ============================================================================
:: MENU
:: ============================================================================

:Menu
cls
echo.
echo ============================================================================
echo                 BITCOIN CORE WINDOWS BUILD SCRIPT (ADVANCED)
echo ============================================================================
echo.
echo   Current Configuration:
echo   ----------------------
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
call :CheckRequirements
echo.
pause
goto :Menu

:InstallOnly
if exist "%BUILD_DIR%\bin\Release" (
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

:: Check requirements
call :CheckRequirements
if %errorlevel% neq 0 goto :BuildError

:: Setup environment
call :SetupEnvironment
if %errorlevel% neq 0 goto :BuildError

:: Verify source
call :VerifySource
if %errorlevel% neq 0 goto :BuildError

:: Configure
call :ConfigureBuild
if %errorlevel% neq 0 goto :BuildError

:: Build
call :RunBuild
if %errorlevel% neq 0 goto :BuildError

:: Report
call :ReportResults

echo.
echo Press any key to return to menu...
pause >nul
goto :Menu

:BuildError
echo.
echo [ERROR] Build process failed!
echo.
pause
goto :Menu

:: ============================================================================
:: FUNCTIONS
:: ============================================================================

:CheckRequirements
echo [STEP] Checking requirements...
echo.

:: Check Git
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [MISSING] Git - Installing...
    call :InstallGit
) else (
    echo [OK] Git found
)

:: Check Python
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [MISSING] Python - Installing...
    call :InstallPython
) else (
    echo [OK] Python found
)

:: Check CMake
where cmake >nul 2>&1
if %errorlevel% neq 0 (
    echo [MISSING] CMake - Installing...
    call :InstallCMake
) else (
    echo [OK] CMake found
)

:: Check Visual Studio
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS_FOUND=0"
if exist "%VSWHERE%" (
    for /f "tokens=*" %%i in ('"%VSWHERE%" -latest -property installationPath 2^>nul') do (
        if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" (
            set "VS_PATH=%%i"
            set "VS_FOUND=1"
        )
    )
)
if "%VS_FOUND%"=="0" (
    echo [MISSING] Visual Studio - Installing...
    call :InstallVS
) else (
    echo [OK] Visual Studio found
)

:: Check vcpkg
if not exist "%VCPKG_DIR%\vcpkg.exe" (
    echo [MISSING] vcpkg - Installing...
    call :InstallVcpkg
) else (
    echo [OK] vcpkg found
)

echo.
echo [OK] All requirements satisfied
exit /b 0

:SetupEnvironment
echo [STEP] Setting up build environment...

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    for /f "tokens=*" %%i in ('"%VSWHERE%" -latest -property installationPath 2^>nul') do (
        set "VS_PATH=%%i"
    )
)

if defined VS_PATH (
    if exist "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" (
        call "!VS_PATH!\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
        echo [OK] Visual Studio environment loaded
    )
)

set "VCPKG_ROOT=%VCPKG_DIR%"
exit /b 0

:VerifySource
echo [STEP] Verifying source code...
cd /d "%REPO_DIR%"

if not exist "CMakeLists.txt" (
    echo [ERROR] CMakeLists.txt not found!
    exit /b 1
)
if not exist "src\bitcoind.cpp" (
    echo [ERROR] Source files not found!
    exit /b 1
)
echo [OK] Source code verified
exit /b 0

:ConfigureBuild
echo [STEP] Configuring build...

if "%CLEAN_BUILD%"=="1" (
    if exist "%BUILD_DIR%" (
        echo [INFO] Cleaning previous build...
        rmdir /s /q "%BUILD_DIR%" 2>nul
    )
)

:: Detect VS version
set "VS_GENERATOR=Visual Studio 17 2022"
if exist "%VSWHERE%" (
    for /f "tokens=1" %%v in ('"%VSWHERE%" -latest -property catalog_productLineVersion 2^>nul') do (
        if "%%v"=="2022" set "VS_GENERATOR=Visual Studio 17 2022"
        if "%%v"=="2019" set "VS_GENERATOR=Visual Studio 16 2019"
    )
)

echo [INFO] Generator: %VS_GENERATOR%

cmake -B "%BUILD_DIR%" -G "%VS_GENERATOR%" -A x64 ^
    -DCMAKE_TOOLCHAIN_FILE="%VCPKG_DIR%\scripts\buildsystems\vcpkg.cmake" ^
    -DVCPKG_TARGET_TRIPLET="x64-windows-static" ^
    -DVCPKG_INSTALL_OPTIONS="--x-buildtrees-root=C:\vbt" ^
    -DBUILD_GUI=%BUILD_GUI% ^
    -DBUILD_TESTS=%BUILD_TESTS% ^
    -DBUILD_BENCH=OFF ^
    -DWITH_ZMQ=%BUILD_ZMQ% ^
    -DENABLE_WALLET=%BUILD_WALLET%

if %errorlevel% neq 0 exit /b 1
echo [OK] Configuration complete
exit /b 0

:RunBuild
echo [STEP] Building Bitcoin Core...
echo [INFO] Using %PARALLEL_JOBS% parallel jobs
echo.

cmake --build "%BUILD_DIR%" --config %BUILD_TYPE% --parallel %PARALLEL_JOBS%

if %errorlevel% neq 0 exit /b 1
echo [OK] Build complete
exit /b 0

:ReportResults
echo.
echo ============================================================================
echo                           BUILD RESULTS
echo ============================================================================
echo.

set "EXE_DIR=%BUILD_DIR%\bin\%BUILD_TYPE%"
if not exist "%EXE_DIR%" set "EXE_DIR=%BUILD_DIR%\src\%BUILD_TYPE%"

set "EXE_COUNT=0"
for %%f in ("%EXE_DIR%\*.exe") do (
    echo [OK] %%~nxf
    set /a EXE_COUNT+=1
)

echo.
echo   Total executables: %EXE_COUNT%
echo   Location: %EXE_DIR%
echo.
echo ============================================================================
exit /b 0

:: ============================================================================
:: INSTALLERS
:: ============================================================================

:InstallGit
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
) else (
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe' -OutFile '%TEMP%\git-installer.exe'; Start-Process '%TEMP%\git-installer.exe' -ArgumentList '/VERYSILENT /NORESTART' -Wait"
)
set "PATH=%PATH%;C:\Program Files\Git\cmd"
goto :eof

:InstallPython
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget install --id Python.Python.3.12 -e --silent --accept-package-agreements --accept-source-agreements
) else (
    powershell -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe' -OutFile '%TEMP%\python-installer.exe'; Start-Process '%TEMP%\python-installer.exe' -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1' -Wait"
)
goto :eof

:InstallCMake
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget install --id Kitware.CMake -e --silent --accept-package-agreements --accept-source-agreements
) else (
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-windows-x86_64.msi' -OutFile '%TEMP%\cmake.msi'; Start-Process 'msiexec' -ArgumentList '/i %TEMP%\cmake.msi /quiet /norestart ADD_CMAKE_TO_PATH=System' -Wait"
)
set "PATH=%PATH%;C:\Program Files\CMake\bin"
goto :eof

:InstallVS
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended" --accept-package-agreements --accept-source-agreements
) else (
    powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile '%TEMP%\vs_buildtools.exe'; Start-Process '%TEMP%\vs_buildtools.exe' -ArgumentList '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621' -Wait"
)
goto :eof

:InstallVcpkg
if not exist "%VCPKG_DIR%" (
    git clone https://github.com/microsoft/vcpkg.git "%VCPKG_DIR%"
)
cd /d "%VCPKG_DIR%"
call bootstrap-vcpkg.bat -disableMetrics
cd /d "%REPO_DIR%"
goto :eof
