import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

// Sección derecha: system tray + reloj
Item {
    id: rightSection

    required property var theme
    required property bool isDark

    implicitWidth: row.implicitWidth
    implicitHeight: 28

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 4

        // ── System Tray ───────────────────────────────────────────
        Repeater {
            model: SystemTray.items

            delegate: TrayIcon {
                required property SystemTrayItem modelData
                item: modelData
                theme: rightSection.theme
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Separador visual entre tray y reloj
        Rectangle {
            width: 1
            height: 14
            color: rightSection.theme.border
            Layout.alignment: Qt.AlignVCenter
            visible: SystemTray.items.length > 0
        }

        // ── Indicador día/noche ───────────────────────────────────
        Text {
            text: rightSection.isDark ? "󰖔" : "󰖙"   // Nerd Font: luna / sol
            font.pixelSize: 11
            color: rightSection.isDark
                ? rightSection.theme.blue
                : rightSection.theme.yellow
            Layout.alignment: Qt.AlignVCenter
            font.family: "Symbols Nerd Font Mono"
        }

        // ── Reloj ─────────────────────────────────────────────────
        Clock {
            theme: rightSection.theme
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
