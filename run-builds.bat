@echo off
setlocal enabledelayedexpansion

:: Configure, build and smoke-test every build type this toolchain supports.

:: Work from the repo root no matter where the script is run from
:: (setlocal restores the caller's directory on exit)
cd /d "%~dp0"

:: Directory for the builds
set "BUILD_DIR=build"

:: Remove any existing build artifacts
if exist "%BUILD_DIR%" rd /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%"

:: Ask CMake which build types this toolchain supports
cmake -S . -B "%BUILD_DIR%\probe" > nul
if errorlevel 1 (
    echo CMake probe configure failed.
    exit /b 1
)
set "BUILD_TYPES="
for /f "tokens=1,* delims==" %%A in ('findstr /b "DIRSIZE_BUILD_TYPES:INTERNAL=" "%BUILD_DIR%\probe\CMakeCache.txt"') do set "BUILD_TYPES=%%B"
if not defined BUILD_TYPES (
    echo Unable to read DIRSIZE_BUILD_TYPES from CMakeCache.txt
    exit /b 1
)
set "BUILD_TYPES=%BUILD_TYPES:;= %"

:: Initialize counters and lists for build results
set /a success_count=0
set /a failure_count=0
set "successful_builds="
set "failed_builds="

:: Loop through each build type
for %%B in (%BUILD_TYPES%) do (
    echo Building for type: %%B

    :: Errorlevel must be read with ! inside a block; % is expanded too early
    call :build_and_test %%B
    if !errorlevel! equ 0 (
        echo %%B build succeeded.
        set "successful_builds=!successful_builds! %%B"
        set /a success_count+=1
    ) else (
        echo %%B build failed.
        set "failed_builds=!failed_builds! %%B"
        set /a failure_count+=1
    )
)

:: Report the summary of builds
echo Build Summary:
echo Successful Builds: %success_count%
echo Failed Builds: %failure_count%

:: List successful build types
if not "!successful_builds!"=="" (
    echo Successful Build Types:
    for %%S in (%successful_builds%) do echo   - %%S
)

:: List failed build types if there were any failures
if not "!failed_builds!"=="" (
    echo Failed Build Types:
    for %%F in (%failed_builds%) do echo   - %%F
)

:: Exit with appropriate status code
if %failure_count% gtr 0 (
    exit /b 1
) else (
    exit /b 0
)

:: Configure, build and smoke-test one build type
:build_and_test
set "TYPE=%~1"
set "DIR=%BUILD_DIR%\%TYPE%"

cmake -S . -B "%DIR%" -DCMAKE_BUILD_TYPE=%TYPE%
if errorlevel 1 exit /b 1
cmake --build "%DIR%" --config %TYPE%
if errorlevel 1 exit /b 1

:: Sanitizer errors make the smoke tests fail
ctest --test-dir "%DIR%" -C %TYPE% --output-on-failure
if errorlevel 1 exit /b 1
exit /b 0
