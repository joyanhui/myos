{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.valkey
  ];

  systemd.services.valkey_devTest = {
    description = "valkey server (devTest)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.valkey}/bin/valkey-server /tmp/valkey_devTest.conf";
      ExecStop = "${pkgs.valkey}/bin/valkey-cli -h 127.0.0.1 -p 6379 shutdown";
      Restart = "on-failure";
      Type = "simple";
    };

    preStart = ''
      mkdir -p /tmp
      cat > /tmp/valkey_devTest.conf <<EOF
      port 6379
      daemonize no
      requirepass admin888
      bind 0.0.0.0
      dir /tmp
      EOF
    '';
  };
}
