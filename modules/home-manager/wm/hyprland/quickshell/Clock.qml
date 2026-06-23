import QtQuick

// Reloj con fecha y hora — actualización cada segundo
Item {
    id: clock

    required property var theme

    implicitWidth: timeText.implicitWidth + 6
    implicitHeight: 28

    // Timer que actualiza cada segundo
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
        anchors.centerIn: parent
        spacing: 6

        // Fecha
        Text {
            id: dateText
            text: clock.dateString
            color: clock.theme.fg4
            font.pixelSize: 11
            font.family: "Noto Sans JP"
            anchors.verticalCenter: parent.verticalCenter
        }

        // Separador
        Text {
            text: "│"
            color: clock.theme.border
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }

        // Hora
        Text {
            id: timeText
            text: clock.timeString
            color: clock.theme.fg
            font.pixelSize: 12
            font.family: "Noto Sans JP"
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
