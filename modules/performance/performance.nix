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

  # Aggressive userspace OOM killer (prevents full freeze under memory pressure)
  services.earlyoom.enable = true;

  # Spread hardware interrupts across CPUs
  services.irqbalance.enable = true;

  # BBR TCP congestion control (better throughput/latency than cubic)
  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
  };
}
