import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications

Item {
    id: rightSection

    required property var theme
    required property bool isDark
    required property var notifServer

    implicitWidth: row.implicitWidth
    implicitHeight: 28

    // Separador reutilizable
    component Sep: Rectangle {
        width: 1
        height: 14
        color: rightSection.theme.sep
        Layout.alignment: Qt.AlignVCenter
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 4

        // ── System Tray ──────────────────────────────────────────
        Repeater {
            model: SystemTray.items
            delegate: TrayIcon {
                required property SystemTrayItem modelData
                item: modelData
                theme: rightSection.theme
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Sep {}

        // ── Volumen ──────────────────────────────────────────────
        Volume {
            theme: rightSection.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Sep {}

        // ── Brillo ───────────────────────────────────────────────
        Brightness {
            theme: rightSection.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Sep {}

        // ── Red (ethernet o wifi) ────────────────────────────────
        Network {
            theme: rightSection.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Sep {}

        // ── Batería ──────────────────────────────────────────────
        Battery {
            theme: rightSection.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Sep {}

        // ── Toggle tema ──────────────────────────────────────────
        Text {
            id: themeIcon
            text: rightSection.isDark ? "🌙" : "☀"
            font.pixelSize: 11
            color: themeHover.hovered
                ? rightSection.theme.accent
                : rightSection.isDark
                    ? rightSection.theme.blue
                    : rightSection.theme.yellow
            Layout.alignment: Qt.AlignVCenter

            HoverHandler { id: themeHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // execDetached, NOT a reused Process: set-theme blocks for seconds
                // while home-manager activates the other generation, and a Process
                // that is still running silently ignores every later start — the
                // same trap that broke Launcher.qml and Workspaces.qml.
                //
                // `toggle` derives the current mode from the active generation
                // rather than from isDark, so the script stays the single source of
                // truth and the bar cannot desync it. The bar's own palette flips
                // when set-theme pushes to the qs-theme pipe (see shell.qml).
                onClicked: Quickshell.execDetached(["bash", Paths.setTheme, "toggle"])
            }
        }

        Sep {}

        // ── Toggle caffeine (inhibir idle/suspend) ───────────────
        Caffeine {
            theme: rightSection.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Sep {}

        // ── Notificaciones ───────────────────────────────────────
        Item {
            id: notifItem
            implicitWidth: bellIcon.implicitWidth + (notifItem.notifCount > 0 ? badge.width + 2 : 0)
            implicitHeight: 28
            Layout.alignment: Qt.AlignVCenter

            property int notifCount: rightSection.notifServer.trackedNotifications.values.length

            Text {
                id: bellIcon
                text: notifItem.notifCount > 0 ? "󰂚" : "󰂜"
                font.pixelSize: 13
                font.family: "Symbols Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
                color: bellHover.hovered
                    ? rightSection.theme.accent
                    : notifItem.notifCount > 0
                        ? rightSection.theme.fg
                        : rightSection.theme.fgDim

                HoverHandler { id: bellHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notifToggle.running = true
                }

                Process {
                    id: notifToggle
                    command: ["sh", "-c", "echo toggle >> " + Paths.notif]
                    running: false
                }
            }

            Rectangle {
                id: badge
                visible: notifItem.notifCount > 0
                width: badgeText.implicitWidth + 4
                height: 13
                radius: 6
                color: rightSection.theme.accent
                anchors { left: bellIcon.right; top: bellIcon.top; leftMargin: 1 }

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: notifItem.notifCount > 9 ? "9+" : notifItem.notifCount
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    color: rightSection.theme.accentFg
                }
            }
        }

        Sep {}

        // ── Clipboard ────────────────────────────────────────────
        Text {
            id: clipIcon
            text: "󰅍"
            font.pixelSize: 13
            font.family: "Symbols Nerd Font"
            color: clipHover.hovered
                ? rightSection.theme.accent
                : rightSection.theme.fgDim
            Layout.alignment: Qt.AlignVCenter

            HoverHandler { id: clipHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: clipToggle.running = true
            }

            Process {
                id: clipToggle
                command: ["sh", "-c", "echo toggle >> " + Paths.clipboard]
                running: false
            }
        }

        Sep {}

        // ── Reloj ────────────────────────────────────────────────
        Clock {
            theme: rightSection.theme
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
