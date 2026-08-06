{ lib, ... }:
{
  options.myDesktop.multiMonitor.enable = lib.mkEnableOption
    "dual-Samsung dock multimonitor daemon (docking host only)";

  # Fractional scale for the internal (eDP-1) panel. Per host: the surface's
  # 2256x1504 13.5" panel needs ~1.3333; keep 1.0 elsewhere. Must yield integer
  # logical pixels for the panel's resolution or Hyprland snaps it.
  options.myDesktop.internalScale = lib.mkOption {
    type = lib.types.float;
    default = 1.0;
    description = "Scale factor for the eDP-1 internal display.";
  };

  # Gamma mapping the brightness KEYS onto the internal panel's raw backlight, and
  # the one number that makes three screens track one control.
  #
  # A monitor's DDC 0-100 ships calibrated by its maker to look perceptually linear,
  # so the DDC value to send externals is simply the control's percent. The panel is
  # the half that needs a curve, and how much is a property of the hardware. There is
  # no way to equalise real LUMINANCE without a photometer -- different maximum nits,
  # different floors. What this buys is one control all three track.
  #
  # 1.1 is MEASURED on the surface, not derived. Matched by eye against the externals
  # at a control of 31%: the panel needed 28% of maximum raw, which solves to
  # ln(0.28)/ln(0.31) = 1.087.
  #
  # That number matters beyond this machine, because it falsifies the obvious theory.
  # The reasoning for the 2.2 this replaced was "a laptop backlight is roughly linear
  # in PWM duty, so it needs sRGB's gamma to look perceptually linear". At 1.087 this
  # panel is already near-perceptual on its own -- intel_backlight, or the panel,
  # applies its own correction -- so stacking 2.2 on top over-darkened it exactly the
  # way the 4 before it did, just less. Do not re-derive this exponent from theory on
  # another machine; measure it the same way.
  #
  # Consumed twice, and the two are pinned together by flake.nix's
  # brightness-exponent check: wm/hyprland/default.nix substitutes it into
  # scripts/brightness.sh, and quickshell/bar/Brightness.qml carries the same
  # literal because the bar directory is deployed as one symlink and cannot take a
  # generated file.
  options.myDesktop.brightnessExponent = lib.mkOption {
    type = lib.types.float;
    default = 1.1;
    description = "Perceptual gamma for the internal backlight and the DDC value sent to externals.";
  };
}
