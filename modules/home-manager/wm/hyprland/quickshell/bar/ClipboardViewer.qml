import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: viewer

    property var theme
    property bool open: false

    anchors.top: true
    anchors.right: true
    implicitWidth: 380
    implicitHeight: open ? contentCol.implicitHeight : 0

    exclusiveZone: 0
    visible: open
    color: "transparent"

    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    // ── Estado ────────────────────────────────────────────────────────────
    property var allItems: []      // [{id, text, pinned}]
    property var filteredItems: []
    property string query: ""
    property int selectedIndex: 0
    property var pinnedItems: []   // persistido en archivo

    readonly property string pinnedFile: Paths.clipboardPinned

    // ── Inicialización ────────────────────────────────────────────────────
    Component.onCompleted: {
        loadPinned()
    }

    // ── Cargar items pinneados desde archivo ──────────────────────────────
    Process {
        id: pinnedReader
        command: ["sh", "-c", "cat " + shellQuote(Paths.clipboardPinned) + " 2>/dev/null || echo ''"]
        running: false
        property string buf: ""
        stdout: SplitParser {
            onRead: (line) => { pinnedReader.buf += line + "\n" }
        }
        onRunningChanged: {
            if (!running) {
                var lines = pinnedReader.buf.trim().split("\n")
                viewer.pinnedItems = lines.filter(l => l.trim() !== "")
                pinnedReader.buf = ""
                loadHistory()
            }
        }
    }

    function loadPinned() {
        pinnedItems = []
        pinnedReader.running = true
    }

    // ── Cargar historial de cliphist ──────────────────────────────────────
    Process {
        id: historyLoader
        command: ["sh", "-c", "cliphist list 2>/dev/null | head -200"]
        running: false
        property var items: []
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "") return
                // cliphist formato: "ID\tcontenido"
                var tabIdx = line.indexOf("\t")
                if (tabIdx === -1) return
                var id   = line.substring(0, tabIdx)
                var text = line.substring(tabIdx + 1).trim()
                if (text === "") return
                historyLoader.items.push({ id: id, text: text, pinned: false })
            }
        }
        onRunningChanged: {
            if (!running) {
                viewer.allItems = historyLoader.items
                historyLoader.items = []
                viewer.buildList()
            }
        }
    }

    function loadHistory() {
        historyLoader.items = []
        historyLoader.running = true
    }

    // ── Construir lista: pinneados arriba, luego historial ─────────────────
    function buildList() {
        var result = []

        // Primero los pinneados
        for (var i = 0; i < pinnedItems.length; i++) {
            result.push({ id: "pinned-" + i, text: pinnedItems[i], pinned: true })
        }

        // Luego el historial (sin duplicados de pinneados)
        for (var j = 0; j < allItems.length; j++) {
            var item = allItems[j]
            var alreadyPinned = pinnedItems.indexOf(item.text) !== -1
            if (!alreadyPinned) {
                result.push(item)
            }
        }

        filteredItems = result
        filterItems()
    }

    function filterItems() {
        var q = query.toLowerCase()
        if (q === "") {
            filteredItems = buildFilteredList()
        } else {
            filteredItems = buildFilteredList().filter(i =>
                i.text.toLowerCase().includes(q)
            )
        }
        selectedIndex = 0
    }

    function buildFilteredList() {
        var result = []
        for (var i = 0; i < pinnedItems.length; i++) {
            result.push({ id: "pinned-" + i, text: pinnedItems[i], pinned: true })
        }
        for (var j = 0; j < allItems.length; j++) {
            if (pinnedItems.indexOf(allItems[j].text) === -1)
                result.push(allItems[j])
        }
        return result
    }

    // ── Seleccionar item → copiar al clipboard ────────────────────────────
    function selectItem(item) {
        if (item.pinned) {
            // Para pinneados, usar wl-copy directo
            copyProc.command = ["sh", "-c",
                "printf '%s' " + shellQuote(item.text) + " | wl-copy"
            ]
        } else {
            // Para historial, usar cliphist decode
            copyProc.command = ["sh", "-c",
                "echo " + shellQuote(item.id + "\t" + item.text) + " | cliphist decode | wl-copy"
            ]
        }
        copyProc.running = true
        doHide()
    }

    function shellQuote(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'"
    }

    Process {
        id: copyProc
        running: false
    }

    // ── Pin / unpin ───────────────────────────────────────────────────────
    function togglePin(item) {
        var idx = pinnedItems.indexOf(item.text)
        var newPinned = pinnedItems.slice()
        if (idx === -1) {
            newPinned.unshift(item.text)  // agregar al inicio
        } else {
            newPinned.splice(idx, 1)      // quitar
        }
        pinnedItems = newPinned
        savePinned()
        buildList()
        filterItems()
    }

    Process {
        id: pinnedWriter
        running: false
    }

    function savePinned() {
        var content = pinnedItems.join("\n")
        var path = Paths.clipboardPinned
        // stateDir isn't guaranteed to exist on disk, so mkdir -p it before
        // the `>` redirect (which fails if the parent dir is missing).
        pinnedWriter.command = ["sh", "-c",
            "mkdir -p \"$(dirname " + shellQuote(path) + ")\" && printf '%s' " +
            shellQuote(content) + " > " + shellQuote(path)
        ]
        pinnedWriter.running = true
    }

    // ── Borrar item del historial ─────────────────────────────────────────
    function deleteItem(item) {
        if (item.pinned) {
            togglePin(item)
            return
        }
        deleteProc.command = ["sh", "-c",
            "echo " + shellQuote(item.id + "\t" + item.text) + " | cliphist delete"
        ]
        deleteProc.running = true
        // Quitar de la lista local inmediatamente
        allItems = allItems.filter(i => i.id !== item.id)
        buildList()
        filterItems()
    }

    Process { id: deleteProc; running: false }

    // ── Limpiar historial (conserva anclados) ─────────────────────────────
    function clearHistory() {
        clearProc.running = true
        allItems = []
        buildList()
        filterItems()
    }

    Process {
        id: clearProc
        command: ["sh", "-c", "cliphist wipe"]
        running: false
    }

    // ── Show / Hide ───────────────────────────────────────────────────────
    function doShow() {
        query = ""
        searchInput.text = ""
        loadPinned()   // recarga historial también
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

    // ── UI ────────────────────────────────────────────────────────────────
    Rectangle {
        id: contentCol
        width: parent.width
        implicitHeight: col.implicitHeight
        color: viewer.theme.bg
        border.color: viewer.theme.sep
        border.width: 1

        Column {
            id: col
            width: parent.width
            spacing: 0

            // Header
            Rectangle {
                width: parent.width
                height: 32
                color: viewer.theme.bg1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "📋"
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: "Clipboard"
                        color: viewer.theme.fg
                        font.pixelSize: 12
                        font.family: "Terminess Nerd Font Mono"
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: viewer.filteredItems.length + " items"
                        color: viewer.theme.fgDim
                        font.pixelSize: 11
                        font.family: "Terminess Nerd Font Mono"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        width: clearLabel.implicitWidth + 12
                        height: 18
                        radius: 3
                        color: clearHover.hovered
                            ? viewer.theme.accent
                            : viewer.theme.bg2
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "limpiar"
                            font.pixelSize: 10
                            font.family: "Terminess Nerd Font Mono"
                            color: clearHover.hovered
                                ? viewer.theme.accentFg
                                : viewer.theme.fgDim
                        }

                        HoverHandler { id: clearHover }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: viewer.clearHistory()
                        }
                    }
                }
            }

            // Buscador
            Rectangle {
                width: parent.width
                height: 28
                color: viewer.theme.bg

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 6

                    Text {
                        text: "/"
                        color: viewer.theme.fgDim
                        font.pixelSize: 12
                        font.family: "Terminess Nerd Font Mono"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: viewer.theme.fg
                        font.pixelSize: 12
                        font.family: "Terminess Nerd Font Mono"
                        verticalAlignment: TextInput.AlignVCenter
                        height: parent.height

                        onTextChanged: {
                            viewer.query = text
                            viewer.filterItems()
                        }

                        Keys.onPressed: (event) => {
                            var empty = text === ""

                            // Shift+A siempre ancla, sin importar si hay texto
                            if (event.key === Qt.Key_A && (event.modifiers & Qt.ShiftModifier)) {
                                if (viewer.filteredItems.length > 0)
                                    viewer.togglePin(viewer.filteredItems[viewer.selectedIndex])
                                event.accepted = true
                                return
                            }

                            // Vim keys solo cuando el input está vacío
                            if (empty) {
                                if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                                    if (viewer.selectedIndex < viewer.filteredItems.length - 1) {
                                        viewer.selectedIndex++
                                        itemList.positionViewAtIndex(viewer.selectedIndex, ListView.Contain)
                                    }
                                    event.accepted = true
                                    return
                                }
                                if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                                    if (viewer.selectedIndex > 0) {
                                        viewer.selectedIndex--
                                        itemList.positionViewAtIndex(viewer.selectedIndex, ListView.Contain)
                                    }
                                    event.accepted = true
                                    return
                                }
                                if (event.key === Qt.Key_L) {
                                    if (viewer.filteredItems.length > 0)
                                        viewer.selectItem(viewer.filteredItems[viewer.selectedIndex])
                                    event.accepted = true
                                    return
                                }
                                if (event.key === Qt.Key_H) {
                                    viewer.doHide()
                                    event.accepted = true
                                    return
                                }
                                if (event.key === Qt.Key_D) {
                                    if (viewer.filteredItems.length > 0)
                                        viewer.deleteItem(viewer.filteredItems[viewer.selectedIndex])
                                    event.accepted = true
                                    return
                                }
                            }

                            // Arrow keys siempre navegan
                            if (event.key === Qt.Key_Down) {
                                if (viewer.selectedIndex < viewer.filteredItems.length - 1) {
                                    viewer.selectedIndex++
                                    itemList.positionViewAtIndex(viewer.selectedIndex, ListView.Contain)
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                if (viewer.selectedIndex > 0) {
                                    viewer.selectedIndex--
                                    itemList.positionViewAtIndex(viewer.selectedIndex, ListView.Contain)
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (viewer.filteredItems.length > 0)
                                    viewer.selectItem(viewer.filteredItems[viewer.selectedIndex])
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                viewer.doHide()
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: viewer.theme.sep }

            // Lista de items (scrolleable)
            ListView {
                id: itemList
                width: parent.width
                height: Math.min(contentHeight, 480)
                clip: true
                model: viewer.filteredItems

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: viewer.theme.fgDim
                        opacity: 0.5
                    }
                }

                // Vacío
                Rectangle {
                    anchors.fill: parent
                    color: viewer.theme.bg
                    visible: viewer.filteredItems.length === 0

                    Text {
                        anchors.centerIn: parent
                        text: viewer.query !== "" ? "sin resultados" : "historial vacío"
                        color: viewer.theme.fgDim
                        font.pixelSize: 12
                        font.family: "Terminess Nerd Font Mono"
                    }
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: itemList.width
                    height: itemCol.implicitHeight + 12
                    color: viewer.selectedIndex === index
                        ? viewer.theme.wsActive
                        : modelData.pinned
                            ? viewer.theme.bg2
                            : index % 2 === 0 ? viewer.theme.bg : viewer.theme.bg1

                    HoverHandler {
                        onHoveredChanged: if (hovered) viewer.selectedIndex = index
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: viewer.selectItem(modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        spacing: 6

                        Column {
                            id: itemCol
                            Layout.fillWidth: true
                            spacing: 2

                            Rectangle {
                                visible: modelData.pinned
                                width: pinnedLabel.implicitWidth + 8
                                height: 14
                                radius: 3
                                color: viewer.selectedIndex === index
                                    ? Qt.rgba(0,0,0,0.2)
                                    : viewer.theme.wsActive

                                Text {
                                    id: pinnedLabel
                                    anchors.centerIn: parent
                                    text: "anclado"
                                    font.pixelSize: 9
                                    font.family: "Terminess Nerd Font Mono"
                                    color: viewer.selectedIndex === index
                                        ? viewer.theme.fg
                                        : viewer.theme.accentFg
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.text.length > 200
                                    ? modelData.text.substring(0, 200) + "…"
                                    : modelData.text
                                color: viewer.selectedIndex === index
                                    ? viewer.theme.accentFg
                                    : viewer.theme.fg
                                font.pixelSize: 11
                                font.family: "Terminess Nerd Font Mono"
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }

                        Column {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter
                            visible: viewer.selectedIndex === index

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 3
                                color: modelData.pinned
                                    ? viewer.theme.yellow
                                    : Qt.rgba(1,1,1,0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "★"
                                    font.pixelSize: 12
                                    color: modelData.pinned
                                        ? viewer.theme.accentFg
                                        : viewer.theme.fgDim
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        viewer.togglePin(modelData)
                                        mouse.accepted = true
                                    }
                                }
                            }

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 3
                                color: Qt.rgba(1,1,1,0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.pixelSize: 11
                                    color: viewer.theme.fgDim
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        viewer.deleteItem(modelData)
                                        mouse.accepted = true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Footer con atajos
            Rectangle {
                width: parent.width
                height: 22
                color: viewer.theme.bg1

                Row {
                    anchors.centerIn: parent
                    spacing: 16

                    Repeater {
                        model: [
                            { key: "↵/l", desc: "copiar" },
                            { key: "A", desc: "anclar" },
                            { key: "d/✕", desc: "borrar" },
                            { key: "j/k", desc: "navegar" },
                            { key: "h/Esc", desc: "cerrar" }
                        ]
                        delegate: Row {
                            required property var modelData
                            spacing: 4
                            Text {
                                text: modelData.key
                                color: viewer.theme.accent
                                font.pixelSize: 10
                                font.family: "Terminess Nerd Font Mono"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.desc
                                color: viewer.theme.fgDim
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
