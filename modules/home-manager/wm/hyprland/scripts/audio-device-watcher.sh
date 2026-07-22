#!/usr/bin/env bash
# audio-device-watcher: notify via libnotify when PipeWire sinks/sources change
# Polls wpctl status, diffs against previous state, sends desktop notifications.
set -u

snapshot() {
    wpctl status 2>/dev/null | sed -n '
        /^Audio/,/^Video/ {
            /├─ Devices:/,/├─ Filters:/ {
                /│.*[0-9]\. / {
                    s/│  *\*  */ /
                    s/│  */ /
                    s/\[vol:[^]]*\]//g
                    s/\[alsa\]//g
                    s/\[v4l2\]//g
                    s/\[libcamera\]//g
                    s/  *$//
                    s/^  */ /
                    p
                }
            }
        }
    ' | sort
}

# Try a few times if pipewire isn't ready yet
for _ in 1 2 3; do
    prev=$(snapshot)
    [ -n "$prev" ] && break
    sleep 1
done

# ecomono: 2s poll. Perceptually instant for hand-plugged audio, cheap enough.
while sleep 2; do
    cur=$(snapshot)
    [ -z "$cur" ] && continue

    if [ "$cur" != "$prev" ]; then
        new=$(comm -13 <(echo "$prev") <(echo "$cur") | head -5)
        gone=$(comm -23 <(echo "$prev") <(echo "$cur") | head -5)

        if [ -n "$new" ]; then
            names=$(echo "$new" | sed 's/^ *[0-9]*\. //' | tr '\n' ', ' | sed 's/, $//')
            notify-send -a "Audio" "New audio device" "$names"
        fi

        if [ -n "$gone" ]; then
            names=$(echo "$gone" | sed 's/^ *[0-9]*\. //' | tr '\n' ', ' | sed 's/, $//')
            notify-send -a "Audio" "Audio device removed" "$names"
        fi

        prev=$cur
    fi
done
