{
  username,
  ...
}:
{
  home-manager = {
    users.${username} = {
      home.sessionVariables = {
        KOPIA_PASSWORD = "******";
        KOPIA_CHECK_FOR_UPDATES = "false";
        TOKEN_CF = "******";
        TOKEN_GH = "ghp_******";
        TOKEN_GH2 = "ghp_******";
        TOKEN_ZEROSSL = "****";
        TOKEN_ZEROSS_EAB_KID = "******";
        TOKEN_ZEROSS_EAB_KEY = "**********";

        MYGH = "https://aaaaa:**********@gh-proxy.com/";
        MYGH_fileuni = "https://vvvvvv:**********@gh-proxy.com/";
        GMAILPASSWD = "**********";
        TOKEN_ALI_AK = "**********";
        TOKEN_ALI_SK = "**********";
        TOKEN_TX_AK = "**********";
        TOKEN_TX_SK = "**********";
      };
    };
  };
}
