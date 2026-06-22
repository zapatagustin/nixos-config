{ pkgs, ... }: {
  # CachyOS sched_ext scheduler (laptop-friendly, latency-aware)
  chaotic.scx = {
    enable = true;
    scheduler = "scx_bpfland";
  };

  # Auto re-nice processes based on rules
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
  };

  # Aggressive userspace OOM killer
  services.earlyoom.enable = true;

  # Spread hardware interrupts across CPUs
  services.irqbalance.enable = true;

  boot.kernel.sysctl = {
    # Network
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_fastopen" = 3;
    "net.core.rmem_max" = 67108864;
    "net.core.wmem_max" = 67108864;

    # Memory (laptop + zram)
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_writeback_centisecs" = 6000;

    # Kernel hardening
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
  };
}
