{ lib, ... }: {
  options.services.displayManager.generic = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = "Generic display manager settings (stub for stylix compat)";
  };
}
