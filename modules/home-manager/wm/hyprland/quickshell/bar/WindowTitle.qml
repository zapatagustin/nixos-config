import QtQuick
import Quickshell.Hyprland

Item {
    id: root

    required property var theme

    property var toplevel: Hyprland.activeToplevel
    property var focusedWs: Hyprland.focusedWorkspace

    // Solo mostrar título si el toplevel activo pertenece al workspace enfocado
    property string title: {
        if (!toplevel) return ""
        if (!focusedWs) return ""
        // Comparar por id para verificar que la ventana está en el ws actual
        if (toplevel.workspace?.id !== focusedWs.id) return ""
        return toplevel.title ?? ""
    }

    implicitWidth: Math.min(titleText.implicitWidth, 400) + 8
    implicitHeight: 28

    Text {
        id: titleText
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        // Elide against the item's actual width too — the layout may shrink
        // root below implicitWidth when the bar row runs out of space.
        width: Math.min(implicitWidth, 400, root.width - 8)
        elide: Text.ElideRight

        text: root.title
        color: root.theme.fg
        font.pixelSize: 12
        font.family: "Terminess Nerd Font Mono"

        Behavior on text {
            SequentialAnimation {
                NumberAnimation { target: titleText; property: "opacity"; to: 0; duration: 80 }
                PropertyAction {}
                NumberAnimation { target: titleText; property: "opacity"; to: 1; duration: 80 }
            }
        }
    }
}
