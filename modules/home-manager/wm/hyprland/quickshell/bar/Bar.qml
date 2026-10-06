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

    // The bar renders in compositor logical px, so it looks the same size on every
    // monitor but is physically tiny on a hidpi laptop panel. The pixel font is only
    // crisp at a multiple of 16 physical px, so on hidpi outputs scale the bar by
    // 2 / monitorScale: Theme.size (16) * uiScale * monitorScale = 32 physical px
    // (surface panel: 16 * 1.2766 * 1.566667 = 32). Scale <= 1.05 or unknown
    // (monitor not resolved yet, scale 0/undefined) stays 1.0 = 16 physical px.
    readonly property real uiScale: {
        var s = bar.hyprMonitor ? Number(bar.hyprMonitor.scale) : 0
        return (isFinite(s) && s > 1.05) ? 2 / s : 1.0
    }

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
