{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    cargo
    gcc
    jq
    killall
    python3
    nil
  ];
}
