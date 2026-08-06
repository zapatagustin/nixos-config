import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

ShellRoot {
    id: root

    // Only drives the toggle's 🌙/☀ glyph in RightSection. The PALETTE is read from
    // stylix's file below, so this is no longer what colours anything.
    property bool isDark: true

    // Leer el tema actual al iniciar (Quickshell resetea isDark al reiniciar).
    // Lee el modo PERSISTIDO, no el pipe: el pipe vive en XDG_RUNTIME_DIR y se
    // borra al cerrar sesión, así que al arrancar no dice nada.
    Process {
        id: themeInit
        command: ["sh", "-c", "cat " + Paths.themeMode + " 2>/dev/null"]
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
            // The colours do NOT come from isDark — this is what actually repaints
            // the bar. isDark only survives because RightSection draws 🌙 or ☀ from
            // it; deleting it as dead would take the toggle's icon with it.
            paletteFile.reload()
        }
    }

    // Colours come from stylix's generated palette, never from a table kept here.
    //
    // This replaced two hand-written gruvbox tables, and they HAD already drifted:
    // the light one opened with #f9f5d7, which is gruvbox-light-HARD, while stylix
    // has always been on gruvbox-light-medium (#fbf1c7). Nobody noticed for as long
    // as it took to go looking, which is the whole argument against keeping a second
    // copy of a palette.
    //
    // Re-reading on the qs-theme signal is race-free by construction: set-theme
    // publishes to that pipe only AFTER the home-manager activation returns, and
    // linkGeneration has relinked palette.json by then, so the file already holds
    // the palette being announced.
    property var base16: ({})

    FileView {
        id: paletteFile
        path: Paths.palette
        // preload must stay ON. See the long note in Brightness.qml: with it off,
        // reload() will not start a FIRST read, and this would silently never load
        // with nothing in the log to explain it.
        onLoaded: {
            try {
                root.base16 = JSON.parse(paletteFile.text())
            } catch (e) {
                console.error("shell.qml: " + Paths.palette + " is not valid JSON (" + e
                              + ") — the bar keeps its built-in fallback palette")
            }
        }
        onLoadFailed: console.error("shell.qml: could not read " + Paths.palette
                                    + " — the bar keeps its built-in fallback palette")
    }

    // stylix writes bare hex, without the leading '#' that a QML colour needs.
    //
    // The fallbacks are gruvbox-dark-medium, and they are deliberately NOT kept in
    // sync with tokens.nix: they only ever render when the palette file is missing or
    // unparseable, and the point then is a legible bar rather than one matching a
    // system whose theming is already broken. A bar with undefined colours is not
    // "degraded", it is invisible.
    function c(slot, fallback) {
        var v = root.base16[slot]
        return v !== undefined ? "#" + v : fallback
    }

    // base16 slot per role. fgDim is the one judgement call: it used to be #a89984,
    // gruvbox's own `gray`, which is not one of the 16 slots at all. base04 is the
    // spec's "dark foreground, used for status bars", so it is the honest home for a
    // dimmed foreground even though it shifts the colour slightly.
    property var theme: ({
        bg:           c("base00", "#282828"),
        bg1:          c("base01", "#3c3836"),
        bg2:          c("base02", "#504945"),
        fg:           c("base06", "#ebdbb2"),
        fgDim:        c("base04", "#bdae93"),
        yellow:       c("base0A", "#fabd2f"),
        blue:         c("base0D", "#83a598"),
        aqua:         c("base0C", "#8ec07c"),
        accent:       c("base0A", "#fabd2f"),
        accentFg:     c("base00", "#282828"),
        wsActive:     c("base0A", "#fabd2f"),
        wsOccupied:   c("base02", "#504945"),
        wsEmpty:      "transparent",
        wsActiveText: c("base00", "#282828"),
        wsOccText:    c("base06", "#ebdbb2"),
        wsEmptyText:  c("base03", "#665c54"),
        sep:          c("base02", "#504945"),
        border:       c("base02", "#504945")
    })

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
        // Only the value until the first notification lands: the popup reassigns
        // screen through resolveScreen() on every notification, so it opens on
        // whichever monitor the pointer is on rather than always the first one.
        screen: Quickshell.screens[0]
        resolveScreen: root.focusedScreen
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
