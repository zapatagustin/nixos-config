# SpacemiT K1 board bits (Orange Pi RV2; Milk-V Jupiter differs only in the
# dtb name). Mainline 7.2 carries both dts files with Ethernet, eMMC, SD, PCIe
# and USB3 enabled. U-Boot lives in the board's SPI flash and is not managed
# here: NixOS owns only /boot (extlinux) and the root filesystem.
{ pkgs, lib, ... }:
{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Rust for Linux is on wherever rustc exists, and riscv64 qualifies. It would
  # add rustc, bindgen and clang to the build for nothing this board uses.
  boot.kernelPatches = [{
    name = "no-rust";
    patch = null;
    structuredExtraConfig.RUST = lib.mkForce lib.kernel.no;
  }];
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };
  hardware.deviceTree = {
    enable = true;
    name = "spacemit/k1-orangepi-rv2.dtb";
  };
  boot.kernelParams = [ "console=ttyS0,115200" ];

  # The riscv defconfig builds the K1 clock, pinctrl, GPIO and SD host in, but
  # PCIe, its PHY, I2C and the P1 PMIC regulators are `default ARCH_SPACEMIT`
  # tristates, which nixpkgs' autoModules turn into modules. Both root media
  # need them in the initrd: NVMe hangs off pcie1, SD/eMMC power comes from
  # the PMIC on i2c8. Names are the 7.2 Makefile objects; allowMissingModules
  # covers whichever the final .config builds in instead.
  boot.initrd.availableKernelModules = [
    "nvme"
    "pcie-spacemit-k1"
    "phy-k1-pcie"
    "spacemit-ccu-k1"
    "spacemit-ccu"
    "reset-spacemit-k1"
    "reset-spacemit-common"
    "i2c-k1"
    "simple-mfd-i2c"
    "spacemit-p1"
    "sdhci-of-k1"
    "mmc_block"
  ];
  boot.initrd.allowMissingModules = true;

  # /boot stays ext4 on the eMMC or SD card because U-Boot has to read it;
  # root is btrfs on the NVMe.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "compress=zstd" "noatime" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXOS_BOOT";
    fsType = "ext4";
  };
}
