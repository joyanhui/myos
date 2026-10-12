{
  pkgs,
  username,
  ...
}:
{

   environment.systemPackages = with pkgs; [
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
    rocmPackages.rpp
    rocmPackages.rocm-core
    rocmPackages.rocm-runtime
    rocmPackages.hipblas
    rocmPackages.llvm.clang

  ];
  hardware.graphics.extraPackages = with pkgs; [
   rocmPackages.clr.icd
  ];
  home-manager = {
    users.${username} =
      { config, ... }:
      {
        home.packages = with pkgs; [
          llama-cpp-rocm

        ];
      };
  };

  services.nextjs-ollama-llm-ui = {
    enable = true;
    port = 3001;
    hostname = "127.0.0.1";
    ollamaUrl = "http://127.0.0.1:11434";
  };

  services.ollama = {
    enable = true;
    package = pkgs.master.ollama-rocm;
    home = "/var/lib/ollama";
    models = "/var/lib/ollama/models";
    environmentVariables = {
      HCC_AMDGPU_TARGET = "gfx1035";
    };
  };

  services.llama-cpp = {
    enable = true;
    package = pkgs.master.llama-cpp-rocm;
    host = "127.0.0.1";
    port = 8080;
  };

}
