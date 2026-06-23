import QtQuick

Item {
    id: clock

    required property var theme

    implicitWidth: row.implicitWidth
    implicitHeight: 28

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.updateTime()
    }

    property string timeString: ""
    property string dateString: ""

    function updateTime() {
        var now = new Date()
        var h = now.getHours().toString().padStart(2, "0")
        var m = now.getMinutes().toString().padStart(2, "0")
        var s = now.getSeconds().toString().padStart(2, "0")
        clock.timeString = h + ":" + m + ":" + s

        var days   = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
        var months = ["Ene", "Feb", "Mar", "Abr", "May", "Jun",
                      "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
        clock.dateString = days[now.getDay()] + " " +
                           now.getDate() + " " +
                           months[now.getMonth()]
    }

    Component.onCompleted: updateTime()

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: clock.dateString
            color: clock.theme.fgDim
            font.pixelSize: 11
            font.family: "Noto Sans JP"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "│"
            color: clock.theme.sep
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: clock.timeString
            color: clock.theme.fg
            font.pixelSize: 12
            font.family: "Noto Sans JP"
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
