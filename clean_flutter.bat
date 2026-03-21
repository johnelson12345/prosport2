@echo off
echo Killing Flutter-related processes...

taskkill /f /im dart.exe >nul 2>&1
taskkill /f /im flutter.exe >nul 2>&1
taskkill /f /im chrome.exe >nul 2>&1
taskkill /f /im code.exe >nul 2>&1
taskkill /f /im java.exe >nul 2>&1

echo Deleting locked folders...

rmdir /s /q .dart_tool
rmdir /s /q build
rmdir /s /q ios
rmdir /s /q linux
rmdir /s /q macos

echo Done cleaning!
pause