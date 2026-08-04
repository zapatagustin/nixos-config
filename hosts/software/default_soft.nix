{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Fetch / fun
    asciinema
    cmatrix
    cowsay
    fastfetch
    figlet
    fortune
    lolcat
    nyancat
    sl
    toilet

    # File / disk utils
    btop
    dust
    duf
    fd
    file
    gparted
    ncdu
    procs
    ripgrep
    tree
    unrar
    unzip
    xcp
    zoxide

    # Network
    netcat-openbsd
    openvpn
    wget

    # Wayland
    # wl-clipboard lives in the hyprland HM module, next to the other session tools
    # the binds and scripts need on PATH. It was declared in both layers.

    # Nix tooling
    # comma comes from programs.nix-index-database.comma (shells/shells.nix), which
    # wraps it with the prebuilt database. The plain pkgs.comma that used to be here
    # had no database to read.
    nh
    nix-output-monitor
    nixpkgs-review
    nvd

    # System info
    mesa-demos
    imagemagick
    pciutils
  ];
}
