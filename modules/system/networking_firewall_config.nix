{ pkgs, lib, ... }:
let
  sharedPorts = [
    22
    3389
    3391
    8180
    3000
    4322
  ];

  sharedPortRanges = [
    {
      from = 1714;
      to = 1764;
    }
    {
      from = 19000;
      to = 19999;
    }
    {
      from = 5900;
      to = 5999;
    }
    {
      from = 9000;
      to = 9999;
    }
    {
      from = 47988;
      to = 48000;
    }
    {
      from = 4321;
      to = 4339;
    }

    {
      from = 7890;
      to = 7899;
    }
  ];
in
{
  networking = {
    hostName = lib.mkDefault "";
    networkmanager.enable = true;
    nameservers = [
      "223.5.5.5"
      "8.8.4.4"
      "1.1.1.1"
    ];
    firewall = {
      enable = true;
      allowedTCPPorts = sharedPorts;
      allowedUDPPorts = sharedPorts;
      allowedTCPPortRanges = sharedPortRanges;
      allowedUDPPortRanges = sharedPortRanges;
    };
  };

  environment.systemPackages = with pkgs; [
    socat
  ];
}
