@echo off
setlocal
cd /d "%~dp0"
call flutter config --enable-windows-desktop
if not exist "windows" (
  echo Generating Flutter platform scaffolding...
  call flutter create --project-name mezox_music --org com.mezox .
)
call flutter pub get
call flutter build windows --release --dart-define=MEZOX_API=%MEZOX_API%
echo.
echo EXE folder (ship entire folder): %~dp0build\windows\x64\runner\Release\
endlocal
