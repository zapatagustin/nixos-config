import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: center
    required property var theme
    required property var notifServer

    anchors.top: true
    anchors.right: true
    implicitWidth: 400
    implicitHeight: open ? contentRect.implicitHeight : 0
    exclusiveZone: 0
    visible: open
    color: "transparent"

    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    property bool open: false
    property int selectedIndex: 0

    property var notifList: center.notifServer.trackedNotifications.values

    function doShow() {
        open = true
        selectedIndex = 0
        focusTimer.restart()
    }

    function doHide() {
        open = false
    }

    function dismissSelected() {
        if (selectedIndex < notifList.length)
            notifList[selectedIndex].dismiss()
    }

    function dismissAll() {
        var list = notifList.slice()
        for (var i = 0; i < list.length; i++) list[i].dismiss()
    }

    function invokeSelected() {
        if (selectedIndex < notifList.length) {
            var n = notifList[selectedIndex]
            if (n.actions.length > 0) n.actions[0].invoke()
            else n.dismiss()
            doHide()
        }
    }

    function navigate(delta) {
        var max = notifList.length - 1
        selectedIndex = Math.max(0, Math.min(selectedIndex + delta, max))
        itemList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    Timer { id: focusTimer; interval: 40; onTriggered: navInput.forceActiveFocus() }

    Rectangle {
        id: contentRect
        width: parent.width
        implicitHeight: col.implicitHeight
        color: center.theme.bg
        border.color: center.theme.sep
        border.width: 1

        Column {
            id: col
            width: parent.width
            spacing: 0

            // Header
            Rectangle {
                width: parent.width
                height: 32
                color: center.theme.bg1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "󰂚"
                        font.pixelSize: 13
                        font.family: "Symbols Nerd Font"
                        color: center.theme.accent
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: "Notificaciones"
                        color: center.theme.fg
                        font.pixelSize: 12
                        font.family: "Terminess Nerd Font Mono"
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: center.notifList.length + " items"
                        color: center.theme.fgDim
                        font.pixelSize: 11
                        font.family: "Terminess Nerd Font Mono"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        width: clearLabel.implicitWidth + 12
                        height: 18
                        radius: 3
                        color: clearHover.hovered ? center.theme.accent : center.theme.bg2
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "limpiar todo"
                            font.pixelSize: 10
                            font.family: "Terminess Nerd Font Mono"
                            color: clearHover.hovered ? center.theme.accentFg : center.theme.fgDim
                        }

                        HoverHandler { id: clearHover }
                        MouseArea { anchors.fill: parent; onClicked: center.dismissAll() }
                    }
                }
            }

            // Input invisible para capturar teclado
            Item {
                width: parent.width
                height: 0

                TextInput {
                    id: navInput
                    width: 1; height: 1
                    visible: false
                    focus: center.open

                    Keys.onPressed: (event) => {
                        // Letters via UsKeys (physical position, dvorak-proof);
                        // named keys via event.key as usual.
                        const l = UsKeys.letter(event)
                        if (l === "j" || event.key === Qt.Key_Down) {
                            center.navigate(1); event.accepted = true
                        } else if (l === "k" || event.key === Qt.Key_Up) {
                            center.navigate(-1); event.accepted = true
                        } else if (l === "d") {
                            center.dismissSelected(); event.accepted = true
                        } else if (l === "l" || event.key === Qt.Key_Return) {
                            center.invokeSelected(); event.accepted = true
                        } else if (l === "h" || event.key === Qt.Key_Escape) {
                            center.doHide(); event.accepted = true
                        } else if (l === "g") {
                            center.selectedIndex = 0
                            itemList.positionViewAtIndex(0, ListView.Beginning)
                            event.accepted = true
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: center.theme.sep }

            // Lista
            ListView {
                id: itemList
                width: parent.width
                height: notifList.length > 0 ? Math.min(contentHeight, 500) : 50
                clip: true
                model: center.notifList

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: center.theme.fgDim
                        opacity: 0.5
                    }
                }

                // Vacío
                Text {
                    anchors.centerIn: parent
                    text: "sin notificaciones"
                    color: center.theme.fgDim
                    font.pixelSize: 12
                    font.family: "Terminess Nerd Font Mono"
                    visible: center.notifList.length === 0
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: itemList.width
                    implicitHeight: delegateCol.implicitHeight + 16
                    color: center.selectedIndex === index ? center.theme.wsActive : center.theme.bg

                    // Borde izquierdo por urgencia
                    Rectangle {
                        width: 3
                        height: parent.height
                        color: urgencyAccent(modelData.urgency)
                    }

                    function urgencyAccent(u) {
                        switch (u) {
                            case NotificationUrgency.Critical: return "#fb4934"
                            case NotificationUrgency.Low:      return center.theme.sep
                            default:                           return center.theme.accent
                        }
                    }

                    HoverHandler { onHoveredChanged: if (hovered) center.selectedIndex = index }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { center.selectedIndex = index; center.invokeSelected() }
                    }

                    Column {
                        id: delegateCol
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top
                            leftMargin: 14; rightMargin: 32
                            topMargin: 8
                        }
                        spacing: 3

                        Text {
                            text: modelData.appName
                            color: center.selectedIndex === index ? center.theme.accentFg : center.theme.accent
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.family: "Terminess Nerd Font Mono"
                        }

                        Text {
                            width: parent.width
                            text: modelData.summary
                            color: center.selectedIndex === index ? center.theme.accentFg : center.theme.fg
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.family: "Terminess Nerd Font Mono"
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: modelData.body
                            color: center.selectedIndex === index ? center.theme.accentFg : center.theme.fgDim
                            font.pixelSize: 11
                            font.family: "Terminess Nerd Font Mono"
                            wrapMode: Text.WordWrap
                            visible: text !== ""
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }

                    // Botón cerrar
                    Text {
                        anchors { right: parent.right; top: parent.top; margins: 8 }
                        text: "✕"
                        font.pixelSize: 11
                        color: center.selectedIndex === index ? center.theme.accentFg : center.theme.fgDim
                        visible: center.selectedIndex === index

                        MouseArea {
                            anchors.fill: parent
                            onClicked: { modelData.dismiss(); mouse.accepted = true }
                        }
                    }
                }
            }

            // Footer
            Rectangle {
                width: parent.width
                height: 22
                color: center.theme.bg1

                Row {
                    anchors.centerIn: parent
                    spacing: 16

                    Repeater {
                        model: [
                            { key: "↵/l", desc: "acción" },
                            { key: "d/✕", desc: "borrar" },
                            { key: "j/k", desc: "navegar" },
                            { key: "h/Esc", desc: "cerrar" }
                        ]
                        delegate: Row {
                            required property var modelData
                            spacing: 4
                            Text {
                                text: modelData.key
                                color: center.theme.accent
                                font.pixelSize: 10
                                font.family: "Terminess Nerd Font Mono"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.desc
                                color: center.theme.fgDim
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
