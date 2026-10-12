{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-wsl/787a4c128292010ad182eed66f879fa688592e4c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      self,
      ...
    }:
    let
      system = "x86_64-linux";
      global_settings = import ./global_setting_vars.nix;
      mkHost =
        tags: machineDir:
        let
          moduleTags = nixpkgs.lib.splitString "|" tags;
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            }
            home-manager.nixosModules.home-manager
            machineDir
            ./app_and_modules_list_NixOS.nix
          ];
          specialArgs = {
            inherit
              moduleTags
              self
              inputs
              nixpkgs-unstable
              global_settings
              ;
            username = global_settings.username;
            hmStandalone = false;
            smallFonts = false;
          };
        };
      mkHome =
        tags:
        let
          moduleTags = nixpkgs.lib.splitString "|" tags;
          hmPkgs = import inputs.nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              allowBroken = true;
              permittedInsecurePackages = global_settings.permittedInsecurePackages;
            };
            overlays = [
              (
                final: prev:
                let
                  importNixpkgs =
                    nixpkgsInput:
                    import nixpkgsInput {
                      system = prev.stdenv.hostPlatform.system;
                      config = {
                        allowUnfree = true;
                        allowBroken = true;
                        permittedInsecurePackages = global_settings.permittedInsecurePackages;
                      };
                    };
                in
                {
                  unstable = importNixpkgs inputs.nixpkgs-unstable;
                }
              )
            ];
          };
        in
        home-manager.lib.homeManagerConfiguration {
          pkgs = hmPkgs;
          modules = [ ./app_and_modules_list_OtherLinux.nix ];
          extraSpecialArgs = {
            inherit
              moduleTags
              self
              inputs
              nixpkgs-unstable
              global_settings
              ;
            username = global_settings.username;
            hmStandalone = true;
            smallFonts = false;
          };
        };
    in
    {
      nixosConfigurations = {
        raw_os_core_img_creat = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./machine/raw_os/raw-os-core-img-creat.nix ];
          specialArgs = { inherit global_settings; };
        };
        wsl = mkHost "common|wsl|dev|editor|services|ai|input-method" ./machine/wsl.nix;
        tb_amd = mkHost "common|tb_amd|physical|ai|inputKeyd|desktop|gui|dailyPC|dev|editor|input-method|services" ./machine/tb_amd;
        raw_os_work_amd = mkHost "common|raw-amd|desktop|gui|dev|editor|input-method|dailyPC|services|ai" ./machine/raw_os/raw-os-work.nix;
        raw_os_work_intel = mkHost "common|raw-intel|desktop|gui|dev|editor|input-method|dailyPC|services|ai" ./machine/raw_os/raw-os-work.nix;
      };

      homeConfigurations = {
        linux = mkHome "common|dev|editor|ai|input-method|gui|dailyPC";
      };
    };
}
