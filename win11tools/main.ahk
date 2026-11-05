#Requires AutoHotkey v2.0
#SingleInstance Force

global APP_TITLE := "win11tools"
global CMD_PYTHON := "winget install --id Python.Python.3.14 -e --source winget"
global CMD_AUTOHOTKEY := "winget install --id AutoHotkey.AutoHotkey -e --source winget"

if (A_IsCompiled || A_LineFile = A_ScriptFullPath)
    Main()

Main() {
    global STATUS
    global mainGui
    mainGui := Gui("+Resize -MaximizeBox", APP_TITLE)
    mainGui.SetFont("s10", "Microsoft YaHei UI")
    mainGui.MarginX := 16
    mainGui.MarginY := 14
    mainGui.AddText("w380", "请选择功能，安装类命令需要手动复制到终端执行：")
    mainGui.AddButton("+0x0100 w380 h36 y+12", "1  显示 winget 安装 Python 的命令").OnEvent("Click", ShowPythonCmd)
    mainGui.AddButton("+0x0100 w380 h36 y+8", "2  显示 winget 安装 AutoHotkey 的命令").OnEvent("Click", ShowAutoHotkeyCmd)
    mainGui.AddButton("+0x0100 w380 h36 y+8", "3  运行同目录 main.pyw").OnEvent("Click", (*) => RunMainPyw())
    mainGui.AddButton("+0x0100 w380 h36 y+8", "4  打包自身为 main.ahk.exe").OnEvent("Click", (*) => PackSelf())
    STATUS := mainGui.AddStatusBar(, "就绪")
    mainGui.AddButton("w380 h32 y+10", "关闭").OnEvent("Click", (*) => ExitApp())
    mainGui.OnEvent("Close", (*) => ExitApp())
    mainGui.Show()
}

SetStatus(msg) {
    global STATUS
    STATUS.Text := msg
}

ShowPythonCmd(*) {
    ShowCommand("安装 Python", CMD_PYTHON)
}

ShowAutoHotkeyCmd(*) {
    ShowCommand("安装 AutoHotkey", CMD_AUTOHOTKEY)
}

ShowCommand(title, command) {
    dlg := Gui("+AlwaysOnTop", APP_TITLE " - " title)
    dlg.SetFont("s10", "Microsoft YaHei UI")
    dlg.MarginX := 14
    dlg.MarginY := 12
    dlg.AddText("w660", "在 PowerShell 或 cmd 中手动执行下面的命令：")
    dlg.SetFont("s11", "Consolas")
    ed := dlg.AddEdit("w660 h56 ReadOnly -Wrap y+8", command)
    dlg.SetFont("s10", "Microsoft YaHei UI")
    sb := dlg.AddStatusBar(, "就绪")
    btnCopy := dlg.AddButton("w120 h32 y+12", "复制命令")
    btnCopy.OnEvent("Click", (*) => CopyCommand(command, sb))
    btnSelect := dlg.AddButton("w120 h32 x+8 yp", "全选")
    btnSelect.OnEvent("Click", (*) => SelectAllEdit(ed))
    btnClose := dlg.AddButton("w120 h32 x+8 yp", "关闭")
    btnClose.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show()
}

CopyCommand(command, sb) {
    A_Clipboard := command
    sb.Text := "已复制到剪贴板"
}

SelectAllEdit(ed) {
    ed.Focus()
    SendMessage(0x00B1, 0, -1, ed)
}

RunMainPyw(*) {
    pyw := A_ScriptDir "\main.pyw"
    if !FileExist(pyw) {
        MsgBox("找不到文件：`n" pyw, APP_TITLE, "Iconx")
        return
    }
    try {
        Run('"pythonw.exe" "' pyw '"', A_ScriptDir)
        SetStatus("已启动 main.pyw")
        return
    }
    exe := FindPythonw()
    if (exe != "") {
        try {
            Run('"' exe '" "' pyw '"', A_ScriptDir)
            SetStatus("已启动 main.pyw")
            return
        }
    }
    SetStatus("未找到 pythonw.exe")
    MsgBox("未找到 pythonw.exe，请先安装 Python。", APP_TITLE, "Iconx")
}

FindPythonw() {
    roots := [EnvGet("LOCALAPPDATA") "\Programs\Python", EnvGet("ProgramFiles") "\Python", EnvGet("ProgramFiles(x86)") "\Python", "C:\Python"]
    for root in roots {
        if !DirExist(root)
            continue
        found := ""
        Loop Files, root "\*", "D" {
            cand := A_LoopFileFullPath "\pythonw.exe"
            if FileExist(cand)
                found := cand
        }
        if (found != "")
            return found
    }
    return ""
}

PackSelf(*) {
    src := A_ScriptDir "\main.ahk"
    if !FileExist(src) {
        MsgBox("找不到源脚本：`n" src, APP_TITLE, "Iconx")
        return
    }
    base := FindAhkBase()
    if (base = "") {
        MsgBox("未找到 AutoHotkey v2 解释器 AutoHotkey64.exe。", APP_TITLE, "Iconx")
        return
    }
    compiler := FindAhk2Exe(base)
    if (compiler = "") {
        MsgBox("未找到编译器 Ahk2Exe.exe。", APP_TITLE, "Iconx")
        return
    }
    target := A_ScriptDir "\main.ahk.exe"
    tmp := A_Temp "\main_ahk_" A_TickCount ".exe"
    cmd := '"' compiler '" /in "' src '" /out "' tmp '" /base "' base '"'
    icon := A_ScriptDir "\lib\iconHome.ico"
    if FileExist(icon)
        cmd .= ' /icon "' icon '"'
    SetStatus("正在打包 ...")
    rc := RunWait(cmd, A_ScriptDir, "Hide")
    if !FileExist(tmp) {
        SetStatus("打包失败")
        MsgBox("打包失败：未生成输出文件（Ahk2Exe exit " rc "）。", APP_TITLE, "Iconx")
        return
    }
    copied := false
    try {
        FileCopy(tmp, target, true)
        copied := (FileExist(target) && FileGetSize(target) = FileGetSize(tmp))
    } catch {
        copied := false
    }
    if copied {
        try FileDelete(tmp)
        SetStatus("打包完成：" target)
        MsgBox("打包完成：`n" target, APP_TITLE, "Iconi")
        return
    }
    cmdDelayed := '/c ping -n 4 127.0.0.1 >nul & copy /y "' tmp '" "' target '" & del "' tmp '"'
    Run(A_ComSpec " " cmdDelayed, , "Hide")
    SetStatus("打包完成，关闭窗口后覆盖 main.ahk.exe")
    MsgBox("打包完成。`n目标文件正在使用中，关闭本窗口后自动覆盖：`n" target, APP_TITLE, "Iconi")
    ExitApp()
}

FindAhkBase() {
    cands := []
    if (A_AhkPath != "" && RegExMatch(A_AhkPath, "i)AutoHotkey\d*\.exe$"))
        cands.Push(A_AhkPath)
    for dir in AhkV2Dirs()
        cands.Push(dir "\AutoHotkey64.exe")
    for c in cands {
        if FileExist(c)
            return c
    }
    return ""
}

FindAhk2Exe(base) {
    SplitPath(base, , &dir)
    cands := [dir "\Compiler\Ahk2Exe.exe", dir "\..\Compiler\Ahk2Exe.exe", dir "\..\..\Compiler\Ahk2Exe.exe"]
    scoop := EnvGet("SCOOP")
    if (scoop != "") {
        root := scoop "\apps\autohotkey"
        cands.Push(root "\current\Compiler\Ahk2Exe.exe")
        if DirExist(root) {
            Loop Files, root "\*", "D"
                cands.Push(A_LoopFileFullPath "\Compiler\Ahk2Exe.exe")
        }
    }
    for c in cands {
        if FileExist(c)
            return c
    }
    return ""
}

AhkV2Dirs() {
    dirs := []
    scoop := EnvGet("SCOOP")
    if (scoop != "") {
        root := scoop "\apps\autohotkey"
        dirs.Push(root "\current\v2")
        if DirExist(root) {
            Loop Files, root "\*", "D"
                dirs.Push(A_LoopFileFullPath "\v2")
        }
    }
    dirs.Push(EnvGet("LOCALAPPDATA") "\Programs\AutoHotkey\v2")
    dirs.Push(EnvGet("ProgramFiles") "\AutoHotkey\v2")
    dirs.Push(EnvGet("ProgramFiles(x86)") "\AutoHotkey\v2")
    return dirs
}
