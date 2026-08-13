import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: popup
    required property var theme
    required property var notifServer

    // Returns the QuickShell screen the popup should appear on. Injected rather
    // than computed here: shell.qml's focusedScreen() is the single place that
    // maps a Hyprland monitor onto a Quickshell.screens entry, and the
    // notification centre already resolves its own screen through it. Duplicating
    // that lookup would be a second source of truth for the same question.
    required property var resolveScreen

    anchors.top: true
    anchors.right: true
    implicitWidth: 360
    implicitHeight: current !== null ? box.implicitHeight + 12 : 0
    // Without this the window is permanently visible and idles as a 1px layer
    // surface created ONCE at startup. If that single creation fails -- and it
    // did, silently, for a 22h session where the notification centre still
    // listed every notification the popup had tracked -- there is no second
    // attempt and the popup is dead until the bar restarts. Binding visibility
    // to the content makes every notification a fresh map, so a failed one
    // costs one popup instead of the whole session. NotificationCenter,
    // Launcher and ClipboardViewer already work this way.
    visible: current !== null
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay

    property var current: null

    Connections {
        target: popup.notifServer
        function onNotification(notif) {
            // Move BEFORE assigning current, which is what makes the window
            // visible. The other order maps the layer surface on the old monitor
            // and then migrates it, i.e. one frame on the wrong screen.
            // This breaks the `screen:` binding in shell.qml permanently, which is
            // intended and is what NotificationCenter does too -- that binding is
            // only the value used until the first notification arrives.
            // input:follow_mouse is 1 (wm/hyprland/default.nix), so Hyprland's
            // focused monitor is the one the pointer is over; there is no need to
            // read the cursor position.
            popup.screen = popup.resolveScreen()
            notif.tracked = true
            popup.current = notif
            var timeout = notif.expireTimeout > 0 ? notif.expireTimeout : 5000
            dismissTimer.interval = timeout
            dismissTimer.restart()
        }
    }

    Timer {
        id: dismissTimer
        onTriggered: popup.current = null
    }

    Rectangle {
        id: box
        width: parent.width - 10
        x: 5
        y: 6
        implicitHeight: inner.implicitHeight + 16
        color: popup.theme.bg1
        border.color: urgencyColor()
        border.width: 2
        radius: 4
        visible: popup.current !== null
        clip: true

        function urgencyColor() {
            if (!popup.current) return popup.theme.sep
            switch (popup.current.urgency) {
                case NotificationUrgency.Critical: return "#fb4934"
                case NotificationUrgency.Low:      return popup.theme.sep
                default:                           return popup.theme.accent
            }
        }

        Column {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; topMargin: 8 }
            spacing: 3

            RowLayout {
                width: parent.width
                spacing: 6

                Text {
                    text: popup.current ? popup.current.appName : ""
                    color: popup.theme.accent
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.family: "Terminess Nerd Font Mono"
                    Layout.fillWidth: true
                }

                Text {
                    text: "✕"
                    color: popup.theme.fgDim
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { if (popup.current) popup.current.dismiss(); popup.current = null }
                    }
                }
            }

            Text {
                width: parent.width
                text: popup.current ? popup.current.summary : ""
                color: popup.theme.fg
                font.pixelSize: 12
                font.weight: Font.Medium
                font.family: "Terminess Nerd Font Mono"
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: popup.current ? popup.current.body : ""
                color: popup.theme.fgDim
                font.pixelSize: 11
                font.family: "Terminess Nerd Font Mono"
                wrapMode: Text.WordWrap
                visible: text !== ""
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (popup.current && popup.current.actions.length > 0)
                    popup.current.actions[0].invoke()
                popup.current = null
            }
        }
    }
}
