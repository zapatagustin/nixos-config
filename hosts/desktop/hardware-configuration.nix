# Hand-written in nixos-generate-config's layout for the TARGET NixOS install of
# this machine (currently CachyOS; facts from findmnt/lsblk/lsmod, 2026-10-21).
#
# The nvme btrfs partition gets reformatted at install with three subvolumes
# (@ -> /, @home -> /home, @nix -> /nix). Its UUID below is the CURRENT one, a
# placeholder: reformatting changes it. Regenerate at install time with
# `nixos-generate-config --show-hardware-config`, take the new UUIDs from it,
# and keep the mount options and the /mnt/datos entry from this file.
#
# /mnt/datos (sda1) is the data disk: Steam library, Immich library, Jellyfin
# config/media, music. It is only mounted here, NEVER formatted by the installer;
# its UUID stays valid.
{ config, lib, modulesPath, ... }:

let
  # nvme0n1p2: one btrfs filesystem, one subvolume per mount point.
  subvolume = subvol: {
    device = "/dev/disk/by-uuid/14a81ffa-8648-4c6c-b2ff-845bec4d3915";
    fsType = "btrfs";
    options = [ "subvol=${subvol}" "compress=zstd:1" "noatime" ];
  };
in
{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "uas" "sd_mod" ];
  # amdgpu in initrd: KMS (native-resolution console) from the first boot stage.
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = subvolume "@";
  fileSystems."/home" = subvolume "@home";
  fileSystems."/nix" = subvolume "@nix";

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/438A-DFF8";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  # sda1, 931G btrfs data disk (top-level subvolume). nofail: a dead or unplugged
  # data disk must not drop the machine into emergency mode.
  fileSystems."/mnt/datos" =
    {
      device = "/dev/disk/by-uuid/3710c79f-7289-4911-9cfc-6ea4b60372b0";
      fsType = "btrfs";
      options = [ "compress=zstd:1" "noatime" "nofail" ];
    };

  # No disk swap: zram only (modules/hardware/hardware.nix zramSwap).
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
