{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    cargo
    gcc
    jq
    killall
    nixd
    python3
  ];
}
