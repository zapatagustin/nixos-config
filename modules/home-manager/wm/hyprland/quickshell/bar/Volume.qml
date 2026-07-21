import QtQuick
import Quickshell.Io

Item {
    id: volume

    required property var theme

    implicitWidth: row.implicitWidth
    implicitHeight: 28

    property int percent: 0
    property bool muted: false
    property bool isExternal: false

    // Leer volumen + mute del sink por defecto con wpctl (pipewire nativo; este
    // sistema no tiene pactl/pulseaudio). "Volume: 0.30" o "Volume: 0.30 [MUTED]".
    Process {
        id: volProcess
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var m = line.match(/Volume: ([0-9.]+)/)
                if (m) volume.percent = Math.round(parseFloat(m[1]) * 100)
                volume.muted = line.indexOf("MUTED") !== -1
            }
        }
    }

    function refresh() {
        volProcess.running = true
    }

    // Refresh instantáneo: los binds de volumen (binds.conf) escriben en este
    // pipe tras correr wpctl. wpctl no tiene `subscribe`, así que el push
    // explícito reemplaza al viejo `pactl subscribe`.
    Process {
        running: true
        command: ["sh", "-c", "touch /tmp/qs-volume && tail -n 0 -f /tmp/qs-volume"]
        stdout: SplitParser { onRead: () => debounce.restart() }
    }

    // Coalesce ráfagas (mantener apretada la tecla de volumen dispara muchos
    // eventos); refresca una sola vez 60ms después del último.
    // ponytail: debounce fijo 60ms; subir si se siente laggy al soltar la tecla.
    Timer {
        id: debounce
        interval: 60
        repeat: false
        onTriggered: { volume.refresh(); volume.refreshSinkType() }
    }

    // Detect if default audio sink is external (USB/HDMI) vs built-in
    Process {
        id: sinkTypeProcess
        command: [
            "sh", "-c",
            "wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q 'Built-in' && echo internal || echo external"
        ]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                volume.isExternal = (line.trim() === "external")
            }
        }
    }

    function refreshSinkType() {
        sinkTypeProcess.running = true
    }

    // Refresh volume + sink type every 5s (backstop for changes outside key binds)
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: { volume.refresh(); volume.refreshSinkType() }
    }

    Component.onCompleted: { volume.refresh(); volume.refreshSinkType() }

    property string volColor: {
        if (volume.muted) return volume.theme.fgDim
        if (volume.percent > 100) return volume.theme.yellow
        return volume.theme.fg
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Text {
            text: volume.muted ? "VOL:M" : "VOL:"
            color: volume.theme.fgDim
            font.pixelSize: 11
            font.family: "Terminess Nerd Font Mono"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: volume.muted ? "---" : volume.percent + "%"
            color: volume.volColor
            font.pixelSize: 11
            font.family: "Terminess Nerd Font Mono"
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        // External audio indicator (USB headset, HDMI, etc.)
        Text {
            text: "EXT"
            color: volume.theme.accent
            font.pixelSize: 10
            font.family: "Terminess Nerd Font Mono"
            font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
            visible: volume.isExternal
        }
    }
}
