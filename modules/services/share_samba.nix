{
  pkgs,
  ...
}:
# sudo smbpasswd -a my_user
{
  services.samba = {
    enable = true;
    openFirewall = true;
    package = pkgs.sambaFull;

    settings = {
      global = {
        "invalid users" = [
          "root"
        ];
        "passwd program" = "/run/wrappers/bin/passwd %u";
        security = "user";
      };
      public = {
        browseable = "yes";
        comment = "Public samba share.";
        "guest ok" = "yes";
        path = "/srv/public";
        "read only" = "yes";
      };
      mnt_auto = {
        path = "/mnt";
        "create mask" = 644;
        "directory mask" = 755;
        available = "yes";
        writeable = "yes";
        security = "share";
        browseable = "yes";
        "guest ok " = "no";
      };
      home = {
        path = "/home";
        "create mask" = 644;
        "directory mask" = 755;
        available = "yes";
        writeable = "yes";
        security = "share";
        browseable = "yes";
        "guest ok " = "no";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}
