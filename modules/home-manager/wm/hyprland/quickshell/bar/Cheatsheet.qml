import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Cheatsheet — lista buscable de todos los binds con descripción (SUPER+? togglea).
//
// Los datos salen de `hyprctl binds -j` vía get-binds.sh, releídos en CADA apertura
// y no cacheados al arranque: un `hyprctl reload` o un switch de home-manager
// cambian los binds con la barra viva, y un cheat-sheet que miente es peor que no
// tenerlo. Misma forma que el get-apps.sh de Launcher.qml — TSV sobre un
// SplitParser — así el formato y el orden quedan en el script y QML solo dibuja.
//
// Enter deliberadamente NO ejecuta nada. Los binds Lua de Hyprland reportan
// dispatcher "__lua" y un arg numérico opaco, así que no hay nada acá que se pueda
// despachar aunque quisiéramos; solo cierra el panel.
PanelWindow {
    id: sheet

    property var theme
    property bool open: false

    // Fullscreen para poder centrar el panel y para que un click en cualquier lado
    // afuera lo cierre — el mismo truco que los backdrops de ClipboardViewer y
    // NotificationCenter en shell.qml, salvo que esos necesitan una segunda ventana
    // porque su panel está anclado a un borde.
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusiveZone: 0
    visible: open
    color: "transparent"

    // Exclusive, como el launcher: el panel es un buscador manejado por teclado, así
    // que cada tecla tiene que caer acá y no en la ventana de abajo.
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    // ── Estado ────────────────────────────────────────────────────────────
    property var allBinds: []      // [{combo, desc}]
    property var filteredBinds: []
    property string query: ""
    property int selectedIndex: 0

    // Cache del último listado válido — evita panel vacío mientras refresca
    property var _allBindsCache: []

    // Tres estados distintos, no dos: "loading" (script en vuelo), "error" (exit
    // code != 0, o lo mató el watchdog) y "ok". Sin esto un hyprctl ausente o un
    // JSON malformado se ven igual que una lista legítimamente vacía, que es un
    // problema de config y se arregla en otro lado.
    property string loadState: "loading"

    function reloadBinds() {
        // Doble toggle: si el loader sigue corriendo no lo reiniciamos. Reasignar
        // allBinds a mitad de parseo tira las líneas ya leídas y las que quedan en
        // el buffer del SplitParser se mezclan con el listado nuevo.
        if (bindLoader.running) return
        _allBindsCache = allBinds.slice() // preservar antes de limpiar
        allBinds = []
        loadState = "loading"
        bindWatchdog.restart()
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
        // exited(exitCode, exitStatus) es lo único que trae el código real;
        // onRunningChanged solo dice que terminó. get-binds.sh corre con
        // pipefail, así que un hyprctl ausente o un JSON malformado llegan acá
        // como exit != 0 en vez de como stdout vacío.
        //
        // Medido con un quickshell aparte, porque el orden importa: primero
        // llegan todas las líneas al SplitParser, después exited, y solo al final
        // runningChanged(false). Por eso filterBinds() se llama acá y no en
        // onRunningChanged — acá la lista ya está completa.
        //
        // qmllint tira un [signal-handler-parameters] sobre este handler
        // ("QProcess::ExitStatus no encontrado"): es un límite del compilador AOT,
        // que esta barra no usa. Verificado en runtime: el código llega bien.
        onExited: (exitCode) => {
            bindWatchdog.stop()
            // Si el watchdog ya marcó error, no lo pisamos: bajar running manda
            // SIGTERM y exited llega igual, con code 15 (medido) — que también
            // sería error, pero el motivo real es el timeout, no el exit code.
            if (sheet.loadState !== "error")
                sheet.loadState = exitCode === 0 ? "ok" : "error"
            sheet.filterBinds()
        }
    }

    // Watchdog: hyprctl contra un socket muerto (compositor caído, $HYPRLAND_
    // INSTANCE_SIGNATURE viejo) no sale nunca, y el panel se quedaría en "cargando"
    // para siempre. Matarlo y mostrar error es más honesto que un spinner eterno.
    Timer {
        id: bindWatchdog
        interval: 3000
        repeat: false
        onTriggered: {
            sheet.loadState = "error"
            // Bajar running mata el proceso de verdad (SIGTERM, processId vuelve
            // a null): no queda un hyprctl colgado por cada apertura del panel.
            bindLoader.running = false
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

        // Se come los clicks sobre el panel para que no lleguen al MouseArea de
        // backdrop de arriba y lo cierren.
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

                    // El contador también reporta el estado de carga: si el script
                    // falló pero el cache anterior todavía llena la lista, el conteo
                    // solo diría "N binds" y el error quedaría invisible.
                    Text {
                        text: sheet.loadState === "error" ? "error"
                            : sheet.loadState === "loading" ? "…"
                            : sheet.filteredBinds.length + " binds"
                        // yellow y no un rojo: el theme de shell.qml no expone un slot
                        // rojo, y agregarlo es tocar la paleta de toda la barra.
                        color: sheet.loadState === "error" ? sheet.theme.yellow : sheet.theme.fgDim
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

                        // Acá no hay teclas vim, a diferencia de ClipboardViewer: cada
                        // letra tiene que seguir siendo tipeable porque la letra ES lo
                        // que se busca ("j" encuentra "Focus down").
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
                        // Cuatro mensajes distintos, en orden de precedencia: el script
                        // todavía corre, el script falló, la búsqueda no matchea, o
                        // ningún bind trae description — que es un problema de config,
                        // no una búsqueda vacía.
                        text: sheet.loadState === "loading" ? "cargando…"
                            : sheet.loadState === "error" ? "no se pudieron leer los binds"
                            : sheet.query !== "" ? "sin resultados"
                            : "sin binds con descripción"
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

                        // Columna de teclas de ancho fijo para que las descripciones
                        // formen una segunda columna legible en vez de desalinearse
                        // atrás de cada combo.
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
                            { key: "escribir", desc: "filtrar" },
                            { key: "↑/↓", desc: "navegar" },
                            { key: "↵/Esc", desc: "cerrar" }
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
