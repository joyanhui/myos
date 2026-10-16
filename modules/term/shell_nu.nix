{
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        nushell
      ];
      home.file = {
        ".config/nushell/config.nu".text = ''
          $env.config.shell_integration.osc133 = false
          $env.config.show_banner = false

          alias colourify = ^grc -es --colour=auto
          alias blkid = colourify blkid
          alias configure = colourify configure
          alias df = colourify df
          alias diff = colourify diff
          alias docker = colourify docker
          alias "docker-compose" = colourify "docker-compose"
          alias "docker-machine" = colourify "docker-machine"
          alias free = colourify free
          alias fdisk = colourify fdisk
          alias findmnt = colourify findmnt
          alias make = colourify make
          alias gcc = colourify gcc
          alias "g++" = colourify "g++"
          alias id = colourify id
          alias ip = colourify ip
          alias iptables = colourify iptables
          alias as = colourify as
          alias gas = colourify gas
          alias journalctl = colourify journalctl
          alias kubectl = colourify kubectl
          alias ld = colourify ld
          alias lsof = colourify lsof
          alias lsblk = colourify lsblk
          alias lspci = colourify lspci
          alias netstat = colourify netstat
          alias ping = colourify ping
          alias ss = colourify ss
          alias traceroute = colourify traceroute
          alias traceroute6 = colourify traceroute6
          alias head = colourify head
          alias tail = colourify tail
          alias dig = colourify dig
          alias mount = colourify mount
          alias mtr = colourify mtr
          alias semanage = colourify semanage
          alias getsebool = colourify getsebool
          alias ifconfig = colourify ifconfig
          alias sockstat = colourify sockstat
        '';
      };
    };
  };
}
