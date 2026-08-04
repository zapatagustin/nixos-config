import QtQuick
import Quickshell
import Quickshell.Io

// Caffeine toggle: one click inhibits idle dim, lock, dpms off and suspend.
// State lives in caffeine.service, not here — the same `caffeine` command is
// reachable from a terminal and the unit outlives a quickshell restart, so this
// widget both asks for the truth at startup and follows the qs-caffeine pipe
// afterwards rather than tracking a local boolean of its own.
Text {
    id: caffeineIcon

    required property var theme
    property bool inhibited: false

    // Mate while the idle timers are live, coffee while they are inhibited. Both
    // are colour emoji, so the glyph — not the colour below — is what actually
    // reads on screen: U+1F9C9 comes only from Noto Color Emoji here (fc-list
    // ':charset=1F9C9'), which is why the pair must not be split across fonts.
    text: caffeineIcon.inhibited ? "☕" : "🧉"
    font.pixelSize: 11
    // Kept for the monochrome fallback (DejaVu covers U+2615) and for hover
    // feedback, same convention as the clipboard and bell icons next to it.
    color: caffeineHover.hovered
        ? caffeineIcon.theme.accent
        : caffeineIcon.inhibited
            ? caffeineIcon.theme.aqua
            : caffeineIcon.theme.fgDim
    opacity: caffeineIcon.inhibited ? 1.0 : 0.55

    HoverHandler { id: caffeineHover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // execDetached, not a reused Process: `systemctl --user start` waits for
        // the job to settle, and a Process still running silently ignores every
        // later start — the trap documented in RightSection.qml.
        onClicked: Quickshell.execDetached(["bash", Paths.caffeineCmd, "toggle"])
    }

    // Startup readback. The inhibitor is a systemd unit, so it survives a bar
    // restart; assuming `off` here would show a lie until the next click.
    Process {
        command: ["bash", Paths.caffeineCmd, "status"]
        running: true
        stdout: SplitParser {
            onRead: (line) => caffeineIcon.inhibited = line.trim() === "on"
        }
    }

    // Push channel, so a `caffeine` run from a terminal flips the icon too.
    IpcWatcher {
        pipePath: Paths.caffeine
        onTriggered: (line) => {
            if (line === "on" || line === "off")
                caffeineIcon.inhibited = (line === "on")
        }
    }
}
