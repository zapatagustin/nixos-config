import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Cheatsheet — searchable list of every described Hyprland bind (SUPER+? to toggle).
//
// The data comes from `hyprctl binds -j` through get-binds.sh, re-read on EVERY
// open rather than cached at startup: a `hyprctl reload` or a home-manager switch
// can change the binds while the bar keeps running, and a cheat-sheet that lies is
// worse than no cheat-sheet. Same shape as Launcher.qml's get-apps.sh — a TSV over
// a SplitParser — so the formatting/sorting stays in the script and QML only draws.
//
// Enter deliberately does NOT execute anything. Hyprland's Lua binds report
// dispatcher "__lua" plus an opaque numeric arg, so there is nothing here that
// could be dispatched even if we wanted to; it just closes the panel.
PanelWindow {
    id: sheet

    property var theme
    property bool open: false

    // Fullscreen so the panel can be centred and so clicking anywhere outside it
    // closes — same trick as the ClipboardViewer/NotificationCenter backdrops in
    // shell.qml, except those need a second window because their panel is anchored
    // to an edge.
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusiveZone: 0
    visible: open
    color: "transparent"

    // Exclusive, like the launcher: the panel is a keyboard-driven search box, so
    // every keystroke must land here and not in the window underneath.
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    // ── Estado ────────────────────────────────────────────────────────────
    property var allBinds: []      // [{combo, desc}]
    property var filteredBinds: []
    property string query: ""
    property int selectedIndex: 0

    // Cache del último listado válido — evita panel vacío mientras refresca
    property var _allBindsCache: []

    function reloadBinds() {
        _allBindsCache = allBinds.slice() // preservar antes de limpiar
        allBinds = []
        bindLoader.running = true
    }

    Process {
        id: bindLoader
        // El script devuelve "COMBO\tdescripcion" por línea, ya ordenado
        command: ["bash", "-c", "bash ~/.config/quickshell/bar/get-binds.sh"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var tabIdx = line.indexOf("\t")
                if (tabIdx === -1) return
                var combo = line.substring(0, tabIdx).trim()
                var desc = line.substring(tabIdx + 1).trim()
                if (combo && desc)
                    sheet.allBinds.push({ combo: combo, desc: desc })
            }
        }
        onRunningChanged: {
            if (!running) sheet.filterBinds()
        }
    }

    // ── Filtro: todos los términos deben aparecer en "combo + descripción" ─
    // AND sobre términos en vez de un solo substring, para que "super shift
    // screen" encuentre la línea sin obligar a tipear el orden exacto.
    function filterBinds() {
        var source = allBinds.length > 0 ? allBinds : _allBindsCache
        var terms = query.toLowerCase().split(" ").filter(t => t !== "")
        if (terms.length === 0) {
            filteredBinds = source.slice()
        } else {
            filteredBinds = source.filter(function (b) {
                var hay = (b.combo + " " + b.desc).toLowerCase()
                return terms.every(t => hay.includes(t))
            })
        }
        selectedIndex = 0
    }

    // ── Show / Hide ───────────────────────────────────────────────────────
    function doShow() {
        reloadBinds() // refresca en bg sin dejar el panel vacío
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

    function moveSelection(delta) {
        var next = selectedIndex + delta
        if (next < 0 || next > filteredBinds.length - 1) return
        selectedIndex = next
        bindList.positionViewAtIndex(next, ListView.Contain)
    }

    // ── UI ────────────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: sheet.doHide()
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 760)
        height: Math.min(parent.height - 120, 620)
        color: sheet.theme.bg
        border.color: sheet.theme.sep
        border.width: 1

        // Swallow clicks on the panel itself so they don't reach the backdrop
        // MouseArea above and close it.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: sheet.theme.bg1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "⌨"
                        font.pixelSize: 13
                        color: sheet.theme.fg
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: "Keybindings"
                        color: sheet.theme.fg
                        font.pixelSize: 12
                        font.family: "Terminess Nerd Font Mono"
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: sheet.filteredBinds.length + " binds"
                        color: sheet.theme.fgDim
                        font.pixelSize: 11
                        font.family: "Terminess Nerd Font Mono"
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            // Buscador
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: sheet.theme.bg

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 6

                    Text {
                        text: "/"
                        color: sheet.theme.fgDim
                        font.pixelSize: 12
                        font.family: "Terminess Nerd Font Mono"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: sheet.theme.fg
                        font.pixelSize: 12
                        font.family: "Terminess Nerd Font Mono"
                        verticalAlignment: TextInput.AlignVCenter
                        selectionColor: sheet.theme.accent
                        selectedTextColor: sheet.theme.accentFg

                        onTextChanged: {
                            sheet.query = text
                            sheet.filterBinds()
                        }

                        // No vim keys here, unlike ClipboardViewer: every letter has to
                        // stay typeable because the letter IS the thing being searched
                        // for ("j" finds "Focus down").
                        Keys.onUpPressed: sheet.moveSelection(-1)
                        Keys.onDownPressed: sheet.moveSelection(1)
                        Keys.onReturnPressed: sheet.doHide()
                        Keys.onEscapePressed: sheet.doHide()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: sheet.theme.sep }

            // Lista de binds (scrolleable)
            ListView {
                id: bindList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: sheet.filteredBinds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: sheet.theme.fgDim
                        opacity: 0.5
                    }
                }

                // Vacío
                Rectangle {
                    anchors.fill: parent
                    color: sheet.theme.bg
                    visible: sheet.filteredBinds.length === 0

                    Text {
                        anchors.centerIn: parent
                        // Nothing at all means the binds carry no description yet, which
                        // is a config problem, not an empty search.
                        text: sheet.query !== "" ? "no matches" : "no described binds"
                        color: sheet.theme.fgDim
                        font.pixelSize: 12
                        font.family: "Terminess Nerd Font Mono"
                    }
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: bindList.width
                    height: 22
                    color: sheet.selectedIndex === index
                        ? sheet.theme.wsActive
                        : index % 2 === 0 ? sheet.theme.bg : sheet.theme.bg1

                    HoverHandler {
                        onHoveredChanged: if (hovered) sheet.selectedIndex = index
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        // Fixed-width key column so the descriptions line up into a
                        // readable second column instead of ragging with the combos.
                        Text {
                            Layout.preferredWidth: 230
                            text: modelData.combo
                            color: sheet.selectedIndex === index
                                ? sheet.theme.accentFg
                                : sheet.theme.yellow
                            font.pixelSize: 11
                            font.family: "Terminess Nerd Font Mono"
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.desc
                            color: sheet.selectedIndex === index
                                ? sheet.theme.accentFg
                                : sheet.theme.fg
                            font.pixelSize: 11
                            font.family: "Terminess Nerd Font Mono"
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Footer con atajos
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                color: sheet.theme.bg1

                Row {
                    anchors.centerIn: parent
                    spacing: 16

                    Repeater {
                        model: [
                            { key: "type", desc: "filter" },
                            { key: "↑/↓", desc: "navigate" },
                            { key: "↵/Esc", desc: "close" }
                        ]
                        delegate: Row {
                            required property var modelData
                            spacing: 4
                            Text {
                                text: modelData.key
                                color: sheet.theme.accent
                                font.pixelSize: 10
                                font.family: "Terminess Nerd Font Mono"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.desc
                                color: sheet.theme.fgDim
                                font.pixelSize: 10
                                font.family: "Terminess Nerd Font Mono"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
