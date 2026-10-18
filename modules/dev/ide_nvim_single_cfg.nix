{
  pkgs,
  username,
  global_settings,
  ...
}:
let
 readme=''
单文件init  要求 neovim 0.12

借鉴 ： https://github.com/onjin/nvim

 '';
in
{
  home-manager = {
    users.${username} =
      { config, ... }:
      {
        home.packages = [ pkgs.neovim pkgs.tree-sitter ];

        xdg.configFile."nvim/init.lua".source =  config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/nvim_init.lua";
        xdg.configFile."nvim/nix.readme.md".text=readme;
      };
  };
}
