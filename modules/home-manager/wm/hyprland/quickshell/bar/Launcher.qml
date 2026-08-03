import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: launcher

    property var theme
    property bool open: false

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 28
    exclusiveZone: 0
    visible: open
    color: "transparent"

    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    // ── Estado ────────────────────────────────────────────────────────────
    property var allApps: []      // [{name, exec}]
    property var filteredApps: [] // subset filtrado
    property string query: ""
    property int selectedIndex: 0
    property bool loaded: false

    // Cache del último listado válido — evita pantalla vacía mientras refresca
    property var _allAppsCache: []

    // ── Cargar apps al inicio con el script (estilo dmenu_run) ────────────
    Component.onCompleted: reloadApps()

    function reloadApps() {
        _allAppsCache = allApps.slice() // preservar antes de limpiar
        loaded = false
        allApps = []
        appLoader.running = true
    }

    Process {
        id: appLoader
        // El script devuelve "Nombre\tcomando" por línea
        command: ["bash", "-c", "bash ~/.config/quickshell/bar/get-apps.sh"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var parts = line.split("\t")
                if (parts.length >= 2) {
                    var name = parts[0].trim()
                    var exec = parts.slice(1).join("\t").trim()
                    if (name && exec)
                        launcher.allApps.push({ name: name, exec: exec })
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                launcher.loaded = true
                launcher.filterApps()
            }
        }
    }

    // ── Filtrar igual que dmenu: primero los que empiezan, luego contienen ─
    function filterApps() {
        var source = allApps.length > 0 ? allApps : _allAppsCache
        var q = query.toLowerCase()
        if (q === "") {
            filteredApps = source.slice()
        } else {
            var starts   = source.filter(a =>  a.name.toLowerCase().startsWith(q))
            var contains = source.filter(a => !a.name.toLowerCase().startsWith(q)
                                            &&  a.name.toLowerCase().includes(q))
            filteredApps = starts.concat(contains)
        }
        selectedIndex = 0
    }

    function launch() {
        if (filteredApps.length === 0) return
        var cmd = filteredApps[selectedIndex].exec
        doHide()
        // uwsm app -- puts each app in its own systemd scope (ordered cleanup).
        // Spawn directly instead of `hyprctl dispatch exec`: launching an app doesn't need
        // the compositor, so it doesn't depend on which parser hyprctl uses (with a Lua
        // config, dispatch's argument is parsed as Lua, not hyprlang).
        //
        // execDetached, not a reused Process: `uwsm app` stays attached to the scope and
        // doesn't return until the app exits, so a shared Process stays running forever
        // after the first launch and every later one is silently ignored (assigning
        // command/running on a Process that's still running is a no-op).
        Quickshell.execDetached(["bash", "-c", "uwsm app -- " + cmd])
    }

    function doShow() {
        reloadApps() // refresca en bg sin dejar la lista vacía
        query = ""
        searchInput.text = ""
        selectedIndex = 0
        open = true
        focusTimer.restart()
    }

    function doHide() {
        open = false
        query = ""
        searchInput.text = ""
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    // ── UI: idéntico a dmenu ──────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: launcher.theme.bg

        Row {
            anchors.fill: parent
            spacing: 0

            // Prompt
            Rectangle {
                width: promptText.implicitWidth + 16
                height: parent.height
                color: launcher.theme.wsActive

                Text {
                    id: promptText
                    anchors.centerIn: parent
                    text: "run:"
                    color: launcher.theme.accentFg
                    font.pixelSize: 12
                    font.family: "Terminess Nerd Font Mono"
                    font.weight: Font.Bold
                }
            }

            // Input
            Rectangle {
                width: 180
                height: parent.height
                color: launcher.theme.bg1

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: launcher.theme.fg
                    font.pixelSize: 12
                    font.family: "Terminess Nerd Font Mono"
                    selectionColor: launcher.theme.accent
                    selectedTextColor: launcher.theme.accentFg

                    onTextChanged: {
                        launcher.query = text
                        launcher.filterApps()
                    }

                    Keys.onUpPressed:     { if (launcher.selectedIndex > 0) launcher.selectedIndex-- }
                    Keys.onDownPressed:   { if (launcher.selectedIndex < launcher.filteredApps.length - 1) launcher.selectedIndex++ }
                    Keys.onTabPressed:    { launcher.selectedIndex = (launcher.selectedIndex + 1) % Math.max(1, launcher.filteredApps.length) }
                    Keys.onReturnPressed: launcher.launch()
                    Keys.onEscapePressed: launcher.doHide()
                }
            }

            Rectangle { width: 1; height: parent.height; color: launcher.theme.sep }

            // Resultados horizontales
            Row {
                id: resultsRow
                height: parent.height
                spacing: 0

                Repeater {
                    model: Math.min(launcher.filteredApps.length, 20)

                    delegate: Row {
                        required property int index
                        height: parent.height
                        spacing: 0

                        Rectangle {
                            width: itemLabel.implicitWidth + 16
                            height: parent.height
                            color: launcher.selectedIndex === index
                                ? launcher.theme.wsActive
                                : "transparent"

                            HoverHandler {
                                onHoveredChanged: if (hovered) launcher.selectedIndex = index
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { launcher.selectedIndex = index; launcher.launch() }
                            }

                            Text {
                                id: itemLabel
                                anchors.centerIn: parent
                                text: launcher.filteredApps[index]?.name ?? ""
                                color: launcher.selectedIndex === index
                                    ? launcher.theme.accentFg
                                    : launcher.theme.fg
                                font.pixelSize: 12
                                font.family: "Terminess Nerd Font Mono"
                            }
                        }

                        Rectangle {
                            width: 1
                            height: parent.height
                            color: launcher.theme.sep
                            visible: index < Math.min(launcher.filteredApps.length, 20) - 1
                        }
                    }
                }
            }
        }
    }
}
