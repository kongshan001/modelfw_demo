@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "KIT=%%~fI"

set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH (
	where bash >nul 2>nul
	if not errorlevel 1 set "BASH=bash"
)
if not defined BASH (
	echo [ERROR] 未找到 Git Bash。请安装 Git for Windows:
	echo         https://git-scm.com/download/win
	pause
	exit /b 1
)

echo 使用 Git Bash: %BASH%
"%BASH%" "%KIT%\setup.sh"
pause
