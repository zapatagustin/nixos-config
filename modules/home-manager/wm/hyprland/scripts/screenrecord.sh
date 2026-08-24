#!/usr/bin/env bash
# Toggle de grabación de pantalla con gpu-screen-recorder (backend kms).
# Primera invocación: picker (click = ventana/monitor, drag = región, con
# pantalla congelada) y arranca. Segunda: para, post-procesa y notifica con
# botón para abrir. Audio: salida del sistema; --mic suma el micrófono
# mergeado en un solo track (tracks separados solo reproducen uno a la vez
# en la mayoría de los players).
#
# Backend kms y no portal a propósito: portal suma HDR/ventanas/eGPU pero
# falla el import de EGL DMA-BUF en algunas configs, dejando la grabación
# muda al arrancar. Este hardware no necesita nada del portal.
#
# Adaptado de omarchy (bin/omarchy-capture-screenrecording): sin webcam
# overlay ni portal ni --resolution; el post-proceso se porta entero.
set -uo pipefail

source "$(dirname "$0")/capture-rects.sh"

state_file="$XDG_RUNTIME_DIR/screenrecord-file"
log_file="/tmp/screenrecord.log"
dir="$HOME/Videos"

mic=false
[ "${1:-}" = "--mic" ] && mic=true

active() { pgrep -f "^gpu-screen-recorder" >/dev/null; }

finalize() {
  local latest="$1"
  [ -f "$latest" ] || return 0

  # Re-encodea solo si el primer GOP trae paquetes descartables de warmup —
  # stream copy no puede recortarlos (rebobina al keyframe). Grabaciones
  # limpias quedan en el camino rápido de stream copy.
  local video_codec=(-c:v copy)
  if ffprobe -v error -select_streams v:0 -read_intervals %+0.2 \
    -show_entries packet=flags -of csv=p=0 "$latest" 2>/dev/null | grep -q D; then
    video_codec=(-c:v libx264 -preset veryfast -crf 20)
  fi

  # Recorta el primer frame y, si hay audio, normaliza a -14 LUFS en un paso.
  local args=(-y -ss 0.1 -i "$latest" "${video_codec[@]}")
  if ffprobe -v error -select_streams a -show_entries stream=codec_type \
    -of csv=p=0 "$latest" 2>/dev/null | grep -q audio; then
    # Mute duro los primeros 400ms: el pop de apertura de captura de PipeWire
    # es un transitorio casi al clipping (~130-200ms) que un fade suave no
    # atenúa; el fade de 50ms posterior evita el click en el borde.
    args+=(-af "volume=enable='lt(t,0.4)':volume=0,afade=t=in:st=0.4:d=0.05,loudnorm=I=-14:TP=-1.5:LRA=11")
  fi

  local processed="${latest%.mp4}-processed.mp4"
  if ffmpeg "${args[@]}" "$processed" -loglevel quiet 2>/dev/null; then
    mv "$processed" "$latest"
  else
    rm -f "$processed"
  fi
}

if active; then
  pkill -SIGINT -f "^gpu-screen-recorder" # SIGINT: necesario para cerrar bien el mp4

  count=0
  while active && [ "$count" -lt 50 ]; do
    sleep 0.1
    count=$((count + 1))
  done

  if active; then
    pkill -9 -f "^gpu-screen-recorder"
    notify-send -u critical "Grabación" "Hubo que matar el proceso — el video puede estar corrupto"
    rm -f "$state_file"
    exit 1
  fi

  file=$(cat "$state_file" 2>/dev/null) || true
  rm -f "$state_file"
  [ -n "${file:-}" ] || exit 0

  finalize "$file"
  preview="${file%.mp4}-preview.png"
  ffmpeg -y -i "$file" -ss 00:00:00.1 -vframes 1 -q:v 2 "$preview" -loglevel quiet 2>/dev/null || true
  action=$(notify-send -A default=Abrir "Grabación guardada" "$file" -i "$preview" -t 10000 2>/dev/null) || true
  [ "${action:-}" = "default" ] && xdg-open "$file"
  rm -f "$preview"
  exit 0
fi

mkdir -p "$dir"

hyprpicker -r -z >/dev/null 2>&1 &
freeze_pid=$!
sleep 0.1
sel=$(visible_rects | slurp) || { kill "$freeze_pid" 2>/dev/null; exit 0; } # Esc = cancelar
kill "$freeze_pid" 2>/dev/null
sel=$(snap_to_rect "$sel")
target=$(classify_capture_target "$sel")

case "$target" in
  monitor:*) capture=(-w "${target#monitor:}") ;;
  region:*)  capture=(-w "${target#region:}") ;;
esac

audio="default_output"
[ "$mic" = true ] && audio="default_output|default_input"

file="$dir/screenrecording-$(date +%Y-%m-%d_%H-%M-%S).mp4"
echo "===== $(date '+%F %T') target: $target =====" >"$log_file"
gpu-screen-recorder "${capture[@]}" -k auto -f 60 -fm cfr \
  -fallback-cpu-encoding yes -a "$audio" -ac aac -o "$file" 2>>"$log_file" &
pid=$!

# gsr tarda en montar la captura; el archivo aparece cuando arrancó de verdad.
while kill -0 "$pid" 2>/dev/null && [ ! -f "$file" ]; do
  sleep 0.2
done

if kill -0 "$pid" 2>/dev/null; then
  echo "$file" >"$state_file"
  notify-send "Grabando" "Misma tecla para parar" -t 3000
else
  notify-send -u critical "Grabación" "gpu-screen-recorder no arrancó — ver $log_file"
  exit 1
fi
