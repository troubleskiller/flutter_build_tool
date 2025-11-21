@echo off
setlocal enabledelayedexpansion

:: Unity Build Script for Windows
:: This script handles Unity project export to Flutter

:: Arguments
set UNITY_EDITOR_PATH=%1
set UNITY_PROJECT_PATH=%2
set BUILD_METHOD=%3

:: Remove quotes from paths
set UNITY_EDITOR_PATH=%UNITY_EDITOR_PATH:"=%
set UNITY_PROJECT_PATH=%UNITY_PROJECT_PATH:"=%

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

:: Colors for output (Windows doesn't support ANSI colors in cmd by default)
echo [INFO] Starting Unity build process...
echo [INFO] Unity Editor: %UNITY_EDITOR_PATH%
echo [INFO] Project Path: %UNITY_PROJECT_PATH%
echo [INFO] Build Method: %BUILD_METHOD%

:: Check if Unity Editor exists
if not exist "%UNITY_EDITOR_PATH%" (
    echo [ERROR] Unity Editor not found at: %UNITY_EDITOR_PATH%
    exit /b 1
)

:: Check if project path exists
if not exist "%UNITY_PROJECT_PATH%" (
    echo [ERROR] Unity project not found at: %UNITY_PROJECT_PATH%
    exit /b 1
)

:: Execute Unity build
echo [INFO] Executing Unity build command...

"%UNITY_EDITOR_PATH%" ^
    -batchmode ^
    -quit ^
    -projectPath "%UNITY_PROJECT_PATH%" ^
    -executeMethod %BUILD_METHOD% ^
    -logFile - ^
    %EXTRA_ARGS%

set EXIT_CODE=%ERRORLEVEL%

if %EXIT_CODE% equ 0 (
    echo [INFO] Unity build completed successfully!
) else (
    echo [ERROR] Unity build failed with exit code: %EXIT_CODE%
    exit /b %EXIT_CODE%
)

:: Check if export was successful
set EXPORT_PATH=%UNITY_PROJECT_PATH%\..\flutter_project\unity
if exist "%EXPORT_PATH%" (
    echo [INFO] Unity export found at: %EXPORT_PATH%

    :: Count exported files
    set /a FILE_COUNT=0
    for /r "%EXPORT_PATH%" %%f in (*) do set /a FILE_COUNT+=1
    echo [INFO] Exported !FILE_COUNT! files to Flutter project
) else (
    echo [WARNING] Unity export directory not found. Build may have failed.
)

echo [INFO] Unity build script completed
exit /b 0