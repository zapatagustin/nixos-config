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

  # Pin GitHub's host key system-wide so nothing — including root during a
  # flake-input fetch — ever hits the interactive trust-on-first-use prompt.
  # Fingerprint SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU, matches
  # https://docs.github.com/en/authentication/keychecking (verified 2026-09-01).
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  services.openssh = {
    enable = true;
    # openFirewall would expose port 22 on every interface; these laptops join
    # untrusted networks (see the cups-browsed note above), so sshd is reachable
    # only over the tailnet. If tailscale is down, SSH requires physical access.
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  fonts = {
    enableDefaultPackages = true;
    # VGA is the new monospace face; symbols-only gives missing glyphs for apps
    # that do not bring their own Nerd Font (e.g. neovim plugin icons). Terminess
    # stays because the quickshell bar pins "Terminess Nerd Font Mono" by name,
    # unconditionally, throughout its QML files.
    packages = with pkgs; [
      udev-gothic
      (pkgs.callPackage ./modules/theme/pxplus-ibm-vga8.nix { })
      nerd-fonts.symbols-only
      nerd-fonts.terminess-ttf
      ibm-plex
    ]; # stylix.fonts refs these but autoEnable=false doesn't install them
    fontconfig.enable = true;
    # defaultFonts managed by stylix (modules/theme/stylix.nix)
    # <accept> APPENDS Symbols Nerd Font after VGA8, making it a real fallback
    # for glyphs VGA8 lacks. <prefer> would PREPEND it, promoting the symbols
    # font ahead of the primary face — inverted from what is wanted here.
    # Verify: fc-match -s "PxPlus IBM VGA8" must list VGA8 first.
    fontconfig.localConf = ''
      <alias>
        <family>PxPlus IBM VGA8</family>
        <accept>
          <family>Symbols Nerd Font</family>
        </accept>
      </alias>
    '';
  };
}
