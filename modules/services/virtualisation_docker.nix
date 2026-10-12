{ pkgs
, global_settings
, ...
}:
{
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      registry-mirrors = [
        "https://docker.1ms.run"
        "https://docker.m.daocloud.io"
        "https://docker.xuanyuan.me"
        "https://dockercf.jsdelivr.fyi"
      ];
      data-root = "${builtins.dirOf global_settings.repoDir}/docker/data-root";
      userland-proxy = false;
      experimental = true;
      ipv6 = true;
      fixed-cidr-v6 = "fd00::/80";
      metrics-addr = "0.0.0.0:9323";
      log-driver = "json-file";
      log-opts.max-size = "10m";
      log-opts.max-file = "10";
    };
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    docker-buildx
    lazydocker
    dive
    x11docker
    nix-prefetch-docker
  ];

  /*
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        metacubexd = {
          image = "docker.leiyanhui.com/metacubex/metacubexd:latest";
          # image = "ghcr.io/metacubex/metacubexd:latest";
          # image = "ghcr.geekery.cn/metacubex/metacubexd:latest";
          ports = [ "80:80" ];
          autoStart = true;
          environment = {
            TZ = "Asia/Shanghai";
          };
        };

        # docker run --name one-api -d --restart always -p 3000:3000 -e TZ=Asia/Shanghai -v /home/nixos/docker/mydata/one-api:/data docker.leiyanhui.com/justsong/one-api
        # one-api = {
        #   image = "docker.leiyanhui.com/justsong/one-api:latest";
        #   ports = [ "3000:3000" ];
        #   autoStart = true;
        #   environment = {
        #     TZ = "Asia/Shanghai";
        #   };
        #   volumes = [
        #     "/home/nixos/docker/mydata/one-api:/data"
        #   ];
        # };

        # docker run -itd --name onlyoffice -p 8100:80 --restart=always -e WOPI_ENABLED=true -e ONLYOFFICE_WOPI_ENABLED=true docker.1ms.run/onlyoffice/documentserver
        # docker run -itd --network host -e "aliasgroup1=http://127.0.0.1:19000" -e "domain=localhost|127\\.0\\.0\\.1" --name code --restart always docker.1ms.run/collabora/code
      };
    };
  */
}
