# herdr (terminal multiplexer) for one developer on us(dvorak).
#
# Physical H J K L type the characters d h t n, and herdr matches the typed
# character. Neovim maps window navigation on <M-h/j/k/l> and its langmap turns
# the typed Alt+d/h/t/n into those. A direct herdr chord is taken from every
# pane, so those four chords go through herdr-nav, which gives the key back to
# neovim when neovim is the focused pane's foreground process.
{ pkgs, ... }:
let
  # The scripts reach herdr through $HERDR_BIN_PATH (set by herdr for key
  # commands and panes) and fall back to PATH, so pkgs.herdr is a runtime input.
  script = name: runtimeInputs: bashOptions: pkgs.writeShellApplication {
    inherit name bashOptions;
    runtimeInputs = [ pkgs.herdr pkgs.jq ] ++ runtimeInputs;
    text = builtins.readFile (./scripts + "/${name}.sh");
  };
  strict = [ "errexit" "nounset" "pipefail" ];

  # herdr-nav must fail open, which `errexit` would fight.
  herdr-nav = script "herdr-nav" [ pkgs.coreutils ] [ "nounset" "pipefail" ];
  herdr-pane = script "herdr-pane" [ ] strict;
  herdr-waiting = script "herdr-waiting" [ pkgs.python3 ] strict;
  herdr-dev = script "herdr-dev" [ pkgs.git herdr-pane ] strict;

  tomlFormat = pkgs.formats.toml { };
  cmd = key: command: { inherit key command; type = "shell"; };
  nav = dir: key: cmd key "${herdr-nav}/bin/herdr-nav ${dir} ${key}";
in
{
  home.packages = [ pkgs.herdr herdr-nav herdr-pane herdr-waiting herdr-dev ];

  xdg.configFile."herdr/config.toml".source = tomlFormat.generate "herdr-config.toml" {
    theme.name = "terminal"; # follow the terminal's palette
    # The first-run onboarding screen takes every key until this is false, and
    # this file is a read-only store link, so herdr could not record on its own
    # that the screen was already seen.
    onboarding = false;

    keys = {
      prefix = "ctrl+g";
      focus_pane_left = [ "alt+left" "prefix+d" ];
      focus_pane_down = [ "alt+down" "prefix+h" ];
      focus_pane_up = [ "alt+up" "prefix+t" ];
      focus_pane_right = [ "alt+right" "prefix+n" ];
      zoom = [ "alt+;" "alt+z" ];
      switch_tab = "alt+1..9";

      command = [
        (nav "left" "alt+d")
        (nav "down" "alt+h")
        (nav "up" "alt+t")
        (nav "right" "alt+n")
        (cmd "alt+b" "${herdr-pane}/bin/herdr-pane")
        (cmd "alt+a" "${herdr-waiting}/bin/herdr-waiting")
      ];
    };
  };
}
