{
  pkgs,
  username,
  global_settings,
  ...
}:
{
  home-manager = {
    users.${username} =
      { config, lib, ... }:
      {
        home.packages = with pkgs; [
          rclone
          nextcloud-client
          sshfs-fuse
          fuse3
          fuse
          kopia
          #rclone-ui
          rclone-browser
          kopia-ui
        ];
        xdg.configFile."rclone/rclone.conf".source =
          config.lib.file.mkOutOfStoreSymlink "${global_settings.secretsDir}/rclone.conf";
      };
  };

}
