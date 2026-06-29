import QtQuick
import Quickshell.Io

Item {
    id: battery

    required property var theme

    implicitWidth: row.implicitWidth
    implicitHeight: 28

    property int percent: 100
    property bool charging: false

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: { capacityReader.reload(); statusReader.reload() }
    }

    FileView {
        id: capacityReader
        path: "/sys/class/power_supply/BAT1/capacity"
        onLoaded: {
            var val = parseInt(capacityReader.text())
            if (!isNaN(val)) battery.percent = val
        }
    }

    FileView {
        id: statusReader
        path: "/sys/class/power_supply/BAT1/status"
        onLoaded: {
            battery.charging = statusReader.text().trim() === "Charging"
        }
    }

    Component.onCompleted: {
        capacityReader.reload()
        statusReader.reload()
    }

    property string batColor: {
        if (battery.charging) return battery.theme.aqua
        if (battery.percent <= 15) return battery.theme.yellow
        return battery.theme.fgDim
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Text {
            text: "BAT:"
            color: battery.theme.fgDim
            font.pixelSize: 11
            font.family: "Terminess Nerd Font Mono"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: battery.percent + "%"
            color: battery.batColor
            font.pixelSize: 11
            font.family: "Terminess Nerd Font Mono"
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
