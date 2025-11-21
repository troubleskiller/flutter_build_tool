@echo off
setlocal enabledelayedexpansion

:: Flutter Build Script for Windows
:: This script handles Flutter APK building

:: Arguments
set FLUTTER_SDK_PATH=%1
set FLUTTER_PROJECT_PATH=%2
set BUILD_TYPE=%3

:: Remove quotes from paths
set FLUTTER_SDK_PATH=%FLUTTER_SDK_PATH:"=%
set FLUTTER_PROJECT_PATH=%FLUTTER_PROJECT_PATH:"=%

:: Default to release if not specified
if "%BUILD_TYPE%"=="" set BUILD_TYPE=release

:: Shift first 3 arguments to get extra args
shift
shift
shift

:: Collect remaining arguments
set EXTRA_ARGS=
:loop
if "%~1"=="" goto endloop
set EXTRA_ARGS=%EXTRA_ARGS% %1
shift
goto loop
:endloop

echo [INFO] Starting Flutter build process...
echo [INFO] Flutter SDK: %FLUTTER_SDK_PATH%
echo [INFO] Project Path: %FLUTTER_PROJECT_PATH%
echo [INFO] Build Type: %BUILD_TYPE%

:: Check if Flutter SDK exists
if not exist "%FLUTTER_SDK_PATH%" (
    echo [ERROR] Flutter SDK not found at: %FLUTTER_SDK_PATH%
    exit /b 1
)

:: Check if project path exists
if not exist "%FLUTTER_PROJECT_PATH%" (
    echo [ERROR] Flutter project not found at: %FLUTTER_PROJECT_PATH%
    exit /b 1
)

set FLUTTER_BIN=%FLUTTER_SDK_PATH%\bin\flutter.bat

:: Check Flutter binary
if not exist "%FLUTTER_BIN%" (
    echo [ERROR] Flutter binary not found at: %FLUTTER_BIN%
    exit /b 1
)

:: Change to project directory
cd /d "%FLUTTER_PROJECT_PATH%"

:: Clean previous build
echo [STEP] Cleaning previous build...
call "%FLUTTER_BIN%" clean

:: Get dependencies
echo [STEP] Getting Flutter dependencies...
call "%FLUTTER_BIN%" pub get

:: Run code generation if needed
if exist "build.yaml" (
    echo [STEP] Running code generation...
    call "%FLUTTER_BIN%" pub run build_runner build --delete-conflicting-outputs
)

:: Build APK
echo [STEP] Building APK...

if "%BUILD_TYPE%"=="release" (
    call "%FLUTTER_BIN%" build apk --release %EXTRA_ARGS%
) else if "%BUILD_TYPE%"=="debug" (
    call "%FLUTTER_BIN%" build apk --debug %EXTRA_ARGS%
) else (
    call "%FLUTTER_BIN%" build apk --profile %EXTRA_ARGS%
)

set EXIT_CODE=%ERRORLEVEL%

if %EXIT_CODE% equ 0 (
    echo [INFO] Flutter build completed successfully!

    :: Find and display APK information
    if "%BUILD_TYPE%"=="release" (
        set APK_PATH=%FLUTTER_PROJECT_PATH%\build\app\outputs\flutter-apk\app-release.apk
    ) else if "%BUILD_TYPE%"=="debug" (
        set APK_PATH=%FLUTTER_PROJECT_PATH%\build\app\outputs\flutter-apk\app-debug.apk
    ) else (
        set APK_PATH=%FLUTTER_PROJECT_PATH%\build\app\outputs\flutter-apk\app-profile.apk
    )

    if exist "!APK_PATH!" (
        :: Get file size
        for %%F in ("!APK_PATH!") do set APK_SIZE=%%~zF
        set /a APK_SIZE_MB=!APK_SIZE!/1048576
        echo [INFO] APK generated at: !APK_PATH!
        echo [INFO] APK size: !APK_SIZE_MB! MB
    ) else (
        echo [WARNING] APK file not found at expected location: !APK_PATH!
    )
) else (
    echo [ERROR] Flutter build failed with exit code: %EXIT_CODE%
    exit /b %EXIT_CODE%
)

echo [INFO] Flutter build script completed
exit /b 0