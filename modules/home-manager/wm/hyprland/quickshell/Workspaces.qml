import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

// Workspaces con numeración japonesa, estilo DWM
Item {
    id: workspaces

    required property var theme

    // Números japoneses del 1 al 10
    readonly property var jpNumbers: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 0

        Repeater {
            // Siempre mostramos 9 workspaces (como DWM por defecto)
            model: 9

            delegate: WorkspaceButton {
                required property int index
                property int wsId: index + 1

                // Workspace activo en Hyprland
                property bool isActive: HyprlandInfo.focusedMonitor?.activeWorkspace?.id === wsId
                // Workspace con ventanas (ocupado)
                property bool isOccupied: {
                    for (var ws of HyprlandInfo.workspaces) {
                        if (ws.id === wsId && ws.windowCount > 0) return true
                    }
                    return false
                }

                wsNumber: wsId
                jpLabel: workspaces.jpNumbers[index]
                active: isActive
                occupied: isOccupied
                theme: workspaces.theme

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + wsId)
                }
            }
        }
    }
}
