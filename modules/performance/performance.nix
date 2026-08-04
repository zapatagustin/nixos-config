_: {
  # ecomono: chaotic.scx removed from nyx. scx kernel module ships with
  # CachyOS kernel; userspace scheduler needs the scx package (available
  # from chaotic overlay). Add back when building on the real NixOS machine.
  # See https://github.com/scx-wiki/scx for upstream status.
  # disabled: CachyOS kernel's BORE scheduler already prioritizes interactive
  # processes; ananicy adds a daemon without measurable benefit here.
  # services.ananicy = {
  #   enable = true;
  #   package = pkgs.ananicy-cpp;
  # };

  services.earlyoom.enable = true;
  services.irqbalance.enable = true;

  boot.kernel.sysctl = {
    # Network perf
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_fastopen" = 3;
    "net.core.rmem_max" = 67108864;
    "net.core.wmem_max" = 67108864;

    # Memory (laptop + zram). zram swap is fast/compressed, so prefer it
    # aggressively instead of evicting page cache (low swappiness suits disk swap).
    "vm.swappiness" = 180;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_writeback_centisecs" = 6000;

    # Kernel hardening
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;

    # Network hardening
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
  };
}
