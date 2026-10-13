{
  username,
  ...
}:
{
  users.users.${username} = {
    password = "nixos";
    /*
      hashedPassword = "********";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 ****"
        "ssh-rsa ****"
      ];
    */
  };
  users.users.root = {
    password = "nixos";
    /*
        hashedPassword = "********";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 ****"
          "ssh-rsa ****"
        ];
    */
  };
  home-manager = {
    users.${username} = {
      /*
         home.file = {
           ".ssh/id_ed25519".text = ''
             -----BEGIN OPENSSH PRIVATE KEY-----
             *************
             -----END OPENSSH PRIVATE KEY-----
           '';
           ".ssh/id_rsa".text = ''
             -----BEGIN OPENSSH PRIVATE KEY-----
             *************
             -----END OPENSSH PRIVATE KEY-----
           '';
         };
      */
    };
  };
}
