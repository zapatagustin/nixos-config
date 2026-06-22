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
    wl-clipboard

    # Nix tooling
    comma
    nh
    nix-output-monitor
    nixpkgs-review
    nvd

    # System info
    glxinfo
    imagemagick
    pciutils
  ];
}
