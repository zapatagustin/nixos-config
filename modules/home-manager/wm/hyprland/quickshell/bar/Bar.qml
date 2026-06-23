import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PanelWindow {
    id: bar

    required property var theme
    required property bool isDark
    required property var notifServer

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 28
    color: "transparent"
    exclusiveZone: implicitHeight

    // Monitor de Hyprland correspondiente a esta pantalla
    readonly property var hyprMonitor: {
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            if (Hyprland.monitors.values[i].name === bar.screen.name)
                return Hyprland.monitors.values[i]
        }
        return null
    }

    Rectangle {
        anchors.fill: parent
        color: bar.theme.bg

        Rectangle {
            anchors.bottom: parent.bottom
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
                color: bar.theme.sep
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                Layout.rightMargin: 6
            }

            WindowTitle {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
            }

            // Empuja la sección derecha al borde
            Item { Layout.fillWidth: true }

            // Separador entre título y sección derecha
            Rectangle {
                width: 1
                height: 14
                color: bar.theme.sep
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 4
                Layout.rightMargin: 4
            }

            // ── DERECHA: Vol + Bri + Bat + reloj ──────────────────
            RightSection {
                theme: bar.theme
                isDark: bar.isDark
                notifServer: bar.notifServer
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
