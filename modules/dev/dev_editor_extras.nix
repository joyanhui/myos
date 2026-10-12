{
  username,
  lib,
  config,
  global_settings,
  hmStandalone ? false,
  ...
}:
if hmStandalone then
  {
    home.file.".npmrc".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.secretsDir}/node_bun_deno.npmrc";
  }
else
  {
    services.gnome.glib-networking.enable = true;

    home-manager.users.${username} = { config, ... }: {

      home.file.".npmrc".source =
        config.lib.file.mkOutOfStoreSymlink "${global_settings.secretsDir}/node_bun_deno.npmrc";
    };
  }