// Bar.qml — Contenedor principal de la barra
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: barWindow

    required property var barTheme
    required property bool barIsDark

    // Anclar al borde superior
    anchors {
        top: true
        left: true
        right: true
    }

    height: 28
    exclusiveZone: height

    color: barTheme.bg

    // Línea decorativa inferior (estilo DWM)
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: barTheme.sep
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 0

        // ── Workspaces (izquierda) ─────────────────────────────────────────
        WorkspacesWidget {
            Layout.alignment: Qt.AlignVCenter
            barTheme: barWindow.barTheme
        }

        // Separador visual
        Rectangle {
            width: 1
            height: 18
            color: barWindow.barTheme.sep
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 4
            Layout.rightMargin: 4
        }

        // ── Título de ventana activa (centro) ──────────────────────────────
        Item {
            Layout.fillWidth: true
            height: parent.height

            ActiveWindowWidget {
                anchors.centerIn: parent
                barTheme: barWindow.barTheme
            }
        }

        // Separador visual
        Rectangle {
            width: 1
            height: 18
            color: barWindow.barTheme.sep
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 4
            Layout.rightMargin: 4
        }

        // ── System Tray + Reloj (derecha) ──────────────────────────────────
        TrayWidget {
            Layout.alignment: Qt.AlignVCenter
            barTheme: barWindow.barTheme
        }

        Rectangle {
            width: 1
            height: 18
            color: barWindow.barTheme.sep
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 4
            Layout.rightMargin: 4
        }

        ClockWidget {
            Layout.alignment: Qt.AlignVCenter
            barTheme: barWindow.barTheme
            Layout.rightMargin: 6
        }
    }
}
