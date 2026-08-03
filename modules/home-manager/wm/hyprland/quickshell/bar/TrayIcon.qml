import QtQuick
import QtQuick.Controls
import Quickshell
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
                contextMenu.open()
            }
        }
    }

    // Menú contextual usando el DBusMenu del item
    QsMenuAnchor {
        id: contextMenu
        menu: trayIcon.item.menu
        anchor.window: trayIcon.QsWindow.window
    }
}
