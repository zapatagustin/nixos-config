import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PanelWindow {
    id: bar

    required property var theme
    required property var notifServer

    anchors {
        bottom: true
        left: true
        right: true
    }

    // Bar height in logical px, identical on every output. The compositor's
    // fractional scale already normalises logical size, so scaling again by
    // monitorScale double-counted it and left the surface bar oversized
    // (~20.4 logical px font vs 16 on the externals). Keep it flat.
    readonly property int baseHeight: 28
    color: "transparent"

    // Monitor de Hyprland correspondiente a esta pantalla
    readonly property var hyprMonitor: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            if (Hyprland.monitors.values[i].name === bar.screen.name)
                return Hyprland.monitors.values[i]
        }
        return null
    }

    implicitHeight: baseHeight
    exclusiveZone: implicitHeight

    Rectangle {
        anchors.fill: parent
        color: bar.theme.bg

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: bar.theme.sep
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 0

            // ── IZQUIERDA: Workspaces + título ventana ─────────────
            Workspaces {
                theme: bar.theme
                monitor: bar.hyprMonitor
                Layout.alignment: Qt.AlignVCenter
            }

            // Separador visual entre workspaces y título
            Rectangle {
                width: 1
                height: 14
                color: "transparent" // gap kept, line not
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                Layout.rightMargin: 6
            }

            WindowTitle {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                // Elastic: shrinks below implicitWidth when the row is tight
                // (long titles on the scaled laptop panel), never grows past it.
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
            }

            // Empuja la sección derecha al borde
            Item { Layout.fillWidth: true }

            // Separador entre título y sección derecha
            Rectangle {
                width: 1
                height: 14
                color: "transparent" // gap kept, line not
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 4
                Layout.rightMargin: 4
            }

            // ── DERECHA: Vol + Bri + Bat + reloj ──────────────────
            RightSection {
                theme: bar.theme
                notifServer: bar.notifServer
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
