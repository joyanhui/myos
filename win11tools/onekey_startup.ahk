; =====================================================================
; startup.ahk — 自启程序的启动器 + komorebi 热键（单文件 AHK v2）
;
;   启动顺序：ExplorerTabUtility（自带键盘钩子，必须最先起）→ YASB → Flow Launcher
;             → AltSnap（已在跑就跳过，没跑才提权启动，会弹 UAC）
;   komorebi 不自动启动：要按托盘菜单「启动 komorebi」手动拉起。
;   热键分两组（全部带 $/~/* 前缀 = 强制走键盘钩子，比系统/资源管理器先拿到按键；
;   ~ 前缀按键不吞、透传给当前程序，用于远程界面放行）：
;     通用（跟平铺桌面无关，脚本一启动就生效，komorebi 没跑也照常）：
;       Win+R           Flow Launcher（顶掉系统「运行」）
;       Alt+Enter       打开本机 noctty 终端
;       Alt+Shift+E     打开 Windows 文件管理器
;       Alt+Shift+Q     关闭当前窗口（komorebi 在跑走 komorebic，没跑退回 WinClose）
;       右 Alt          → F2（等价官方 remap `RAlt::F2`，按住可自动重复；左 Alt 不受影响）
;     平铺（komorebi 的活；一直注册着，komorebi 没跑时按下只提示一次）：
;       Win+1..9        切工作区（komorebi 索引 0 起，Win+1 → 工作区 0）
;       Win+Shift+1..9  把当前窗口移到工作区并跟过去
;       Win+F           切换浮动 / 平铺
;       Win+Shift+E     退出 komorebi（本脚本跟着退出；YASB / Flow / ETU 不动）
;   Alt+Shift+Q / Win+Shift+1..9 / Win+Shift+E 带 ~：焦点在远程/虚拟机界面
;   （WSLg / RDP / VMware / Hyper-V / VirtualBox / QEMU 等）时，按键透传给
;   远端/虚拟机，处理函数直接 return，本地绝不动作 —— 防止把 RDP/VM 控制台
;   整个关掉、移走窗口或误退 komorebi。
;   退出本脚本：只卸下自己的热键，komorebi / YASB / Flow Launcher / ExplorerTabUtility 一律不动。
;   YASB 不做自己的配置，直接用 YASB 自己的配置（config_run\yasb 或 YASB 默认位置）。
;   日志：%TEMP%\onekey_startup.log
;   主界面：托盘菜单「说明 / 主界面」或双击托盘图标（启动时不弹窗，仍只驻托盘），
;   窗口里是可复制的全文：自启动列表 + 全部热键 + 远程界面放行规则。
;   语法自检：AutoHotkey64.exe /ErrorStdOut /Validate startup.ahk
; =====================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force      ; 再双击一次 = 顶掉旧实例重来（热键跟着重装）
#Warn VarUnset, StdOut
Persistent

PROJ     := A_ScriptDir
APPDIR   := EnvGet("TEMP")
LOGFILE  := APPDIR . "\onekey_startup.log"

HLIVE    := Map()           ; 已注册的热键
SCOPEC   := ""              ; scoop 根目录缓存
KOMOC    := ""              ; komorebic 路径缓存
KOMODOWN := false           ; 「komorebi 没在跑」是否已经提示过
AGUI     := ""              ; 主界面（懒加载，退出前不销毁）

DOC_TEXT := "
(
startup.ahk — 自启启动器 + komorebi 热键

[自启动]  依次拉起，已在跑就跳过；komorebi / YASB 不自动启动
  1. ExplorerTabUtility   自带键盘钩子，必须最先起
  2. Flow Launcher        按 Win+R 唤出
  3. AltSnap              提权启动（会弹 UAC）
  -  komorebi             托盘菜单「启动 komorebi（手动）」
  -  YASB                 脚本里已注释，暂不启动

[通用热键]  不依赖 komorebi，脚本一启动就生效
  Win+R                   Flow Launcher（顶掉系统「运行」）
  Alt+Enter               本机 noctty 终端
  Alt+Shift+E             Windows 文件管理器
  Alt+Shift+Q             关闭当前窗口（komorebi 在跑走 komorebic，否则 WinClose）
  右 Alt                   → F2（等价官方 remap，按住自动重复；左 Alt 不受影响）

[平铺热键]  komorebi 的活，komorebi 在跑才生效（没跑时按下只提示一次）
  Win+1..9                切工作区（komorebi 索引 0 起，Win+1 = 工作区 0）
  Win+Shift+1..9          把当前窗口移到工作区并跟过去
  Win+F                   切换浮动 / 平铺
  Win+Shift+E             退出 komorebi（本脚本跟着退出）

[远程 / 虚拟机放行]
  Alt+Shift+Q / Win+Shift+1..9 / Win+Shift+E 在远程或虚拟机界面里
  （RDP / WSLg / VMware / Hyper-V / VirtualBox / QEMU / AnyDesk / ToDesk 等）
  直接透传给远端，本地不动作 —— 不会把控制台窗口关掉、移走或误退 komorebi。

[其他]
  托盘双击               打开本窗口
  重装热键               托盘菜单（改过热键后才需要）
  退出                   只卸下自己的热键，komorebi / YASB / Flow / ETU 一律不动
  日志                   %TEMP%\onekey_startup.log
)"

; =====================================================================
; 日志
; =====================================================================
EnsureDirs() {
    try DirCreate(APPDIR)
}

LogRaw(text) {
    try FileAppend(text . "`n", LOGFILE, "UTF-8")
}
LogAt(level, text) {
    LogRaw(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " [" . level . "] " . text)
}
LogLine(text) => LogAt("信息", text)
LogOk(text)   => LogAt("成功", text)
LogWrn(text)  => LogAt("警告", text)
LogErr(text)  => LogAt("失败", text)

; =====================================================================
; 路径（scoop 的 shims 在 PATH 里 ——「PATH 里的 yasb / komorebic」就是这么来的）
; =====================================================================
FindExe(name) {
    p := A_ScriptDir . "\" . name
    if (FileExist(p) != "")
        return p
    for d in StrSplit(EnvGet("PATH"), ";") {
        d := RTrim(d, "\/")
        if (d = "")
            continue
        p := d . "\" . name
        if (FileExist(p) != "")
            return p
    }
    return ""
}

ScoopDir() {
    global SCOPEC
    if (SCOPEC != "")
        return SCOPEC
    s := RTrim(EnvGet("SCOOP"), "\/")
    if (s != "" && DirExist(s . "\shims") != "")
        return SCOPEC := s
    for d in StrSplit(EnvGet("PATH"), ";") {        ; 从 PATH 里的 shims 反推
        d := RTrim(d, "\/")
        if (d = "" || !InStr(d, "shims"))
            continue
        if (FileExist(d . "\komorebic.shim") != "")
            return SCOPEC := d . "\.."
    }
    return SCOPEC := ""
}

ScoopAppExe(pkg, exe) {
    s := ScoopDir()
    if (s = "")
        return ""
    p := s . "\apps\" . pkg . "\current\" . exe
    return (FileExist(p) != "") ? p : ""
}

KomorebicExe() {
    global KOMOC
    if (KOMOC != "")
        return KOMOC
    p := FindExe("komorebic-no-console.exe")   ; 官方给热键用的无控制台版本，不闪黑框
    if (p = "")
        p := FindExe("komorebic.exe")
    return KOMOC := p
}

EtuExe() {
    p := ScoopAppExe("ExplorerTabUtility", "ExplorerTabUtility.exe")
    if (p != "")
        return p
    p := EnvGet("LOCALAPPDATA") . "\Programs\ExplorerTabUtility\ExplorerTabUtility\ExplorerTabUtility.exe"
    return (FileExist(p) != "") ? p : ""
}

FlowExe() {
    p := FindExe("Flow.Launcher.exe")
    if (p != "")
        return p
    return ScoopAppExe("Flow-Launcher", "Flow.Launcher.exe")
}

NocttyExe() {
    p := FindExe("noctty.exe")
    if (p != "")
        return p
    p := EnvGet("ProgramFiles") . "\noctty\noctty.exe"
    return (FileExist(p) != "") ? p : ""
}

AltsnapExe() {
    p := ScoopAppExe("altsnap", "AltSnap.exe")
    if (p != "")
        return p
    p := ScoopDir() . "\shims\altsnap.exe"
    return (FileExist(p) != "") ? p : ""
}

; =====================================================================
; komorebic
; =====================================================================
KCmd(sub) {                                  ; 只改状态，不要输出
    p := KomorebicExe()
    if (p = "") {
        LogErr("PATH 里找不到 komorebic（先装 komorebi）")
        return false
    }
    try {
        Run('"' . p . '" ' . sub, , "Hide")
        return true
    } catch as e {
        LogErr("komorebic " . sub . " 失败: " . e.Message)
        return false
    }
}

; =====================================================================
; 启动 / 停止
; =====================================================================
StartEtu() {
    if (ProcessExist("ExplorerTabUtility.exe")) {
        LogLine("ExplorerTabUtility 已在运行")
        return
    }
    p := EtuExe()
    if (p = "") {
        LogErr("找不到 ExplorerTabUtility.exe")
        return
    }
    try {
        Run('"' . p . '"')
        LogOk("已启动 ExplorerTabUtility: " . p)
    } catch as e
        LogErr("启动 ExplorerTabUtility 失败: " . e.Message)
}

StartKomorebi() {
    if (ProcessExist("komorebi.exe")) {
        LogLine("komorebi 已在运行")
        return
    }
    if (!KCmd("start"))
        return
    LogLine("已请求启动 komorebi，等进程出现…")
    SetTimer(ConfirmKomorebi, -300)          ; 新线程里等，不卡启动
}

ConfirmKomorebi() {
    pid := ProcessWait("komorebi.exe", 20)
    if (pid)
        LogOk("komorebi 已就绪 (pid " . pid . ")")
    else
        LogErr("等了 20s 没看到 komorebi.exe（komorebic start 失败？）")
}

StopKomorebi() {
    if (!ProcessExist("komorebi.exe")) {
        LogLine("komorebi 本来就没在跑")
        return false
    }
    if (!KCmd("stop"))
        return false
    LogOk("已停止 komorebi（YASB / Flow Launcher / ExplorerTabUtility 不动）")
    return true
}

StartYasb() {                                  ; 用 YASB 自己的配置（不指定、不另做一份）
    if (ProcessExist("yasb.exe")) {
        LogLine("yasb.exe 已在运行")
        return
    }
    p := FindExe("yasb.exe")                   ; 「PATH 里的 yasb」
    if (p = "") {
        LogErr("PATH 里找不到 yasb.exe")
        return
    }
    try {
        Run('"' . p . '"')
        LogOk("已启动 YASB: " . p . "  [配置=" . (EnvGet("YASB_CONFIG_HOME") != "" ? EnvGet("YASB_CONFIG_HOME") : "YASB 默认位置") . "]")
    } catch as e
        LogErr("启动 YASB 失败: " . e.Message)
}

RunFlow() {
    p := FlowExe()
    if (p = "") {
        LogErr("找不到 Flow.Launcher.exe（先装它）")
        return false
    }
    try {
        Run('"' . p . '"')
        return true
    } catch as e {
        LogErr("启动 Flow Launcher 失败: " . e.Message)
        return false
    }
}

StartFlow() {                                ; 启动时用：已经在跑就不重复拉起
    if (ProcessExist("Flow.Launcher.exe")) {
        LogLine("Flow Launcher 已在运行")
        return
    }
    if (RunFlow())
        LogOk("已启动 Flow Launcher: " . FlowExe())
}

; AltSnap 的鼠标钩子要能拖提权窗口，所以固定用管理员启动；已经在跑就直接跳过
StartAltsnap() {
    if (ProcessExist("AltSnap.exe")) {
        LogLine("AltSnap 已在运行")
        return
    }
    p := AltsnapExe()
    if (p = "") {
        LogErr("找不到 AltSnap.exe")
        return
    }
    try {
        Run('*RunAs "' . p . '"')            ; UAC 弹窗；被拒 = 抛异常 = 启动失败
        LogOk("已请求提权启动 AltSnap: " . p)
    } catch as e
        LogErr("提权启动 AltSnap 失败（UAC 被拒？）: " . e.Message)
}

ShowFlow() {                                 ; Win+R：Flow Launcher 是单实例，再跑一次 = 把窗口叫出来
    RunFlow()
}

OpenNoctty() {                               ; Alt+Enter：本机 noctty 终端
    p := NocttyExe()
    if (p = "") {
        LogErr("找不到 noctty.exe（先装 noctty）")
        return
    }
    try Run('"' . p . '"')
    catch as e
        LogErr("启动 noctty 失败: " . e.Message)
}

OpenExplorer() {                             ; Alt+Shift+E：Windows 文件管理器
    try Run("explorer.exe")
    catch as e
        LogErr("打开文件管理器失败: " . e.Message)
}

; =====================================================================
; 远程 / 虚拟机界面识别（InRemoteView）
;   焦点在远程软件的操作界面 / 虚拟机控制台里时，Alt+Shift+Q（关窗）、
;   Win+Shift+1..9（移窗口）、Win+Shift+E（退出）三个热键必须放行给远端，
;   本地绝不动作 —— 否则会把 mstsc/VMware/Hyper-V 窗口整个关掉，或误退 komorebi。
;   WSLg 的宿主也是 mstsc.exe（静默 RAIL-RDP），所以天然被覆盖。
;   进程名统一转小写比对（Windows 进程名不分大小写，Map 的键区分大小写）。
; =====================================================================
REMOTE_EXES := Map(
    ; 远程桌面：老客户端 mstsc / 新「Windows App」msrdc（WSLg 宿主 = mstsc 静默实例）
    "mstsc.exe", true,
    "msrdc.exe", true,
    ; VMware Workstation / Player
    "vmware.exe", true,
    "vmware-vmx.exe", true,
    "vmwareworkstationvmx.exe", true,
    "vmwareplayer.exe", true,
    ; Hyper-V VMConnect
    "vmconnect.exe", true,
    ; VirtualBox
    "virtualbox.exe", true,
    "virtualboxvm.exe", true,
    ; QEMU（qemu-system-*.exe 走下方前缀匹配）
    "qemu.exe", true,
    ; 常见远程控制软件
    "anydesk.exe", true,
    "teamviewer.exe", true,
    "todesk.exe", true,
    "rustdesk.exe", true,
    "sunflower.exe", true,
    "parsec.exe", true,
    "wfica32.exe", true,                     ; Citrix Workspace
    "vncviewer.exe", true,                   ; TightVNC / RealVNC / UltraVNC 查看端
    "tvnviewer.exe", true,
    "winvnc.exe", true,
    "nomachine.exe", true                    ; NoMachine
)
REMOTE_CLASSES := Map(                       ; 窗口类兜底（进程名对不上时）
    "TscShellContainerClass", true           ; mstsc 现代窗口
)

InRemoteView() {                             ; 焦点在远程/虚拟机界面 = true
    try hwnd := WinExist("A")
    catch
        return false
    if (!hwnd)
        return false
    try exe := StrLower(WinGetProcessName(hwnd))
    catch
        exe := ""
    try cls := WinGetClass(hwnd)
    catch
        cls := ""
    if (exe != "" && (REMOTE_EXES.Has(exe) || RegExMatch(exe, "^qemu-system-")))
        return true
    if (cls != "" && REMOTE_CLASSES.Has(cls))
        return true
    return false
}

; =====================================================================
; 热键（$ / ~ 前缀 = 强制走键盘钩子，系统/资源管理器收不到这些按键；
; ~ 前缀按键不吞、透传给当前程序 —— 远程/虚拟机界面的三个放行热键用它）
; =====================================================================
KomorebiAlive() {
    global KOMODOWN
    if ProcessExist("komorebi.exe") {
        KOMODOWN := false
        return true
    }
    if (!KOMODOWN) {                         ; 一个「掉线期」只提示一次
        KOMODOWN := true
        LogWrn("komorebi.exe 没在跑：平铺热键（Win+1..9 等）不生效；通用热键（Win+R / Alt+Shift+Q / 右Alt→F2）照常")
        try TrayTip("Win+1..9 等平铺热键要 komorebi 在跑才生效（Win+R / 关窗 / 右Alt→F2 照常）。右键托盘图标 → 启动 komorebi。", "startup.ahk", "Icon!")
    }
    return false
}

GoWS(n) {                                    ; Win+数字
    if (!KomorebiAlive())
        return
    KCmd("focus-workspace " . (n - 1))
}

MoveWS(n) {                                  ; Win+Shift+数字：移过去并跟过去
    if (InRemoteView())                      ; 焦点在远程/虚拟机界面：按键已透传，本地不动
        return
    if (!KomorebiAlive())
        return
    KCmd("move-to-workspace " . (n - 1))
}

ToggleFloat() {                              ; Win+F
    if (!KomorebiAlive())
        return
    KCmd("toggle-float")
}

CloseWindow() {                              ; Alt+Shift+Q：通用热键，不依赖 komorebi
    if (InRemoteView())                      ; 焦点在远程/虚拟机界面：按键已透传，本地不动
        return
    if (ProcessExist("komorebi.exe")) {
        KCmd("close")
        return
    }
    try WinClose("A")                        ; 兜底：直接给当前窗口发 WM_CLOSE
}

RAltToF2Down() {                             ; 右 Alt → F2（官方 remap `RAlt::F2` 的等价展开）
    Send("{Blind}{F2 DownR}")               ; DownR：按住期间跟着键盘自动重复
}
RAltToF2Up() {
    Send("{Blind}{F2 Up}")                  ; 必须有这个 Up，否则 F2 会卡住
}

QuitKomorebi() {                             ; Win+Shift+E：退出 komorebi，本脚本跟着退
    if (InRemoteView())                      ; 焦点在远程/虚拟机界面：按键已透传，本地不动
        return
    StopKomorebi()
    ExitApp()
}

; 通用热键：和平铺桌面无关，脚本启动就注册，komorebi 在不在都照常工作
GeneralHotkeys() {
    return [
        ["$#r",      (*) => ShowFlow()],        ; Win+R → Flow Launcher
        ["$!Enter",  (*) => OpenNoctty()],      ; Alt+Enter → 本机 noctty
        ["$!+e",     (*) => OpenExplorer()],    ; Alt+Shift+E → 文件管理器
        ["~!+q",     (*) => CloseWindow()],     ; Alt+Shift+Q → 关闭当前窗口（~：远程里透传不动作）
        ["*RAlt",    (*) => RAltToF2Down()],    ; 右 Alt → F2
        ["*RAlt Up", (*) => RAltToF2Up()]
    ]
}

; 平铺热键：komorebi 的活（一直注册着，komorebi 没跑时只提示一次，不转发按键）
KomorebiHotkeys() {
    out := []
    loop 9 {
        out.Push(["$#"  . A_Index, ((n) => ((*) => GoWS(n)))(A_Index)])
        out.Push(["~#+" . A_Index, ((n) => ((*) => MoveWS(n)))(A_Index)])  ; ~：远程里透传不动作
    }
    out.Push(["$#f",  (*) => ToggleFloat()])
    out.Push(["~#+e", (*) => QuitKomorebi()])      ; ~：远程里透传不动作
    return out
}

AddHotkey(pair) {
    global HLIVE
    try {
        Hotkey(pair[1], pair[2])
        HLIVE[pair[1]] := true
        return true
    } catch as e {
        LogErr("注册热键失败 " . pair[1] . ": " . e.Message)
        return false
    }
}

InstallHotkeys() {
    RemoveHotkeys()
    ng := 0
    for pair in GeneralHotkeys()
        ng += AddHotkey(pair)
    nk := 0
    for pair in KomorebiHotkeys()
        nk += AddHotkey(pair)
    LogOk("热键已启用：通用 " . ng . " 个（Win+R / Alt+Enter / Alt+Shift+E / Alt+Shift+Q / 右Alt→F2，不依赖 komorebi）、平铺 " . nk . " 个（komorebi）")
}

RemoveHotkeys() {
    global HLIVE
    for k in HLIVE {
        try Hotkey(k, "Off")
    }
    HLIVE := Map()
}

; =====================================================================
; 托盘
; =====================================================================
OpenLog() {
    p := (FileExist(LOGFILE) != "") ? LOGFILE : APPDIR
    try Run('"' . p . '"')
}

ShowMainGui() {                              ; 主界面：自启动列表 + 热键说明（只读、可复制）
    global AGUI
    if (AGUI) {
        try {
            AGUI.Show()
            WinActivate("ahk_id " . AGUI.Hwnd)
            return
        } catch {
            AGUI := ""
        }
    }
    g := Gui("-Resize -MaximizeBox", "startup.ahk — 自启与热键说明")
    g.MarginX := 0
    g.MarginY := 0
    g.SetFont("s10", "Consolas")
    g.Add("Edit", "ReadOnly -Wrap x0 y0 w760 h560 BackgroundF7F7F7", DOC_TEXT)
    g.OnEvent("Close", (*) => g.Hide())
    g.OnEvent("Escape", (*) => g.Hide())
    AGUI := g
    g.Show("w760 h560")
}

SetupTray() {
    A_IconTip := "startup.ahk — Win+1..9 切工作区（komorebi 要先手动启动）；双击看说明"
    tm := A_TrayMenu
    tm.Delete()
    tm.Add("说明 / 主界面", (*) => ShowMainGui())
    tm.Add()
    tm.Add("启动 komorebi（手动）", (*) => StartKomorebi())
    tm.Add("停止 komorebi", (*) => StopKomorebi())
    tm.Add()
    tm.Add("启动 YASB", (*) => StartYasb())
    tm.Add("启动 Flow Launcher", (*) => ShowFlow())
    tm.Add("启动 AltSnap（提权）", (*) => StartAltsnap())
    tm.Add("重装热键", (*) => InstallHotkeys())
    tm.Add()
    tm.Add("打开日志", (*) => OpenLog())
    tm.Add()
    tm.Add("退出（保留 komorebi / YASB / Flow）", (*) => ExitApp())
    tm.Add("退出并停止 komorebi", (*) => QuitKomorebi())
    tm.Default := "说明 / 主界面"         ; 双击托盘图标 = 打开主界面
}

; =====================================================================
; 主流程
; =====================================================================
MainEntry() {
    EnsureDirs()
    LogRaw("=== startup.ahk 启动 ===")
    StartEtu()          ; 必须最先：它自带键盘钩子，钩子后装的先拿到按键
    ; StartYasb()
    StartFlow()
    InstallHotkeys()
    SetupTray()
    SetTimer(StartAltsnap, -500)     ; 提权会弹 UAC（会占到用户点完为止），放最后别挡前面的事

    if (ProcessExist("komorebi.exe")) {
        LogOk("komorebi 已在运行，热键可直接用")
        try TrayTip("Win+1..9 切工作区 · Win+Shift+1..9 移窗口 · Win+F 浮动 · Win+Shift+E 退出 komorebi · Win+R Flow · Alt+Shift+Q 关窗口 · 右Alt→F2", "startup.ahk 已就绪")
        return
    }
    LogWrn("komorebi 没在跑（本脚本不再自动启动它）；右键托盘图标 →「启动 komorebi（手动）」")
    try TrayTip("通用热键已生效：Win+R Flow / Alt+Shift+Q 关窗 / 右Alt→F2；Win+1..9 等平铺热键要启动 komorebi 后才生效。", "startup.ahk 已就绪（komorebi 未启动）", "Icon!")
}

OnExit(OnExitHandler)
OnExitHandler(Reason, Code) {
    RemoveHotkeys()
    LogAt("信息", "退出（" . Reason . "）：只卸下自己的热键，YASB / Flow Launcher / ExplorerTabUtility 不动")
    return 0
}

MainEntry()
