@echo off
setlocal enabledelayedexpansion

:: Check for Administrator privileges
net session >nul 2>&1
if ERRORLEVEL neq 0 (
  echo This script requires Administrator privileges.
  echo Please right-click and select "Run as administrator".
  pause
  exit /b 1
)

echo PathOptimizer - Windows PATH Environment Optimizer
echo =================================================
echo.

:: Set working directory to script location
cd /d "%~dp0"

:: Parse command line arguments
set WHATIF=
set VERBOSE=
set INTERACTIVE=
set NONINTERACTIVE=
set FIXISSUE=All
set CUSTOMCONFIG=

:parse_args
if "%~1" == "" goto run_script
if /i "%~1" == "-WhatIf" (
  set WHATIF=-WhatIf
) else if /i "%~1" == "-Verbose" (
  set VERBOSE=-Verbose
if /i "%~1" == "-FixSpecificIssue" (
  if "%~2" == "" (
    echo Error: -FixSpecificIssue requires an argument.
    exit /b 1
  )
  if "%~2"=="" (
    echo Error: -FixSpecificIssue requires a value.
    exit /b 1
  )
  set FIXISSUE=%~2
  shift
) else if /i "%~1" == "-CustomConfig" (
  if "%~2"=="" (
    echo Error: -CustomConfig requires a value.
    exit /b 1
  )
  set CUSTOMCONFIG=-CustomConfig "%~2"
  shift
)
) else if /i "%~1" == "-CustomConfig" (
  set CUSTOMCONFIG=-CustomConfig "%~2"
  shift
)
shift
goto parse_args

:run_script
echo Running PathOptimizer with the following settings:
if defined WHATIF echo - Simulation mode (no changes will be made)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
if defined INTERACTIVE echo - Interactive mode
if defined NONINTERACTIVE echo - Non-interactive mode
echo - Issue focus: %FIXISSUE%
if defined CUSTOMCONFIG echo - Using custom configuration
echo.

echo Starting PowerShell script...
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "& { . ""%~dp0PathOptimizer.ps1"" %WHATIF% %VERBOSE% %INTERACTIVE% %NONINTERACTIVE% -FixSpecificIssue %FIXISSUE% %CUSTOMCONFIG% }"

echo.
if %ERRORLEVEL% equ 0 (
  echo PathOptimizer completed successfully.
) else (
  echo PathOptimizer encountered an error (code: %ERRORLEVEL%).
)

pause
