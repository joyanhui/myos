{
  pkgs,
  username,
  global_settings,
  ...
}:
let
  helixHelp = pkgs.writeShellScriptBin "helix-help" ''
    cat <<'EOF'
    Helix 常用快捷键

    模式：普通模式按 i 进入插入模式，按 v 进入选择模式，Esc 返回普通模式

    ┌────────────────────┬──────────────────────────────────────┐
    │ 操作               │ 按键                                 │
    ├────────────────────┼──────────────────────────────────────┤
    │ 删除当前行         │ xd（x 选择整行，d 删除）               │
    │ 删除光标至行尾     │ vgl d（选择至行尾后删除）               │
    │ 跳转到行首         │ gh                                   │
    │ 跳转到行尾         │ gl                                   │
    │ 跳转到第一行       │ gg                                   │
    │ 跳转到最后一行     │ ge                                   │
    │ 全选               │ %                                    │
    │ 撤销 / 重做        │ u / U                                │
    │ 复制 / 粘贴        │ y / p                                │
    │ 搜索               │ /（输入后回车），n / N 下一个/上一个 │
    ├────────────────────┼──────────────────────────────────────┤
    │ 当前文件全部替换   │ %s旧内容␠c新内容␠（␠表示空格键）     │
    │ 当前选择内替换     │ s旧内容␠c新内容␠（␠表示空格键）      │
    │ 全目录搜索         │ 空格 + g（输入搜索内容）              │
    │ 全目录替换         │ 空格 + g 搜索后逐项打开并替换          │
    ├────────────────────┼──────────────────────────────────────┤
    │ 打开 Yazi 文件管理器│ Ctrl+y                                │
    │ 打开 Lazygit        │ Alt+g                                 │
    │ 打开 Zsh 终端       │ Alt+t                                 │

    提示：替换操作中 ␠ 表示按空格键；全目录搜索结果需逐项打开后在文件内替换。
    EOF
  '';
in
{
  home-manager = {
    users.${username} =
      { config, ... }:
      {
        home.packages = with pkgs; [
          helix
          helixHelp
          #helix-gpt
        ];
        xdg.configFile = {
          "helix/config.toml".source =
            config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/helix_config.toml";
          "helix/languages.toml".source =
            config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/helix_languages.toml";
        };
      };
  };
}
