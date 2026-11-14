{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    copyq
  ];
}
