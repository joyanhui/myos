{ lib, pkgs, ... }: {
  networking.networkmanager.wifi.backend = "wpa_supplicant";
}
