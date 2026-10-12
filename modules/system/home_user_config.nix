{ pkgs
, inputs
, username
, moduleTags
, global_settings
, ...
}:
{
  home-manager = {
    backupFileExtension = ".home_manager_backup";
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit inputs username moduleTags global_settings; };
    users.${username} = {
      #imports =[];
      home.username = "${username}";
      home.homeDirectory = "/home/${username}";
      home.stateVersion = global_settings.stateVersion;
      programs.home-manager.enable = true;
    };
  };
  users.mutableUsers = false;
  security.sudo.wheelNeedsPassword = false;
  users.users.${username} = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = [
      "wheel"
      "users"
      "libvirtd"
      "vboxusers"
      "kvm"
      "video"
      "dialout"
      "docker"
      "lxc"
      "plugdev"
      "nginx"
      "input"
    ];
    shell = pkgs.bash;
  };
  nix.settings.allowed-users = [ "${username}" ];

}
