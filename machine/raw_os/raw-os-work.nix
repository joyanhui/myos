{
  lib,
  config,
  username,
  global_settings,
  ...
}:
{
  imports = [ ./raw-os-runtime.nix ];

  swapDevices = [ ];

  home-manager.users.${username} =
    { config, lib, ... }:
    {
      xdg.configFile."niri/config.kdl".source = lib.mkForce (
        config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/modules/desktop/niri_rawos_config.kdl"
      );

      xdg.configFile."rio/config.toml".text = lib.mkForce ''
        [window]
        opacity = 0.85
        blur = true

        [shell]
        program = "fish"

        [cursor]
        shape = "beam"

        [fonts]
        family = "Sarasa Fixed SC"
        size = ${toString global_settings.font.size.term}
      '';

      programs.brave.commandLineArgs = lib.mkForce [ "--password-store=basic" ];
    };
}
