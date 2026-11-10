## 1 安装python
winget install --id Python.Python.3.14 -e --source winget
## 2 安装auto hot key
winget install --id AutoHotkey.AutoHotkey -e --source winget
## 3 安装 Ahk2Exe
winget 只装解释器，编译器要从 https://github.com/AutoHotkey/Ahk2Exe/releases 下载 Ahk2Exe.zip，把 Ahk2Exe.exe 放进 %LOCALAPPDATA%\Programs\AutoHotkey\v2\Compiler\
## 4 打包 onekey_startup.ahk 为 exe
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\Compiler\Ahk2Exe.exe" /in .\onekey_startup.ahk /out .\onekey_startup.ahk.exe /base "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" /icon .\lib\iconHome.ico