# 私密安全文件

## 加密与使用

`security/_protected/` 中的敏感文件由 git-crypt 加密提交，
`security/placeholder_files/` 保存不加密的占位文件；

有密钥时执行 `git-crypt unlock <keyfile>`，nix会通过判断 sensitive_env.nix 的内容决定  是否是用解密后的文件，还是使用占位文件。

修改敏感内容时候需要同时更新 `_protected/` 下的真实文件以及 `placeholder_files/` 中的占位文件，git-crypt 密钥需单独备份保管。

## 目录结构

```sh
security/
├── _protected/                       # 真实敏感文件（git-crypt 加密提交）
│   ├── fcitx5_rime_custom_phrase.txt
│   ├── floccus.export.json
│   ├── mihomo.yaml
│   ├── node_bun_deno.npmrc
│   ├── opencode.json
│   ├── openssh_auth_keys_and_passwd.nix
│   ├── pi_auth.json
│   ├── rclone.conf
│   └── sensitive_env.nix
│   └── 其他文件
├── placeholder_files/                # 同名占位符/模板（明文提交）
└── README.md                         # 本文件
```
