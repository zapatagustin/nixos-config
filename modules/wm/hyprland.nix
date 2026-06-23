{ pkgs, ... }:
{
  # Compositor + uwsm session. Portals (xdg-desktop-portal-hyprland) come with it.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Login: tuigreet -> uwsm-managed hyprland session. No DE.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
      user = "greeter";
    };
  };

  security.polkit.enable = true;

  # hyprlock needs a PAM entry to authenticate — without it you can't unlock.
  security.pam.services.hyprlock = { };
}
