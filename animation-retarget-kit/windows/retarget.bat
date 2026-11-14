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

if not exist "%KIT%\config.env" (
	echo [ERROR] 还没有配置环境。请先双击 windows\setup.bat
	pause
	exit /b 1
)

set "TARGET=%~1"
if not defined TARGET (
	for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.OpenFileDialog; $d.Filter='Model (*.fbx;*.glb)|*.fbx;*.glb'; if($d.ShowDialog() -eq 'OK'){$d.FileName}"`) do set "TARGET=%%I"
)
if not defined TARGET (
	echo 未选择目标模型。
	pause
	exit /b 1
)

echo.
echo 选择动作:
echo   1 = SambaDance
echo   2 = Run
echo   3 = Walk
echo   4 = Idle
set /p CHOICE=输入 1-4:
if "%CHOICE%"=="1" set "CLIP=samba"
if "%CHOICE%"=="2" set "CLIP=run"
if "%CHOICE%"=="3" set "CLIP=walk"
if "%CHOICE%"=="4" set "CLIP=idle"
if not defined CLIP (
	echo 无效选择。
	pause
	exit /b 1
)

echo.
echo 输出格式:
echo   1 = GLB
echo   2 = FBX
set /p FMT=输入 1-2:
set "EXTRA="
if "%FMT%"=="2" set "EXTRA=--fbx"

echo.
echo 目标: %TARGET%
echo 动作: %CLIP%
"%BASH%" "%KIT%\retarget.sh" --target "%TARGET%" --clip %CLIP% %EXTRA%

echo.
if exist "%KIT%\out" start "" "%KIT%\out"
pause
