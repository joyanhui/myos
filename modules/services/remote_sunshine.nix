{ ...
}: {
  services.sunshine = {
    autoStart = true;
    enable = true;
    capSysAdmin = true;
  };
}
