{ ... }: {
  imports = [
    ./foot/foot.nix # default terminal (TERMINAL + SUPER+RETURN)
    ./kitty/kitty.nix # kept installed as fallback
  ];
}
