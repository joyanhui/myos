{ ...
}:
{
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ];
        settings = {
          main = {
            rightalt = "overload(alt_r_layer, f2)";
            rightcontrol = "f5";
          };
          "alt_r_layer" = {
            "esc" = "~";
          };
        };
      };
    };
  };
}
