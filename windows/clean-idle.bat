@echo off
setlocal
node "%~dp0..\tools\devcache.mjs" clean-idle %*
exit /b %errorlevel%
