# Waydroid 配置记录（翻译层 / 固件选型 / 摄像头）

Waydroid 1.6.3 + 官方 Android 13（lineage-20.0 GAPPS）+ libhoudini 14 的最终配置。
本文只记录翻译层选择、固件尝试结果和摄像头方案，不写无关内容。

## 翻译层（唯一选择：libhoudini 14）

- 使用 **libhoudini 14**（Intel 官方 ARM 转译层，从 Google Play Games 提取），
  解压到 `/var/lib/waydroid/overlay/system/`（bin/lib/lib64/etc）。
- cfg 里 `ro.dalvik.vm.native.bridge = libhoudini.so`，ABI 列表含 arm64-v8a。
- **libndk 已禁用**：性能差、兼容性差（实测微信/应用卡死），永远不用。
- libhoudini 11（Android 11 用）比 14 慢，A11 时代验证过，不用。

## 固件尝试结果（全部试过）

| 固件 | 结果 |
|------|------|
| A13 官方（lineage-20.0 GAPPS）| 微信流畅，但自带 external camera 摄像头黑屏（YUV 错误）|
| A13 WayDroid-ATV（20260106）| 相机流能开但 app 黑屏 + system_server 崩溃 |
| A14 WayDroid-ATV（20260125）| AMD GPU 强制 amdgpu gralloc，surfaceflinger 崩溃无法进桌面 |
| A11 WayDroid-ATV（20240801）| Camera1 有画面，Camera2 被拒（endConfigure），微信人脸不可用 |
| A10 官方（lineage-17.1）| SurfaceFlinger 崩溃，系统起不来 |
| e/OS（20260201）| 系统完整稳定，但 external camera 同样 YUV 黑屏；libhoudini 下微信启动超时 |
| kde-yyds 第三方 A13 | 自带 camera.v4l2（唯一亮点），但镜像缺组件 system_server 卡死 |

结论：**官方 A13 是最稳定底座**（微信/libhoudini 兼容最好），加上 camera.v4l2 移植解决摄像头。

## 摄像头方案（camera.v4l2 移植）

官方 A13 的 external camera HAL 有 YUV layout bug（gralloc 拿不到 NV12 布局），
所有 app 黑屏。解法：**移植 Android-x86 的 camera.v4l2 传统 HAL**（kde33 镜像里提取），
绕过 external camera：

1. 从 kde33 镜像提取 camera.v4l2.so + legacy provider 组件（provider@2.4-service、
   provider@2.4-impl、legacy、camera.device@1.0-impl 等）放入 overlay/vendor。
2. vintf manifest 加 legacy/0 实例（合并进 camera.provider 块，不能重复块）。
3. 编译 PermissionCache shim（纯汇编返回 true），patchelf 加到 provider 二进制和
   libgui 的 NEEDED——解决 VNDK libbinder 缺 PermissionCache 符号的问题。
4. 禁用 external provider（rc 加 disabled），让 camera.v4l2 独占 /dev/video0。
5. 依赖库（libcamera_client/libgui/libEGL 等）用 e/OS 镜像的版本放 overlay/vendor/lib。

结果：
- Camera1（Open Camera）有画面。
- Camera2 能打开但 camera.v4l2 只支持单流，Aperture 等请求多流会闪退。
- 微信人脸识别（Camera2 + arm64 人脸组件）无法完成：组件经 libhoudini 翻译
  初始化超 13 秒，微信自动杀进程。

## 微信结论

- 8.0.76（arm64）：SIGILL 崩溃（libhoudini 翻译微信 native 代码非法指令），启动即死。
- 8.0.42（32 位）：SIGSEGV 崩溃（libhoudini 32 位路径）。
- libndk 能跑但性能差，已禁用。
- **微信在 waydroid 下不可用**，这是翻译层兼容性的硬限制。

## 网络与代理

- 容器静态 IP：192.168.240.112（eth0），需手动配置：
  `ip addr add 192.168.240.112/24 dev eth0; ip rule add from all lookup main pref 5000`
- 容器代理指向宿主机 mihomo：`settings put global http_proxy 192.168.240.1:7890`（已验证 204）。

## 其他注意事项

- 分辨率/密度：`setprop persist.waydroid.width 720; height 1600`；density 改 cfg
  `ro.sf.lcd_density`（200 较小，320 较大）。
- fcitx5-android 是可用输入法（x86_64 原生），Gboard 翻译层下滑行卡顿不用。
- 镜像放 `/etc/waydroid-extra/images/`（preinstalled，避免 OTA 下载）。
- 仓库根目录禁止裸 `nix build`。
