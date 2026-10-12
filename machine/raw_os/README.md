- AI agents may read and reference this file, but MUST NEVER modify it in any way.Provide suggestions only; all changes require manual human editing.

# img-core

img-core 是本项目中用 NixOS repart来构建一个可引导虚拟磁盘镜像的一个host。

构建命令: `nix build --no-link --print-out-paths  .#nixosConfigurations.raw_core.config.system.build.image --option substituters https://cache.nixos.org`

构建后的文件 可以烧录到硬盘/u盘直接启动 或者作为文件放在物理分区内通过efi+gurb2启用，或者通过其他方式转换为虚拟机软件可识别的格式用虚拟机启动。

## 虚拟磁盘镜像文件内架构

GPT raw 镜像（nixos.raw）内含 ESP 分区与 btrfs root 分区（label nixos-root）

## 多种启动方式

### 烧录或者 dd 到 U 盘/硬盘

过程略 用dd命令即可。

### 从文件物理启动

原理gurb2 自动搜索 第一个卷标里面带字符IMG的分区，然后把这个分区下的nixos.raw 用loopback挂载，然后读取里面的 /nix/store 的 kernel 与 initrd 完成启动。

#### 镜像文件和卷标
- 把 镜像文件 复制到 物理分区内（必须放在分区根目录下的 OS-img目录下，文件名必须是nixos.raw ，可使用ntfs分区，比如 V:/OS-img/nixos.raw），

#### 引导
需要把 grubx64.efi 复制到 EFI 分区并注册给bios/UEFI
windows安装后一般会默认创建一个ESP分区是隐藏的，这个就是FAT32分区。几乎所有安装过window的电脑都带这个分区。 （名字带ESP 一般300MB大小）

#### Windows下操作方法。
可以在window下 也可以是winpe

- 放引导文件 给efi/ESP分区分配一个卷标  用 Diskgenius 找到对应的分区，浏览  把 grubx64.efi 拖拽到 /EFI/Boot/下 。
   也就是 /EFI/BOOT/grubx64.efi (也可额外复制一份到 /EFI/BOOT/BOOTX64.EFI做兜底（如果你系统上没有这个文件的话，有的话不要覆盖）)
   如果你电脑上有bootx64.efi这个文件大概率是Windows自己的，不要管，也不要删除。 


- 注册引导到UEFI  打开 Diskgenius 点击 工具  设置UEFI启动项 点击添加 在上面的选择分区找到对应的分区，然后选中 /EFI/Boot/grubx64.efi，
  然后设置 启动项名字 例如 NIXOS-IMG  调整顺序  点击 保存当前启动项设置
  
启动测试： 重启电脑，按下电脑的 启动选择菜单，或者进bios把 新增的 启动项 NIXOS-IMG 设置为默认，然后启动

### 虚拟机启动
#### 使用QEMU + whpx
最简单的方案 就是 使用QEMU（qemu-system-whpx），替代hypr-v管理器当作前端，后端使用hyper-v/wsl，更方便灵活。
cpu性能和磁盘性能基本没损耗，网络虽然支持virio但是实际性能会差点，图形性能的问题后期可能优化的潜力大。
需要一个OVMF.fd 文件

完整命令 参考

```powershell

& "C:\Program Files\qemu\qemu-system-x86_64.exe" `
     -machine q35 `
     -accel whpx `
     -cpu max `
     -smp 4 `
     -m 4096 `
     -drive if=pflash,format=raw,readonly=on,file=v:\OS-img\OVMF.fd `
     -drive file=v:\OS-img\nixos.raw,format=raw,if=virtio `
     -netdev user,id=n0 `
     -device virtio-net-pci,netdev=n0 `
     -vga virtio `
     -display gtk `
     -device qemu-xhci,id=xhci `
     -device usb-tablet,bus=xhci.0
	 
```
virtio-vga 比默认 std/vga 细腻、更省 CPU， display 换 GTK，好像更好一点。

#### virtural box
vbox默认是支持raw格式的虚拟磁盘。
#### vmware虚拟机
需要做一个 vmdk描述文件映射这个镜像文件，或者干脆用qemu-disk转换为vmdk 或者套娃
参考 https://community.broadcom.com/vmware-cloud-foundation/discussion/specify-disk-location
#### hypr-v 启动

想要同一个镜像文件同时支持hyper-V和物理机启动,整体实现具有可行性，但是非常复杂得不偿失。而且 使用hyper-v gen1做前端，图形加速也是一个深坑。。
只记录思路
1 限制：hyper-v gen2 不支持vhd只支持vhdx，而grub+loopback方案很难支持vhdx，所以路径只有hypr-v gen1（一代机）但是gen1 不支持efi引导
2 镜像文件的兼容性 固定大小的vhd格式实际是raw格式文件在文件末尾增加一点描述信息，grub+loopback方案可以兼容固定大小的vhd文件不需要额外处理。
3 raw转换为固定大小的vhd文件，可以用脚本搞不复杂，也可以直接用qemu-img等工具把raw转换为固定大小的vhd。
4 改造grub+loopback 让它搜索文件的时候搜索 .vhd后缀
5 镜像文件内部的必须使用双引导（mbr/bios + efi），nix构造完成的镜像转换为vhd后，需要在kvm用其他系统启动起来执行一次grub-install。或者写一个复杂的脚本来搞。
因为systemd-boot不支持mbr/bios引导，最好换成grub同时管理双引导，即便如此也因为需要给镜像额外处理一次引导也会非常复杂。



## 常用命令和操作


### 构建新nixos系统的基础可启动虚拟磁盘

最小尺寸2g,建议4-7g以上。
```bash
nix build --no-link --print-out-paths .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image
```

`--print-out-paths` 会在构建结束后直接打印产物路径；否则可以查找最新的 `nixos.raw`：

```bash
find /nix/store -maxdepth 2 -name nixos.raw -newer /etc/machine-id 2>/dev/null
ls -dt /nix/store/*-nixos | head -1
```
### 扩容现有镜像

使用 `machine/raw_os/docs_script/resize-raw-image.sh`，扩容前应确保没有其他程序同时写入目标镜像。

```bash
# 扩展镜像文件、GPT 第二分区和 Btrfs 文件系统
machine/raw_os/docs_script/resize-raw-image.sh nixos.raw 20G --resize-btrfs

# 只扩展镜像文件和 GPT 第二分区，不扩展 Btrfs
machine/raw_os/docs_script/resize-raw-image.sh nixos.raw 20G --skip-btrfs-resize
```

镜像启动后，也可以使用镜像内提供的同名命令扩展另一个未挂载的镜像：

```bash
sudo resize-raw-image /mnt/other/nixos.raw 20G --resize-btrfs：
```

脚本只允许增加容量：目标容量必须严格大于当前容量，不使用 `qemu-img resize --shrink`，并在扩容后再次核对实际容量；任何缩容或保持原容量的请求都会直接失败。`--resize-btrfs` 会在扩展第二分区后临时创建 loop 设备、挂载 `nixos-root` 并执行 `btrfs filesystem resize max`；`--skip-btrfs-resize` 只扩展镜像文件和第二分区。

### 改为实际占用磁盘和避免水平
QEMU 的 raw 格式天然支持 sparse，固态硬盘文件碎片几乎不影响性能。并不是非做不可。

```bash
cp --sparse=never nixos.raw nixos-full.raw #强制全量复制即可 占满磁盘

dd if=nixos.raw of=nixos-tmp.raw bs=4M conv=notrunc status=progress # linux下DD一次 就可以连续
contig.exe N:\nixos.raw  # win下整理即可连续占用

```

## 脚本位置

raw 镜像相关脚本统一位于 `machine/raw_os/docs_script/`：

- `resize-raw-image.sh`：按参数扩容 raw 镜像
- `create-grubx64-efi.sh`：根据 `boot.json` 生成外部 loopback 引导文件
- `additional-foot-to-raw-and-renameVHD.sh`：将 raw 镜像转换为 fixed VHD，成功后删除原始 `.raw` 文件

## 关于各种启动方式
如果镜像烧录到硬盘 或者 直接给虚拟机直接做虚拟磁盘使用，此时直接使用镜像内的efi分区的systemd-boot启动 不需要再grub2+loopback方案。

只有通过直接启动 虚拟镜像文件的时候 才会使用 grub2+loopback来启动
### 关于 grubx64.efi

当前生成脚本位于 `machine/raw_os/docs_script/create-grubx64-efi.sh`。脚本需要 `jq` 和 `grub-mkstandalone`，例如：

```bash
nix shell nixpkgs#jq nixpkgs#grub2_efi -c machine/raw_os/docs_script/create-grubx64-efi.sh <boot.json> -o grubx64.efi
```

这个grubx64.efi内部嵌入一个 grub.cfg 文件，用来完成  如下操作
```bash
 search --no-floppy --set=root --file /nixos.raw
 set vdisk=($root)/nixos.raw
 loopback loop0 $vdisk
 linux (loop0,gpt2)/nix/store/<nix-hash-string>-linux-<ver>/bzImage
 init=/nix/store/<nix-hash-string>-nixos-system-nixos-<ver>/init root=fstab loglevel=7
 console=ttyS0,115200 console=tty0
 initrd (loop0,gpt2)/nix/store/<nix-hash-string>-initrd-linux-<ver>/initrd
 boot
```
首次启动的时候，相关的hash以及内核版本号系统版本号码需要通过现存的nixos.raw文件获取，或者通过nix获取。

启动后nixos.raw 如果进行过一些牵扯系统更新和内核更新的nixos-rebuld会导致grub.cfg失效，所以需要修正 grub.cfg

### img 内更新脚本

img 内封装了一个 命令 sudo update-grubx64-loopback-efi 用来在 nixos-rebuild 后手动更新 grub2-loopback的efi方便。
