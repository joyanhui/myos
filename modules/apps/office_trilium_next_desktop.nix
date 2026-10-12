{ pkgs
, username
, ...
}:
{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        unstable.trilium-desktop
      ];
    };
  };
}
