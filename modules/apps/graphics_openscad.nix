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
          openscad-unstable
          openscad-lsp
          meshlab
          prusa-slicer
          manifold
          (python3.withPackages (ps: [
            ps.trimesh
            ps.numpy-stl
            ps.meshio
            ps.manifold3d
          ]))
        ];
      };
  };
}
