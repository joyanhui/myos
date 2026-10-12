{ username
, pkgs
, ...
}:
{
  services.nginx = {
    user = "${username}";
    enable = true;
    config = ''
      events {
        worker_connections  4096;  ## Default: 1024
      }
      http {
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        include ${pkgs.nginx}/conf/mime.types;
        default_type application/octet-stream;
        gzip on;
        gzip_disable "msie6";

        server {
          server_name          localhost;
          listen               8001;
          listen               [::]:8001;
          client_max_body_size 100M;
          location / {
          root ${pkgs.nginx}/html;
          }
        }
        server {
          server_name          localhost;
          listen               8002;
          listen               [::]:8002;
          client_max_body_size 100M;
          location / {
          root /home/${username}/myworkspace/syx_lot_manager_aio;
          }
        }
      }
    '';

  };

}
