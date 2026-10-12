{ username
, ...
}:
{
   /*
  users.users.${username} = {
    hashedPassword = "********";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 ****"
      "ssh-rsa ****"
    ];
  };
  users.users.root = {
    hashedPassword = "***********";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 ***********"
      "ssh-rsa **********m"
    ];
  };
*/
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
