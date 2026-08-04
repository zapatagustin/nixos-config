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
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
      user = "greeter";
    };
  };

  security.polkit.enable = true;

  # Thunar file manager + volman (auto-mount/manage removable media). volman
  # needs udisks2 to mount and polkit (above) to authorize; gvfs adds trash +
  # network/MTP mounts; tumbler renders thumbnails. Enable auto-mount in
  # Thunar > Edit > Preferences > Removable Media after first launch.
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [ thunar-volman thunar-archive-plugin ];
  };
  # thunar-archive-plugin is only the context-menu hook; it needs a real archiver
  # backend to actually compress/extract.
  environment.systemPackages = [ pkgs.xarchiver ];

  # udisks2 and gvfs are both enabled in modules/hardware/hardware.nix (removed
  # redundant enables here) — Thunar/volman consume them, they don't own them.
  services.tumbler.enable = true;

  # hyprlock needs a PAM entry to authenticate — without it you can't unlock.
  security.pam.services.hyprlock = { };
}
