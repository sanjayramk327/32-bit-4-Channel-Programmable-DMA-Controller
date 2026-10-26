@echo off
setlocal

set "YOSYS_ROOT="
set "YOSYS_EXE="

rem Prefer the project-local OSS CAD Suite installation.
if exist "%~dp0tools\oss-cad-suite\bin\yosys.exe" (
    set "YOSYS_ROOT=%~dp0tools\oss-cad-suite"
) else if exist "%~dp0New folder\oss-cad-suite-windows-x64-20260913\oss-cad-suite\bin\yosys.exe" (
    set "YOSYS_ROOT=%~dp0New folder\oss-cad-suite-windows-x64-20260913\oss-cad-suite"
) 

if defined YOSYS_ROOT set "PATH=%YOSYS_ROOT%\bin;%YOSYS_ROOT%\lib;%PATH%"
if defined YOSYS_ROOT set "YOSYS_EXE=%YOSYS_ROOT%\bin\yosys.exe"
if not defined YOSYS_EXE for /f "delims=" %%I in ('where yosys 2^>nul') do if not defined YOSYS_EXE set "YOSYS_EXE=%%I"

if not defined YOSYS_EXE (
    echo ERROR: yosys.exe was not found.
    echo Install the official OSS CAD Suite Windows x64 archive, then extract it here:
    echo   %~dp0tools\oss-cad-suite
    echo Expected executable:
    echo   %~dp0tools\oss-cad-suite\bin\yosys.exe
    exit /b 1
)

if not exist build mkdir build
"%YOSYS_EXE%" -s synth.ys
exit /b %errorlevel%
