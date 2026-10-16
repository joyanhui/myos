{
  pkgs,
  username,
  global_settings,
  ...
}:
let
  readme = ''

    配置使用lazyvim 但是不深度绑定nix
  '';
in

{
  home-manager = {
    users.${username} =
      { config, ... }:
      {
        home.packages = with pkgs; [
          neovim
        ];

        xdg.configFile = {
          "nvim/init.lua".source =
            config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/nvim_lazyvim_init.lua";
          "nvim/lua/config/lazy.lua".source =
            config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/nvim_lazyvim_lazy.lua";
          "nvim/lua/plugins/example.lua".source =
            config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/nvim_lazyvim_example.lua";

          # readme
          ".nvim/nvim.readme.md".text = readme;

        };
      };
  };
}
