# Wine/Bottles 运行红警 2 与 Ares

本文记录本机 RA2/Yuri's Revenge 在 Wine/Bottles 下的验证方式与已知限制。原版游戏与 Ares 注入是两条不同启动链；战网平台测试也不能以其中任一链的成功替代。

## 目录与 Bottle

- 独立测试目录：`/home/nixos/Games/RA2/For_Map_Test`
- 专用 Bottle：`RA2-For-Map-Test`，32 位、Caffe 9.7；已登记 `Yuri Revenge`（`gamemd.exe`）和 Syringe 测试程序。
- `Game` Bottle 也曾用于运行该目录。不要把两个 Bottle 的 runner、DLL override 或程序参数当成相同配置。
- 本机 `RA2-For-Map-Test` 的 `bottle.yml` 有 `ddraw: native` override，且已登记程序的 Syringe 参数是 `gamemd.exe -SPAWN`。后者没有保留 Syringe 所需的目标文件名引号，不能据此认定注入成功。

## 原版 RA2/Yuri's Revenge

- 已验证原版可进入游戏。使用游戏目录内的 `RA2MD.EXE` 作为启动入口；直接运行 `gamemd.exe` 曾快速返回，不能据此判断游戏不可运行。
- 原版显示曾由用户确认正常。不要把游戏自身的缩放、黑边或画面布局机制误判成 Wine 故障。
- 该目录中的本地 `ddraw.dll` 是 cnc-ddraw。Wine 若加载 runner 自带的 `ddraw.dll`，可能出现渲染差异；需要时以 Bottles 的该 Bottle DLL override 让游戏目录 DLL 生效，并通过进程实际加载模块和游戏画面确认，而非只看配置写入成功。
- `RA2MD.INI` 是游戏设置文件。调整分辨率或窗口模式前先记录原值；不要将原版验证时的显示设置擅自套用到战网平台目录。

## Ares 启动与注入

- 测试目录中的 `Ares.dll`、`Ares.dll.inj`、`Syringe.exe` 和 `gamemd.exe` 是不同组件：存在这些文件或裸启动某个 exe，不等于 Ares 已注入。
- Syringe 的调用结构是 `Syringe.exe "<目标游戏 exe>" <游戏参数>`。目标 exe 名称必须作为一个带引号的参数传入；`-SPAWN` 等游戏参数属于目标程序参数，不要混为 Syringe 的选项。
- Bottles 的程序参数字段、CLI 的 `--args-replace` 以及 shell 包装可能移除或重新解析双引号。运行后要核对 Wine 实际收到的命令行、Syringe 日志、游戏进程及其模块；出现 Syringe usage 窗口不算启动测试。
- Ares 运行验证以实际游戏窗口/主菜单和 Ares 注入日志为准。用户已确认此前曾多次看到 Ares 游戏正常运行；但当前目录登记的 `Ares-Syringe-Spawn-Test` 参数存在引用问题，不能把这个登记项作为已验证的可复用命令。
- 测试 Bottle 或副本优先于改正式游戏目录。更换 Syringe、Ares、Bink 等文件前先核对游戏版本与组件清单并保留原文件；不要用不兼容的 `Binkw32.dll` 改名替代 `Binkw64.dll`。

## 战网平台的区别与当前状态

- HTPlatform 的“测试运行”会运行平台自己的 `gamemd-spawn.exe`、`EDRAW.dll`、Bink 与 Syringe/Ares 注入链。原版 RA2 或独立目录 Ares 能运行，不代表平台测试已通过。
- 平台测试通过标准是：完成平台真实测试流程、游戏正常进入，平台接受测试并保存游戏路径。配置页显示目录或短暂出现游戏进程都不够。
- 本机平台目录 `C:\Ra2Game412` 的 `Binkw64.dll` 曾报 `NtProtectVirtualMemory` hook 错误。平台自带 HTPack 中的 2026 版 Bink 曾替换该文件，原版文件保存在 `Binkw64.dll.pre-htpack-2026.bak`；替换后测试曾出现要求在游戏内按 ESC 退出测试的提示，但未确认平台保存路径或测试完整成功。此平台问题仍应标为未验证，不能据此宣称战网已修复。
- 恢复旧 Bink 前核对备份哈希与平台文件清单；不要在游戏仍运行时替换 DLL。不要因用户主动关闭游戏就把进程消失判定为崩溃。

## 验证原则

- 分开验证原版、Ares 注入和 HTPlatform 测试，不跨启动链推断结果。
- 每次测试记录 Bottle 名称、runner、工作目录、实际命令行、DLL override、窗口/游戏内结果及日志。
- 未观察到错误不等于成功；以目标游戏实际进入和该流程要求的状态持久化为验收条件。
