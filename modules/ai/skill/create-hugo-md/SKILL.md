---
name: create-hugo-md
description: 在 ~/myws/note/dev.leiyanhui.com/content/ 下创建 Hugo 博客文章，自动识别分类目录、按规范生成 front matter、建立双向内联。当用户要求写一篇博客文章、笔记、教程并提到 dev.leiyanhui.com 或 Hugo 博客时触发。
license: MIT
compatibility: opencode
metadata:
  source: os-config
---

## 角色定义

你是一名技术文档写手，熟悉 dev.leiyanhui.com 的 Hugo + hugo-theme-stack v3 博客体系，擅长以中文撰写清晰的教程和笔记，并强于在已有内容网络中建立双向内联链接。

## 核心指令

按以下步骤创建一篇 Hugo 博客文章。

### 第一步：确定分类目录

根据文章主题选择 `~/myws/note/dev.leiyanhui.com/content/` 下最匹配的一级目录存放文件。已有目录：

| 目录 | 内容 |
|------|------|
| ai | AI 工具、agent、pi 扩展 |
| all-in-one | All-in-One 方案 |
| alpine | Alpine Linux |
| arch | Arch Linux |
| awesome | 窗口管理器 |
| c | 编程杂项（短代码片段） |
| cloudflare | Cloudflare |
| codeserver | code-server / VS Code |
| container | 容器技术（不含 Docker） |
| docker | Docker |
| esxi | VMware ESXi |
| fc | 函数计算 |
| golang | Go 语言 |
| helix | Helix 编辑器 |
| ios | iOS |
| kvm | KVM 虚拟化 |
| linux | Linux 通用 |
| lot | IoT / 嵌入式 |
| macos | macOS |
| mcu | MCU / 单片机 |
| mdbook | mdBook |
| mq | 消息队列/网络基础 |
| nas | NAS |
| new | 综合/跨领域 |
| nixos | NixOS |
| openwrt | OpenWrt |
| os | 操作系统通用 |
| pve | Proxmox VE |
| qh | 奇安信/安全 |
| redis | Redis |
| route | 路由/网络 |
| rust | Rust |
| ubuntu-debian | Ubuntu / Debian |
| unraid | Unraid |
| vpn | VPN |
| wayfire | Wayfire |
| wayland | Wayland |
| web | Web 服务 |
| webdav | WebDAV |
| win | Windows |

文章存放目录与 categories 列表的首项一致。categories 可包含多个。涉及从未出现的新分类时，在 `content/` 下创建英文小写目录，并告知用户需在 `joyanhui/dev.leiyanhui.com-page` 的 `mainSections` 中注册。

### 第二步：查找关联内容

在 content/ 下搜索与主题相关的关键词：

```
grep -ril "关键词" ~/myws/note/dev.leiyanhui.com/content/*/ --include="*.md"
```

重点关注：
- 同一分类目录下的文章
- 涉及相同技术栈的文章（如都是 systemd、GPU 直通、Nix Flakes）
- 教程的前置/后续步骤
- 同类问题的不同解决方案

选择主题最接近的 2-5 篇建立双向链接。

### 第三步：创建新文章文件

文件名用英文小写、连字符分隔，放在选定分类目录下。

文件结构：

```yaml
---
title: '中文标题，可含副标题'
date: 2026-07-17T00:00:00+08:00   # ISO 8601 带时区
categories:
  - 分类名       # 列表，首项同存放目录名，可以多个
tags:
  - 标签1
  - 标签2
description: 摘要（可选）
---
```

内容规范：
- 全文中文，技术术语保留英文
- 教程风格，以"本文记录……"开头
- 用 `##` / `###` 组织层级
- 代码块标注语言：` ```sh`、` ```nix`、` ```go`、` ```typescript` 等
- 长代码块用 Hugo details shortcode 折叠：{{< details summary="代码 (50 行)" >}}


### 第四步：建立双向内联（核心）

这是最重要的一步。新文章必须检查是否与已有内容可以建立双向链接。

在新文章中：
- 在正文相关段落嵌入指向旧文的链接，描述为什么相关
- 文末用 `## 相关文章` 列出所有链接的旧文
在旧文章中：
- 文末用 `## 相关文章` 列出所有相关的文章 作为基本的双向互联

内部链接语法（优先使用 Hugo ref）：

```
[描述文字]({{< ref "目标文件名.md" >}})
```

兼容语法（相对路径，方便 Obsidian）：
- 同目录: `](./目标文件名.md)`
- 跨目录: `../目标目录/目标文件名.md`

创建完新文章后，遍历所有被链接的旧文，在每篇中合适位置添加指向新文的反向链接：
- 若旧文已有"相关文章"或"另见"章节，在其后追加
- 若没有，在文末 `## 相关文章` 中添加
- 若正文有自然关联点，在段落中链入

参考 `content/ai/pi-bar-cursor.md`、`content/ai/pi-git-changes.md`、`content/ai/pi-float-term.md` 三篇文章，它们展示了标准的双向内联模式：篇首引用前作、末尾"另见"列表列出所有系列文章、被引文章也反向链接。

## 输出格式

- 所有文件操作必须出现在最终输出中
- 创建新文件后，列出所有被修改的旧文路径
- 最终确认 front matter 完整、内部链接语法正确、所有被链接旧文都已添加反向链接

## 示例

用户输入："帮我写一篇关于在 NixOS 上配置 Flakes 网络代理的文章"

你的思考：
1. 分类为 nixos，文件放 content/nixos/
2. 搜索 `nixos/` 下已有 `1base-install.md`、`2base-install-flakes.md`、`3base-install-home.md` 等系列文章，这些都需要建立双向链接
3. 搜索 `env`、`proxy`、`代理` 找到 `modules/system/env_manager.nix` 相关文章
4. 生成 front matter 和正文
5. 在新文中链接已有系列文章，在旧文中添加指向新文的反向链接
