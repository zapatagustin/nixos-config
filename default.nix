{ pkgs, ... }:
{
  imports = [
    ./modules/modules.nix
    ./hosts/host.nix
  ];

  services.printing = {
    enable = true;
    # cups-browsed off (its default is on). With avahi + nssmdns4 in hosts/host.nix
    # it browses mDNS and creates a local queue for every IPP printer that
    # advertises itself, so joining a coworking network silently produced an
    # `implicitclass://EPSON_WF_6590_Series/` queue nobody asked for -- alongside a
    # Xerox someone was sharing off their laptop. Nothing inbound was exposed (cupsd
    # binds 127.0.0.1:631 only, no UDP 631 listener, 631 not in the firewall), so
    # the risk is not RCE: it is printing a document on a stranger's machine because
    # browsed picked the default queue. Add printers explicitly when one is needed.
    browsed.enable = false;
  };
  # disabled: enabled for a year with no Flathub remote and zero apps installed
  # (`flatpak remotes` and `flatpak list --app` both came back empty). Declaring the
  # remote would need the nix-flatpak input -- a whole flake input to declare a
  # repository nothing is installed from. Unlike gaming/pihole, which are modules
  # left switched OFF and cost nothing, this one was RUNNING: a service plus the
  # portal closure, for nothing. Re-enable here and add the remote when an app
  # actually needs it:
  #   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  # services.flatpak.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [ udev-gothic nerd-fonts.terminess-ttf ibm-plex ]; # stylix.fonts refs these but autoEnable=false doesn't install them
    fontconfig.enable = true;
    # defaultFonts managed by stylix (modules/theme/stylix.nix)
  };
}
