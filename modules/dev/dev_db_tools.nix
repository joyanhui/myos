{ pkgs, ... }: {
  environment.systemPackages = [
    pkgs.duckdb
    pkgs.sqlite
  ];
}
