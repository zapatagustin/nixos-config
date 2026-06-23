// WorkspacesWidget.qml — Workspaces con numeración japonesa
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var barTheme

    // Números japoneses del 1 al 10
    readonly property var jpNums: ["一","二","三","四","五","六","七","八","九","十"]

    implicitWidth: wsRow.implicitWidth
    implicitHeight: 28

    // Estado de workspaces desde Hyprland
    property int activeWs: HyprlandIpc.focusedWorkspace ? HyprlandIpc.focusedWorkspace.id : 1

    // Workspaces ocupados
    property var occupiedWs: {
        var occ = {};
        for (var i = 0; i < HyprlandIpc.workspaces.length; i++) {
            occ[HyprlandIpc.workspaces[i].id] = true;
        }
        return occ;
    }

    RowLayout {
        id: wsRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: 9  // workspaces 1–9

            delegate: Item {
                id: wsItem
                required property int index
                property int wsId: index + 1
                property bool isActive: wsId === root.activeWs
                property bool isOccupied: root.occupiedWs[wsId] === true

                width: 22
                height: 22

                // Fondo del workspace
                Rectangle {
                    anchors.fill: parent
                    color: wsItem.isActive   ? root.barTheme.wsActive
                         : wsItem.isOccupied ? root.barTheme.wsOccupied
                         :                     root.barTheme.wsEmpty
                    radius: 2

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                // Número japonés
                Text {
                    anchors.centerIn: parent
                    text: root.jpNums[wsItem.index]
                    font.family: "Noto Sans CJK JP"
                    font.pixelSize: 12
                    font.weight: wsItem.isActive ? Font.Bold : Font.Normal
                    color: wsItem.isActive   ? root.barTheme.wsActiveText
                         : wsItem.isOccupied ? root.barTheme.wsOccText
                         :                     root.barTheme.wsEmptyText

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                // Click para cambiar workspace
                MouseArea {
                    anchors.fill: parent
                    onClicked: HyprlandIpc.dispatch("workspace " + wsItem.wsId)
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
