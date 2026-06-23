import QtQuick
import Quickshell.Hyprland

// Título de la ventana activa — centro de la barra
Item {
    id: activeWindow

    required property var theme

    property string windowTitle: HyprlandInfo.focusedClient?.title ?? ""
    property string windowClass: HyprlandInfo.focusedClient?.class ?? ""

    implicitWidth: titleText.implicitWidth
    implicitHeight: titleText.implicitHeight

    Text {
        id: titleText
        anchors.centerIn: parent

        // Truncar si es muy largo
        text: activeWindow.windowTitle.length > 80
            ? activeWindow.windowTitle.substring(0, 78) + "…"
            : activeWindow.windowTitle

        color: activeWindow.theme.fg
        font.pixelSize: 12
        font.family: "Noto Sans JP"

        // Fade suave al cambiar de ventana
        Behavior on text {
            SequentialAnimation {
                NumberAnimation { target: titleText; property: "opacity"; to: 0; duration: 80 }
                PropertyAction {}
                NumberAnimation { target: titleText; property: "opacity"; to: 1; duration: 80 }
            }
        }
    }
}
