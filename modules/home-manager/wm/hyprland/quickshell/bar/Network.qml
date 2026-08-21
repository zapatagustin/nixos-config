import QtQuick
import Quickshell.Io

Item {
    id: net

    required property var theme

    implicitWidth: row.implicitWidth
    implicitHeight: 28

    // "eth" | "wifi" | "none"
    property string linkType: "none"
    property int signal: 0
    property string name: ""

    // One line, always: "type:signal:name". Ethernet wins over wifi when both
    // are up (docked). Fields TYPE/SIGNAL come before the name so a name
    // containing ':' only pollutes the tail, which QML re-joins.
    Process {
        id: netProcess
        command: [
            "sh", "-c",
            "eth=$(nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null | grep '^ethernet:connected:' | head -1 | cut -d: -f3-); " +
            "if [ -n \"$eth\" ]; then echo \"eth:100:$eth\"; else " +
            "nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi 2>/dev/null | awk -F: '$1==\"yes\" && !f {sub(/^yes/, \"wifi\"); print; f=1} END {if (!f) print \"none:0:\"}'; fi"
        ]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var parts = line.split(":")
                net.linkType = parts[0]
                net.signal = parseInt(parts[1]) || 0
                net.name = parts.slice(2).join(":")
            }
        }
    }

    function refresh() {
        netProcess.running = true
    }

    // Instant refresh on connect/disconnect/radio events. `nmcli monitor`
    // blocks forever and prints one line per NetworkManager event.
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: () => debounce.restart() }
    }

    // Coalesce event bursts (a connect emits several monitor lines).
    Timer {
        id: debounce
        interval: 300
        repeat: false
        onTriggered: net.refresh()
    }

    // Signal-strength drift doesn't emit monitor events; poll as backstop.
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: net.refresh()
    }

    Component.onCompleted: net.refresh()

    // Weak wifi shows as color, not as a number the bar has no room to explain.
    property string netColor: {
        if (net.linkType === "none") return net.theme.fgDim
        if (net.linkType === "wifi" && net.signal <= 40) return net.theme.yellow
        return net.theme.fg
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Text {
            text: net.linkType === "eth" ? "ETH:" : net.linkType === "wifi" ? "WIFI:" : "NET:"
            color: net.theme.fgDim
            font.pixelSize: 11
            font.family: "Terminess Nerd Font Mono"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            // ecomono: hard truncation at 16 chars; switch to Text.elide with a
            // width cap if a real SSID makes this look wrong.
            text: net.linkType === "none" ? "---"
                : net.name.length > 16 ? net.name.slice(0, 15) + "…" : net.name
            color: net.netColor
            font.pixelSize: 11
            font.family: "Terminess Nerd Font Mono"
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
