rec {
  username = "nixos";
  repoDir = "/home/nixos/myws/myos";
  stateVersion = "26.05";

  editor = "hx";

  secretsUnlocked =
    let
      checkFile = ./security/_protected/isDecryptedCheckFileLen.txt;
      checkFileHash = builtins.hashFile "sha256" checkFile;
    in
    builtins.pathExists checkFile
    && builtins.elem checkFileHash [
      (builtins.hashString "sha256" "1")
      (builtins.hashString "sha256" "1\n")
    ];
  secretsDir = if secretsUnlocked then "${repoDir}/security/_protected" else "${repoDir}/security/placeholder_files";
  secretRelDir = if secretsUnlocked then ./security/_protected else ./security/placeholder_files;

  permittedInsecurePackages = [
    "openssl-3.0.22"
    "another-redis-desktop-manager-1.7.1"
    "electron-31.7.7"
    "electron-38.8.4"
    "electron-39.8.10"
    "electron-41.9.1"
    "electron-41.10.7"
    "ventoy-1.1.07"
  ];

  # systemProxy = "http://127.0.0.1:7890";
  ghProxy = "https://gh.leiyanhui.com";
  helloProxy = "https://hello.leiyanhui.com";

  theme = {
    name = "adw-gtk3-dark";
    package = "adw-gtk3";
    iconTheme = "Papirus-Dark";
    iconThemePkg = "papirus-icon-theme";
    cursorTheme = "Bibata-Modern-Ice";
    cursorThemePkg = "bibata-cursors";
  };

  font = {
    size = {
      xsmall = 9;
      small = 10;
      medium = 12;
      large = 14;
      xlarge = 16;
      xxlarge = 18;
      gui = 12;
      term = 14;
    };
    mono = "Sarasa Mono SC";
    sans = "Sarasa UI SC";
    serif = "Sarasa Gothic";
    emoji = "Noto Color Emoji";
  };
}
