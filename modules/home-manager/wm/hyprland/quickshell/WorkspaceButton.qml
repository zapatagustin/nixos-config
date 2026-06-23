import QtQuick

// Botón individual de workspace — estilo DWM, número japonés
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
        ? theme.accent
        : occupied
            ? theme.bg2
            : "transparent"

    // Cursor pointer al hacer hover
    HoverHandler { id: hov }

    // Highlight hover (no activo)
    Rectangle {
        anchors.fill: parent
        color: theme.fg
        opacity: hov.hovered && !btn.active ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: 80 } }
    }

    Text {
        anchors.centerIn: parent
        text: btn.jpLabel
        font.pixelSize: 12
        font.family: "Noto Sans JP"
        color: btn.active
            ? theme.accentFg
            : btn.occupied
                ? theme.fg
                : theme.inactiveFg

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Behavior on color { ColorAnimation { duration: 120 } }
}
