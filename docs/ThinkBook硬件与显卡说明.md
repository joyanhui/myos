# ThinkBook 14p (AMD) 独显 MX570 4G 调查记录

本文记录本机独显的身份确认、问题根源分析及启用方案。信息来自公开资料与工程机案例,最终方案需以本机实测为准。

## 独显身份

- 机型:联想 Rembrandt 平台工程机(ThinkBook 14+/14p 同族模具),CPU 为 Ryzen 7 6800U 工程样品(料号 100-000000534-40_Y)
- 独显:NVIDIA GeForce MX570 4GB(工程样品),GA107 核心
- 同款料号工程机的公开记录(哔哩哔哩 thinkbook14+ gen4 工程机小结)确认该工程机独显为 MX570 4G,惠普 envy17 cr1000 工程机也是同款 MX570 4G
- 正式零售版同模具(ThinkBook 14+ 2022 AMD)的独显为 RTX 2050 4GB,均为 GA107,驱动通用
- 正式版 MX570 的 PCI ID 为 10de:25a6 / 25a7 / 25aa(MX570 A),其中 25aa 存在 4GB VBIOS(三星机型,techpowerup 268551)
- GA107 系列存在专属工程样品 ID(如 RTX 3050 ES = 25af),本机 MX570 4G 的 PCI ID 需启用独显后通过 lspci 确认

## 问题根源

- 驱动层面:MX570 4G 为工程样品,NVIDIA 官方为给 RTX 2050 让路,从未为 4GB 版提供正式驱动支持;惠普工程机强装驱动后不显示显存
- 但正式版 MX570(2GB/4GB,25aa)与 RTX 2050 的驱动一直存在:联想官网 2025-04 版本 32.0.15.6094 仍同时支持 MX570 与 RTX 2050;NVIDIA Linux 驱动 470.103.01 起支持 GA107 全系(MX570/RTX 2050/RTX 3050)
- BIOS 层面:独显供电由 BIOS/PCH 信号控制(如 DGPU_PWR_EN),工程机 BIOS 可能未正确配置独显供电与电压分配,导致 GPU 无法初始化、驱动读不到显存
- 结论:问题可能同时涉及 BIOS 供电配置与驱动设备 ID 白名单,需分步排查

## 启用方案(按优先级)

### 1. 重新启用独显并确认 PCI ID(第一步,必做)

- BIOS 中重新启用独显,进系统执行 lspci -nn | grep -i nvidia
- 记录 device ID(25a6/25aa 为正式 MX570,25af 之类为工程样品 ID),决定后续路线
- 记录 VBIOS 版本(lspci -v 或 nvidia-smi)

### 2. 刷正式版 BIOS(解决供电/电压分配问题)

- 同款工程机记录显示 BIOS 可从 17 版本升级到 47 版本,说明工程机可刷正式版 BIOS
- 正式版 BIOS 含正确的独显供电时序与电压分配配置,可解决 GPU 无法初始化问题
- 风险:工程机刷 BIOS 有真实变砖案例(联想 IDEAPAD SLIM 5 13代工程机、YOGA Pro 14s 工程机、Dell Precision 7540 ES 均刷正式 BIOS 后变砖)
- 最大风险点:正式零售版 BIOS 很可能不含 ES CPU(6800U 工程样品)的微码/支持表,刷后可能无法开机自检;同款机器有成功先例,但无法保证
- 刷之前务必用编程器夹子备份原 BIOS 至少两份(AMD 版 EC 与 BIOS 集成在同一个 32MB SPI Flash,恢复时 EC 与 BIOS 版本必须匹配)
- 恢复手段:联想 Fn+R + 电源键 Crisis Recovery(USB 盲刷,部分机型支持);无效则需编程器直刷芯片,自己无工具基本无法恢复
- BIOS 来源:联想官网按机型下载,或联想电脑管家;可先私信同款工程机作者确认其 BIOS 来源与版本号全称

### 2.1 刷 BIOS 风险案例

- 联想 IDEAPAD SLIM 5 13代工程机:刷零售版 BIOS 后黑屏死机,只能编程器救砖
- 联想 YOGA Pro 14s 2021 工程机:升级 BIOS 后开机黑屏,靠刷前编程器备份恢复
- Dell Precision 7540 ES:刷正式 BIOS 后变砖
- INTEL NUC ES:软件检测硬件不同禁止更新,强行解锁更新后直接挂掉
- HP EliteBook 830 G9 ES:工程 BIOS 含 ES CPU 支持,刷正式 BIOS 后该支持丢失

### 3. Linux 开源驱动路线(nouveau + NVK)

- GA107 的 NVIDIA 签名固件已公开,Linux 6.2+ nouveau 支持 Ampere 3D 加速
- NVK(Mesa 25.x 起)是 Vulkan 1.3 conformant 驱动,支持 Ampere
- nouveau 按 GPU 架构匹配设备,不依赖具体 device ID 白名单,对工程样品最友好
- 适用场景:渲染、Vulkan 计算;无 CUDA,不适合 LLM 推理
- NixOS 启用:nixpkgs.config.nvidia 不适用,需配置 nouveau(默认开启)+ firmware + 最新 mesa

### 4. Windows 下 NVIDIA-patcher 强制安装驱动

- dartraiden/NVIDIA-patcher 专为 ES/未发布 GPU 设计(支持 RTX 3080 Ti 20GB、L40 ES、RTX 5080M ES 等)
- 原理:解包官方驱动,替换 nvlddmkm.sys 等文件绕过硬件 ID 检查
- 适合 Windows 下使用;若 PCI ID 为正式 MX570 则无需补丁,联想官方驱动直接支持

### 5. 刷 MX570 A 4GB VBIOS

- techpowerup 268551 提供三星机型的 MX570 A 4GB VBIOS(25aa,94.07.8F.40.5E)
- 若驱动加载后显存为 0/异常,可能是 VBIOS 显存配置问题,可用 nvflash 刷该 4GB VBIOS
- 风险高:笔记本独显 VBIOS 刷写可能失败;但独显刷坏不影响核显,系统仍可用
- 前提:驱动或至少 lspci 能访问到 GPU

## 性能预期

- MX570 4G 为 GA107 入门级,25W 左右,性能接近 RTX 2050,明显强于 Radeon 680M 核显
- 即使启用成功,也不适合作为主力游戏卡,适合 CUDA 计算、视频编解码等场景

## 参考资料

- 哔哩哔哩:thinkbook14+ gen4 工程机小结(作者:班尼迪克在奥地利,2023-12-17) https://www.bilibili.com/opus/876114006319824932
- TechPowerUp:MX570 A 4GB VBIOS(Samsung, 25aa, 94.07.8F.40.5E) https://www.techpowerup.com/vgabios/268551/268551
- GitHub:dartraiden/NVIDIA-patcher(ES GPU 驱动补丁) https://github.com/dartraiden/NVIDIA-patcher
- NVIDIA Linux 驱动 470.103.01 发布说明(支持 RTX 2050/MX570/MX550) https://www.nvidia.com/en-us/geforce/drivers/results/186996/
- linux-hardware.org:GA107M [GeForce MX570 A] 10de:25aa(Ubuntu 24.04 认证) https://linux-hardware.org/?id=pci:10de-25aa-1028-0ca3
- 联想官网 NVIDIA VGA 驱动(支持 MX570/RTX 2050) https://newsupport.lenovo.com.cn/driveDownloads_detail.html?driveId=130187
- 迅维网:联想 IDEAPAD SLIM 5 13代工程机升级零售版BIOS变砖 https://www.chinafix.com/forum.php?mod=viewthread&tid=1357517
- 迅维网:联想 YOGA Pro 14s 2021皮革版工程机升级BIOS开机黑屏 https://www.chinafix.com/forum.php?mod=viewthread&action=printable&tid=1399733
- Win-Raid:Dell Precision 7540 (ES) bricked by BIOS update https://winraid.level1techs.com/t/dell-precision-7540-es-bricked-by-bios-update/39770
- superuser:Lenovo BIOS Crisis Recovery(Fn+R) https://superuser.com/revisions/90e57306-161f-4886-90c1-474aeb435953/view-source
