@echo off
set "SHELL=powershell.exe"
where nu >nul 2>nul && set "SHELL=nu.exe"
where zellij >nul 2>nul || goto :no_zellij
zellij
exit /b

:no_zellij
where nu >nul 2>nul || goto :no_nu
nu
exit /b

:no_nu
powershell.exe
