# 私密安全文件

## 加密与使用

`security/_protected/` 中的敏感文件由 transcrypt 加密提交，cipher 固定为 `aes-256-cbc`；`security/placeholder_files/` 保存不加密的占位文件。

在已配置 transcrypt 的工作区中，Git 会在暂存时加密 `_protected/` 文件，在签出或读取工作区时解密。新克隆仓库需要在仓库根目录执行：

```sh
transcrypt -c aes-256-cbc
```

执行时由使用者交互输入与源仓库相同的密码。不要将密码写入命令参数、源码、文档、日志或其他仓库文件。transcrypt 的本地配置保存在 `.git/config`，不提交到仓库。

Nix 通过检查 `_protected/isDecryptedCheckFileLen.txt` 的内容选择配置目录：内容为 `1` 或 `1\n` 时使用 `_protected/`，否则自动使用 `placeholder_files/`。检查使用文件哈希，不会读取 transcrypt 密文内容，因此未解密时也能正常回退。

修改敏感内容时需要同时更新 `_protected/` 下的真实文件以及 `placeholder_files/` 中的占位文件。`isDecryptedCheckFileLen.txt` 的解密内容必须保持为单个字符 `1`，允许末尾换行。

## 目录结构

```sh
security/
├── _protected/                       # 真实敏感文件（transcrypt 加密提交）
│   ├── fcitx5_rime_custom_phrase.txt
│   ├── floccus.export.json
│   ├── mihomo.yaml
│   ├── node_bun_deno.npmrc
│   ├── opencode.json
│   ├── openssh_auth_keys_and_passwd.nix
│   ├── pi_auth.json
│   ├── rclone.conf
│   ├── sensitive_env.nix
│   ├── isDecryptedCheckFileLen.txt  # 解密后内容为 1 或 1\n
│   └── 其他文件
├── placeholder_files/                # 同名占位符/模板（明文提交）
└── README.md                         # 本文件
```

Git 历史中迁移前的提交仍可能使用 git-crypt 格式；本次迁移不重写历史。仓库继续保留 `git-crypt` 和 `transcrypt` 软件包，以便访问旧历史和管理当前加密文件。
