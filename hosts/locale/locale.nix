{ pkgs, ... }: {
  time.timeZone = "America/Argentina/Buenos_Aires";

  i18n.defaultLocale = "en_US.UTF-8";

  # Only generate locales we use (saves ~70MB)
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "es_AR.UTF-8/UTF-8"
  ];

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_AR.UTF-8";
    LC_IDENTIFICATION = "es_AR.UTF-8";
    LC_MEASUREMENT = "es_AR.UTF-8";
    LC_MONETARY = "es_AR.UTF-8";
    LC_NAME = "es_AR.UTF-8";
    LC_NUMERIC = "es_AR.UTF-8";
    LC_PAPER = "es_AR.UTF-8";
    LC_TELEPHONE = "es_AR.UTF-8";
    LC_TIME = "es_AR.UTF-8";
  };

  console = {
    earlySetup = true;
    keyMap = "dvorak";
    font = "ter-v32b";
    packages = [ pkgs.terminus_font ];
  };

  # Wayland compositors read xkb settings — keep for future DE/WM
  services.xserver.xkb = {
    layout = "us";
    variant = "dvorak";
  };
}
