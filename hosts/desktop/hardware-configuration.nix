# Hand-written in nixos-generate-config's layout for the NixOS install of this
# machine (installed 2026-10; facts from /etc/fstab + /proc/self/mounts of the
# installer-generated generation, 2026-10-23).
#
# The installer did NOT use the @-prefixed layout this file once assumed: / sits
# on the btrfs top-level subvolume, with `home` and `nix` nested inside it. If
# the disk is ever reformatted, regenerate with
# `nixos-generate-config --show-hardware-config`, take the new UUIDs from it,
# and keep the mount options and the /mnt/datos entry from this file.
#
# /mnt/datos (sda1) is the data disk: Steam library, Immich library, Jellyfin
# config/media, music. It is only mounted here, NEVER formatted by the installer;
# its UUID stays valid.
{ config, lib, modulesPath, ... }:

let
  # nvme0n1p2: one btrfs filesystem; / is the top-level subvolume (no subvol=).
  nvme = subvolOptions: {
    device = "/dev/disk/by-uuid/667148d6-afe7-4c96-91b4-6ee94926d2c7";
    fsType = "btrfs";
    options = subvolOptions ++ [ "compress=zstd:1" "noatime" ];
  };
in
{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "uas" "sd_mod" ];
  # amdgpu in initrd: KMS (native-resolution console) from the first boot stage.
  # Ruled out as the GPU-init culprit in the 2026-10 bisect (hosts/desktop
  # default.nix, "Bisect verdict"); the real fix was pinning stock 7.3.
  # NEVER mkForce this list: NixOS injects `btrfs` here for the root
  # filesystem, and force-emptying it left stage 1 unable to mount root.
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = nvme [ ];
  fileSystems."/home" = nvme [ "subvol=home" ];
  fileSystems."/nix" = nvme [ "subvol=nix" ];

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/75D8-737E";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  # sda1, 931G btrfs data disk (top-level subvolume). nofail: a dead or unplugged
  # data disk must not drop the machine into emergency mode.
  fileSystems."/mnt/datos" =
    {
      device = "/dev/disk/by-uuid/3710c79f-7289-4911-9cfc-6ea4b60372b0";
      fsType = "btrfs";
      options = [ "compress=zstd:1" "noatime" "nofail" "x-systemd.device-timeout=10s" ];
    };

  # Disk swap behind zram (modules/hardware/hardware.nix zramSwap, priority 5):
  # the installer's nvme0n1p3 keeps the default priority -1, so it only fills
  # once zram is exhausted. systemd-gpt-auto was already activating it anyway;
  # declaring it makes the config match the running system. No boot.resumeDevice:
  # 8.8G cannot reliably hold a 16G hibernation image.
  swapDevices = [{ device = "/dev/disk/by-uuid/85e661c4-4fd5-49e4-83e1-3052549bb640"; }];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
