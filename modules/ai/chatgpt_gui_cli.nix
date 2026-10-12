{
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        # chatgpt # 还没合并
        # chatgpt-cli
      ];
    };
  };
}
