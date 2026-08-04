{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    cargo
    gcc
    jq
    killall
    # nixd comes from the editors that use it: neovim declares it in extraPackages
    # and emacs in home.packages, so it is on PATH without a third declaration here.
    python3
  ];
}
