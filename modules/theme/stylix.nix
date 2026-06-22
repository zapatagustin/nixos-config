{ pkgs, config, ... }: {
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

    # No DE/compositor: wallpaper is just a solid bg pixel.
    image = config.lib.stylix.pixel "base00";

    fonts = {
      monospace = { package = pkgs.terminus_font_ttf; name = "Terminus (TTF)"; };
      sansSerif = { package = pkgs.udev-gothic; name = "UDEV Gothic"; };
      serif = { package = pkgs.udev-gothic; name = "UDEV Gothic"; };
    };

    # Stylix's starship target imposes its own palette and breaks the custom
    # prompt (uses named colors). Manual palette is already gruvbox — keep it.
    targets.starship.enable = false;
  };
}
