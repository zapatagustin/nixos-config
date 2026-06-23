import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    id: workspaces

    required property var theme
    required property var monitor

    readonly property var jpNumbers: ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

    // VD activo en ESTE monitor: ws 1-9 → VD=ws, ws 10-18 → VD=ws-9, ws 19-27 → VD=ws-18
    readonly property int activeVD: {
        var wsId = monitor?.activeWorkspace?.id ?? 0
        return wsId > 0 ? ((wsId - 1) % 9) + 1 : 1
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: 9

            delegate: WorkspaceButton {
                required property int index
                property int vdId: index + 1

                property bool isActive: workspaces.activeVD === vdId

                property bool isOccupied: {
                    // VD N ocupa ws N, N+9, N+18
                    for (var i = 0; i < Hyprland.workspaces.values.length; i++) {
                        var ws = Hyprland.workspaces.values[i]
                        if ((ws.id === vdId || ws.id === vdId + 9 || ws.id === vdId + 18)
                                && ws.windowCount > 0) return true
                    }
                    return false
                }

                wsNumber: vdId
                jpLabel: workspaces.jpNumbers[index]
                active: isActive
                occupied: isOccupied
                theme: workspaces.theme

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("exec ~/.config/hypr/switch-group.sh " + vdId)
                }
            }
        }
    }
}
