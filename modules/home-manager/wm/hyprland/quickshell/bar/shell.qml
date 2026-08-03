import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

ShellRoot {
    id: root

    property bool isDark: true

    // Leer el tema actual al iniciar (Quickshell resetea isDark al reiniciar)
    Process {
        id: themeInit
        command: ["sh", "-c", "cat " + Paths.theme + " 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                var msg = line.trim()
                if (msg === "light") root.isDark = false
                if (msg === "dark")  root.isDark = true
            }
        }
    }

    IpcWatcher {
        pipePath: Paths.theme
        onTriggered: (line) => {
            if (line === "dark")  root.isDark = true
            if (line === "light") root.isDark = false
        }
    }

    property var darkTheme: ({
        bg:          "#282828",
        bg1:         "#3c3836",
        bg2:         "#504945",
        fg:          "#ebdbb2",
        fgDim:       "#a89984",
        yellow:      "#fabd2f",
        blue:        "#83a598",
        aqua:        "#8ec07c",
        accent:      "#fabd2f",
        accentFg:    "#282828",
        wsActive:    "#fabd2f",
        wsOccupied:  "#504945",
        wsEmpty:     "transparent",
        wsActiveText:"#282828",
        wsOccText:   "#ebdbb2",
        wsEmptyText: "#665c54",
        sep:         "#504945",
        border:      "#504945"
    })

    property var lightTheme: ({
        bg:          "#f9f5d7",
        bg1:         "#ebdbb2",
        bg2:         "#d5c4a1",
        fg:          "#3c3836",
        fgDim:       "#7c6f64",
        yellow:      "#b57614",
        blue:        "#076678",
        aqua:        "#427b58",
        accent:      "#b57614",
        accentFg:    "#f9f5d7",
        wsActive:    "#b57614",
        wsOccupied:  "#d5c4a1",
        wsEmpty:     "transparent",
        wsActiveText:"#f9f5d7",
        wsOccText:   "#3c3836",
        wsEmptyText: "#bdae93",
        sep:         "#d5c4a1",
        border:      "#d5c4a1"
    })

    property var theme: isDark ? darkTheme : lightTheme

    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
            theme: root.theme
            isDark: root.isDark
            notifServer: notifSrv
        }
    }

    NotificationServer {
        id: notifSrv
        keepOnReload: true
    }

    NotificationPopup {
        id: notifPopup
        theme: root.theme
        notifServer: notifSrv
        screen: Quickshell.screens[0]
    }

    NotificationCenter {
        id: notifCenter
        theme: root.theme
        notifServer: notifSrv
        screen: Quickshell.screens[0]
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusiveZone: 0
            visible: notifCenter.open
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay

            MouseArea {
                anchors.fill: parent
                onClicked: notifCenter.doHide()
            }
        }
    }

    IpcWatcher {
        pipePath: Paths.notif
        onTriggered: (line) => {
            if (line === "toggle") {
                if (notifCenter.open) notifCenter.doHide()
                else {
                    notifCenter.screen = root.focusedScreen()
                    notifCenter.doShow()
                }
            }
        }
    }

    function focusedScreen() {
        var fm = Hyprland.focusedMonitor
        if (!fm) return Quickshell.screens[0]
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === fm.name) return Quickshell.screens[i]
        }
        return Quickshell.screens[0]
    }

    Launcher {
        id: appLauncher
        theme: root.theme
        screen: Quickshell.screens[0]
    }

    ClipboardViewer {
        id: clipViewer
        theme: root.theme
        screen: Quickshell.screens[0]
    }

    // Backdrop transparente para cerrar clipboard al clickear afuera
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusiveZone: 0
            visible: clipViewer.open
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay

            MouseArea {
                anchors.fill: parent
                onClicked: clipViewer.doHide()
            }
        }
    }

    IpcWatcher {
        pipePath: Paths.launcher
        onTriggered: (line) => {
            if (line === "toggle") {
                if (appLauncher.open) appLauncher.doHide()
                else {
                    appLauncher.screen = root.focusedScreen()
                    appLauncher.doShow()
                }
            }
        }
    }

    IpcWatcher {
        pipePath: Paths.clipboard
        onTriggered: (line) => {
            if (line === "toggle") {
                if (clipViewer.open) clipViewer.doHide()
                else {
                    clipViewer.screen = root.focusedScreen()
                    clipViewer.doShow()
                }
            }
        }
    }
}
