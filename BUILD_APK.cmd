@echo off
setlocal
cd /d "%~dp0"
if not exist "android" (
  echo Generating Flutter platform scaffolding...
  call flutter create --project-name mezox_music --org com.mezox .
)
call flutter pub get
call flutter build apk --release --dart-define=MEZOX_API=%MEZOX_API%
echo.
echo APK: %~dp0build\app\outputs\flutter-apk\app-release.apk
endlocal
