import QtQuick

Rectangle {
    id: btn

    required property int wsNumber
    required property string jpLabel
    required property bool active
    required property bool occupied
    required property var theme

    implicitWidth: 22
    implicitHeight: 22

    color: active
        ? btn.theme.wsActive
        : occupied
            ? btn.theme.wsOccupied
            : btn.theme.wsEmpty

    HoverHandler { id: hov }

    Rectangle {
        anchors.fill: parent
        color: btn.theme.fg
        opacity: hov.hovered && !btn.active ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: 80 } }
    }

    Text {
        renderType: Theme.render
        anchors.centerIn: parent
        text: btn.jpLabel
        font.pixelSize: Theme.size
        font.family: Theme.mono
        color: btn.active
            ? btn.theme.wsActiveText
            : btn.occupied
                ? btn.theme.wsOccText
                : btn.theme.wsEmptyText

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Behavior on color { ColorAnimation { duration: 120 } }
}
