import QtQuick
import QtQuick.Controls
import Quickshell.Services.SystemTray

// Ícono individual del system tray con menú contextual
Item {
    id: trayIcon

    required property SystemTrayItem item
    required property var theme

    implicitWidth: 20
    implicitHeight: 20

    HoverHandler { id: hov }

    // Fondo hover
    Rectangle {
        anchors.fill: parent
        color: trayIcon.theme.fg
        opacity: hov.hovered ? 0.10 : 0
        radius: 2
        Behavior on opacity { NumberAnimation { duration: 80 } }
    }

    // Ícono
    Image {
        anchors.centerIn: parent
        width: 14
        height: 14
        source: trayIcon.item.icon
        smooth: true
        mipmap: true
    }

    // Click izquierdo: activate; click derecho: menú
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                trayIcon.item.activate()
            } else {
                contextMenu.popup()
            }
        }
    }

    // Menú contextual del tray
    Menu {
        id: contextMenu

        Instantiator {
            model: trayIcon.item.menu?.children ?? []

            delegate: MenuItem {
                required property SystemTrayMenuItem modelData
                text: modelData.label
                enabled: modelData.enabled
                onTriggered: modelData.activate()
            }

            onObjectAdded: (idx, obj) => contextMenu.insertItem(idx, obj)
            onObjectRemoved: (idx, obj) => contextMenu.removeItem(obj)
        }
    }
}
