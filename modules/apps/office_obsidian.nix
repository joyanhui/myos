{
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    users.${username} =
      { config, ... }:
      {
        home.packages = with pkgs; [
          obsidian
        ];

        #  home.file.".obsidian/snippets/page_width.css".source =
        #    config.lib.file.mkOutOfStoreSymlink "${repoDir}/modules/apps/configFile/obsidian/page_width.css";
      };
  };
}
