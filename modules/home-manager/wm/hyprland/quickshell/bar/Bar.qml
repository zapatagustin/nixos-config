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

    // Base (logical) bar height; scaled up on hidpi laptop panels below.
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

    // The bar renders in the compositor's logical space, so 28px looks the same
    // on every monitor — but on a small hidpi laptop panel (fractional scale >1)
    // that's physically tiny. Bump the whole bar there; externals (scale 1) stay
    // as before. Tune the 1.25 if the laptop bar feels off.
    readonly property real uiScale: (bar.hyprMonitor && bar.hyprMonitor.scale > 1.05) ? 1.25 : 1.0

    implicitHeight: Math.round(baseHeight * uiScale)
    exclusiveZone: implicitHeight

    Rectangle {
        // Sized in base logical px, then scaled from the top-left so fonts,
        // spacing and separators all grow uniformly by uiScale.
        width: bar.width / bar.uiScale
        height: bar.baseHeight
        transformOrigin: Item.TopLeft
        scale: bar.uiScale
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
