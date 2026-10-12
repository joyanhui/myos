{
  commonAliases = {
    killall = "killall -v";
    umount = "umount -v";
    lsblk = "lsblk -a --output \"NAME,LABEL,FSTYPE,SIZE,FSUSE%,RO,TYPE,MOUNTPOINTS\"";
    grep = "grep --color=auto";
    ls = "ls --color=auto";
    chmod = "chmod -v";
    chown = "chown -v";
    chattr = "chattr -v";
    ln = "ln -v";
    cp = "cp -v";
    mv = "mv -v";
    #    rm = "rm -v";
    mkdir = "mkdir -pv";
    rmdir = "rmdir -v";

    myclean_nixos = "cat ${../../script/myclean.sh}";
    myclean_home_manager = "find /home  -name \"*home-manager-backup*\" -delete ";

    proxySet = "export http_proxy=\"http://127.0.0.1:7890\"; export https_proxy=\"http://127.0.0.1:7890\";export NO_PROXY=\"127.0.0.1,localhost,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.local,192.168.1.0/24\"";

    proxySet2 = "export http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890 all_proxy=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890 ALL_PROXY=http://127.0.0.1:7890 no_proxy=127.0.0.1,localhost NO_PROXY=127.0.0.1,localhost";

    proxyUnSet = "command -v unset > /dev/null && unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy NO_PROXY || set -e http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy NO_PROXY";

    imRestart = "systemctl --user restart fcitx5";

    scpToX240 = "scp -r /home/nixos/myws/os-config/* yh@x240:/home/nixos/myws/os-config/";
    # find /path/to/directory -type f -name \"*home-manager-backup*\" -exec rm -f {} \;
    helix = "hx";
    # nano = "command -v micro &>/dev/null && micro || nano";
    neofetch = "echo fastfetch && fastfetch";
    # aitools = "bun install -g @google/gemini-cli && bun install -g opencode-ai";

    cdos = "cd /home/nixos/myws/os-config/";
    cdlot = "cd /home/nixos/myws/lot-manager-aio/";
    cdbmh = "cd /home/nixos/myws/baomihua.eu.org/";
  };
}
