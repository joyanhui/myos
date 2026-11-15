{
  pkgs,
  username,
  ...
}:
let
  obsidianPreflight = pkgs.writeShellScript "obsidian-preflight" ''
    cfg="$XDG_CONFIG_HOME"
    [ -n "$cfg" ] || cfg="$HOME/.config"
    cfg="$cfg/obsidian"

    if [ -d "$cfg" ]; then
      if compgen -G "$cfg/obsidian-*.asar" > /dev/null; then
        rm -f "$cfg"/obsidian-*.asar "$cfg"/obsidian.asar.tmp
        rm -rf "$cfg/Code Cache"
      fi

      if [ -f "$cfg/obsidian.json" ] && ! ${pkgs.jq}/bin/jq -e '.updateDisabled == true' "$cfg/obsidian.json" > /dev/null 2>&1; then
        ${pkgs.jq}/bin/jq '.updateDisabled = true' "$cfg/obsidian.json" > "$cfg/obsidian.json.tmp" \
          && mv "$cfg/obsidian.json.tmp" "$cfg/obsidian.json"
      fi
    fi
  '';

  obsidian = pkgs.symlinkJoin {
    name = "obsidian-fixed";
    paths = [ pkgs.obsidian ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/obsidian --run '${obsidianPreflight}'
    '';
  };
in
{
  home-manager = {
    users.${username} =
      { config, ... }:
      {
        home.packages = with pkgs; [
          obsidian
          zenity
        ];
      };
  };
}
