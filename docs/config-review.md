# Config Review — NixOS Flake (surface + thinkpad)

Revisión general de la configuración en busca de problemas de performance,
conflictos, y seguridad. Fecha: 2026-07-17.

## Resumen

Arquitectura limpia, módulos bien separados, comentarios que explican el *por
qué*. La base es sólida. Hay puntos ajustables en seguridad, performance fina,
y un par de services redundantes.

---

## 🟥 Críticos

### 1. SSH: `PasswordAuthentication = true`

**Archivo:** `default.nix:18`

```
PasswordAuthentication = true;  # TEMP: switch to false after installing SSH key
```

Puerto 22 abierto (`services.openssh.openFirewall = true`) + login por
contraseña. Si la key SSH ya está instalada hay que apagarlo ya.

**Fix:**
```nix
PasswordAuthentication = false;
```

---

## 🟡 Advertencias

### 2. `services.throttled` — MEDIDO, deshabilitado ✅

**Archivo:** `modules/hardware/hardware.nix:59` (ahora comentado)

`throttled` arregla el bug BD PROCHOT de ThinkPads **Skylake/Kaby-era**. Esta
máquina es **i7-1185G7 (Tiger Lake, 11th gen)** — no afectada. Medido con
`turbostat` + `stress-ng --cpu 8`:

| Config | Bzy_MHz | PkgWatt | PkgTmp |
|--------|---------|---------|--------|
| PL1=44W (throttled ON)  | 3590 | 31.9W | 86°C |
| PL1=28W (throttled OFF) | 3531 | 32.1W | 93°C |

El paquete se clava en **~32W / 86-93°C bajo carga all-core — thermal-bound,
no power-bound**. Nunca llega al techo de 44W que mantenía throttled, así que
subir PL1 no compra nada (diferencia de clocks <2%, dentro del ruido térmico).
Además el config no desactivaba BD PROCHOT (`Disable_BDPROCHOT: False`) ni
aplicaba undervolt. **Deshabilitado.** Peor caso: ~2% en cargas largas (>30s).

### 3. `services.ananicy` (`package = ananicy-cpp`) — beneficio marginal con CachyOS

**Archivo:** `modules/performance/performance.nix:6`

Ananicy ajusta nice values de procesos. El scheduler BORE del CachyOS
kernel ya prioriza procesos interactivos mejor que ananicy. El daemon suma
carga sin beneficio medible.

### 4. `splash` en kernelParams sin plymouth

**Archivo:** `modules/boot/systemd/systemd.nix:35`

```nix
kernelParams = [ "quiet" "splash" "loglevel=3" "udev.log_level=3" ];
```

`splash` no hace nada si plymouth no está configurado. El kernel lo ignora
silenciosamente.

**Fix:**
```nix
kernelParams = [ "quiet" "loglevel=3" "udev.log_level=3" ];
```

### 5. `connect-timeout = 5` — muy agresivo

**Archivo:** `hosts/host.nix:72`

Con conexiones lentas, builds de flake contra cachés grandes (chaotic,
nix-community) pueden fallar por timeout falso. 5 segundos es poco para el
primer handshake contra un mirror lento.

**Fix:** subir a `10` o `15`.

### 6. `services.udisks2` habilitado en dos módulos

**Archivos:** `modules/hardware/hardware.nix:81` y `modules/wm/hyprland.nix:33`

`services.udisks2.enable = true` está en ambos. Nix mergea bien, pero es
 redundante. Dejar solo en `hardware.nix`.

### 7. `hardware.enableAllFirmware = true`

**Archivo:** `modules/hardware/hardware.nix:102`

Habilita TODO el firmware, incluyendo el no-redistribuible que la máquina no
necesita. No es un problema de performance (los blobs son archivos en disco,
el kernel los carga on-demand; no hay costo en runtime) — es pureza y espacio.
Alternativa más acotada:

```nix
hardware.enableRedistributableFirmware = true;
```

Da microcode + firmwares wifi redistribuibles sin arrastrar el resto.

### 8. `electron-39.8.10` en `permittedInsecurePackages`

**Archivo:** `modules/home-manager/home.nix:49`

Necesario por `bitwarden-desktop`. Electron 39 es EOL con CVEs públicos.
Alternativa: `bitwarden-cli` + extensión de navegador, o evaluar si
`bitwarden-desktop` en flatpak funciona sin esto.

---

## 🟢 Todo bien (confirmado)

| Aspecto | Status |
|---|---|
| TLP + `power-profiles-daemon` disabled | Correcto, compiten |
| `dbus.implementation = "broker"` | Más rápido que dbus-daemon |
| TLP + thermald | No compiten |
| CachyOS kernel + early KMS (i915 en initrd) | Bien |
| nftables + firewall | NixOS los integra bien |
| systemd-resolved stub disabled + Pi-hole host net | Limpio |
| zram + disco swap coexistiendo | Sensato (zram rápido + disco como safety net) |
| `nix.settings.use-cgroups = true` | Sandboxing moderno |
| `gc.automatic` semanal + 14d retention | Buen balance |
| Systemd-boot + `configurationLimit = 5` | No llena la ESP |
| Pi-hole reachable solo por tailscale | Firewall bien configurado |
| `programs.command-not-found` disabled + nix-index | nix-index es superior |
| `vm.swappiness = 180` con zram | **Correcto** — es el default de Fedora con zram; swappiness alto prefiere el swap comprimido en RAM antes que evictar page cache |

---

## 🔧 Resumen de acciones

| Prioridad | Acción | Archivo |
|-----------|--------|---------|
| ⏸ Diferido | `PasswordAuthentication = false` (sin key SSH instalada) | `default.nix` |
| ✅ Hecho | `connect-timeout` subido a 15 | `hosts/host.nix` |
| ✅ Hecho | `throttled` deshabilitado (medido: no-op, thermal-bound) | `modules/hardware/hardware.nix` |
| ✅ Hecho | `splash` sacado de kernelParams | `modules/boot/systemd/systemd.nix` |
| ✅ Hecho | `udisks2` duplicado sacado de hyprland.nix | `modules/wm/hyprland.nix` |
| ✅ Hecho | `ananicy` deshabilitado (BORE ya prioriza interactivos) | `modules/performance/performance.nix` |
| ✅ Hecho | `enableRedistributableFirmware` (medido: cubre todo el HW cargado) | `modules/hardware/hardware.nix` |
| Info | `electron-39.8.10` inseguro por `bitwarden-desktop` | `modules/home-manager/home.nix` |

> **Nota:** `vm.swappiness = 180` salió de la lista de acciones — es la config
> correcta para un sistema con zram, no un problema.
