{
  username,
  global_settings,
  ...
}:
let
  readme = ''
    # AI CLI 工具安装命令（bun 全局，供参考）
    bun install -g opencode-ai@latest
    bun add -g --ignore-scripts @earendil-works/pi-coding-agent
    # 配置文件由本模块软链：opencode 在 ~/.config/opencode，pi 在 ~/.pi/agent
    # Credential-bearing files are sourced from security/_protected/, whose committed contents are protected by repository transcrypt encryption (opencode.json / pi_auth.json); models.json contains no credentials and stays in dotfiles
  '';
in
{
  home-manager = {
    users.${username} =
      { config, ... }:
      {
        home.file = {
          # opencode
          ".config/opencode/opencode.json".source =
            config.lib.file.mkOutOfStoreSymlink "${global_settings.secretsDir}/opencode.json";
          ".config/opencode/tui.json" = {
            source = config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/opencode_tui.json";
            force = true;
          };

          # pi
          ".pi/agent/auth.json".source =
            config.lib.file.mkOutOfStoreSymlink "${global_settings.secretsDir}/pi_auth.json";
          ".pi/agent/models.json" = {
            source = config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/pi_models.json";
            force = true;
          };
          ".pi/agent/settings.json" = {
            source = config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/pi_settings.json";
            force = true;
          };
          ".pi/agent/pi-goal.json" = {
            source = config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/pi_goal.json";
            force = true;
          };
          ".pi/agent/SYSTEM.md" = {
            source = config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/pi_global_AGENTS.md";
            force = true;
          };
          # skills 与 mcp
          ".agents/skills".source =
            config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/modules/ai/skill";
          ".config/mcp/mcp.json" = {
            source = config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/mcp.json";
            force = true;
          };
          # readme
          ".cargo/rust.nix.readme.md".text = readme;
        };
      };
  };
}
