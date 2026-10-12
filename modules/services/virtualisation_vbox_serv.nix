{ pkgs
, username
, ...
}:
{
  systemd.services.vbox_Serv = {
    description = "vbox-serv";
    enable = true;
    wantedBy = [ "multi-user.target" ];
    after = [ "vboxnet0.service" ];
    serviceConfig = {
      User = "${username}";
      Group = "vboxusers";
      ExecStart = [
        ''
          ${pkgs.virtualbox}/libexec/virtualbox/VBoxHeadless -s Serv
        ''
      ];
    };
  };
}
