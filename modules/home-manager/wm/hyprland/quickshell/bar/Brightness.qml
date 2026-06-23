import QtQuick
import Quickshell.Io

Item {
    id: brightness

    required property var theme

    implicitWidth: row.implicitWidth
    implicitHeight: 28

    property int percent: 100

    // Refresh instantáneo: los binds de brillo (binds.conf) escriben en este
    // pipe tras correr brightnessctl. sysfs no emite inotify confiable, por eso
    // el push explícito en vez de polling agresivo.
    Process {
        running: true
        command: ["sh", "-c", "touch /tmp/qs-brightness && tail -n 0 -f /tmp/qs-brightness"]
        stdout: SplitParser { onRead: () => currentReader.reload() }
    }

    // Backstop lento: brillo puede cambiar fuera de las teclas (power-profiles,
    // auto-brightness). FileView no spawnea proceso → barato. max_brightness es
    // constante, se lee 1 sola vez en Component.onCompleted (#2).
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: currentReader.reload()
    }

    property int rawCurrent: 0
    property int rawMax: 1

    FileView {
        id: currentReader
        // intel_backlight es el más común; si no funciona probar acpi_video0
        path: "/sys/class/backlight/intel_backlight/brightness"
        onLoaded: {
            var v = parseInt(currentReader.text())
            if (!isNaN(v)) {
                brightness.rawCurrent = v
                brightness.percent = Math.round(brightness.rawCurrent / brightness.rawMax * 100)
            }
        }
    }

    FileView {
        id: maxReader
        path: "/sys/class/backlight/intel_backlight/max_brightness"
        onLoaded: {
            var v = parseInt(maxReader.text())
            if (!isNaN(v) && v > 0) {
                brightness.rawMax = v
                brightness.percent = Math.round(brightness.rawCurrent / brightness.rawMax * 100)
            }
        }
    }

    Component.onCompleted: {
        currentReader.reload()
        maxReader.reload()
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Text {
            text: "BRI:"
            color: brightness.theme.fgDim
            font.pixelSize: 11
            font.family: "Noto Sans JP"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: brightness.percent + "%"
            color: brightness.theme.fg
            font.pixelSize: 11
            font.family: "Noto Sans JP"
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
