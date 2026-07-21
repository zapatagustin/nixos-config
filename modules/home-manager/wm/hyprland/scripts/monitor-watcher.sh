#!/bin/bash
# Daemon: escucha eventos de hyprland (socket2) y re-corre setup-monitors.sh
# cuando se conecta o desconecta un monitor, o cuando se recarga la config
# (configreloaded) — p.ej. el `hyprctl reload` que dispara cada nixos-rebuild,
# que si no re-aplicamos deja los externos en el fallback y pierde las
# workspace rules dinámicas.
# Debounce: si varios eventos llegan en ráfaga (típico al conectar un dock),
# solo corre setup-monitors.sh una vez, 1.5s después del último evento.

SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
SETUP="$HOME/.config/hypr/setup-monitors.sh"
DEBOUNCE_SEC=1.5

# Quickshell muere a veces cuando cambia la lista de monitores (PanelWindow
# atado a un screen que desaparece). Ahora es un systemd user unit; lo
# relanzamos via systemctl si no está activo (systemd Restart=on-failure cubre
# crashes; esto cubre la salida limpia post-hotplug).
ensure_quickshell() {
    systemctl --user is-active --quiet quickshell.service && return
    systemctl --user start quickshell.service
}

# hyprpaper muere igual que quickshell al desconectar monitores. Lo relanzamos
# ANTES de setup-monitors.sh para que el aplicado de wallpapers no se saltee.
ensure_hyprpaper() {
    if systemctl --user is-active --quiet hyprpaper.service \
        && hyprctl hyprpaper listactive >/dev/null 2>&1; then
        return
    fi
    systemctl --user start hyprpaper.service
    # Esperar a que el socket IPC esté listo
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        hyprctl hyprpaper listactive >/dev/null 2>&1 && return
        sleep 0.2
    done
}

run_setup() {
    # DDC bus list (brightness.sh) is stale after a hotplug; rebuilt on next keypress.
    rm -f /tmp/ddc-buses
    ensure_hyprpaper
    bash "$SETUP"
    ensure_quickshell
}

pending_pid=0

socat -U - "UNIX-CONNECT:$SOCK" | while IFS= read -r line; do
    case "$line" in
        monitoradded*|monitorremoved*|configreloaded*)
            if [ "$pending_pid" -ne 0 ] && kill -0 "$pending_pid" 2>/dev/null; then
                kill "$pending_pid" 2>/dev/null
            fi
            ( sleep "$DEBOUNCE_SEC" && run_setup ) &
            pending_pid=$!
            ;;
    esac
done
