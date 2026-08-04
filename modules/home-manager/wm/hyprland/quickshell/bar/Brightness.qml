import QtQuick
import Quickshell.Io

Item {
    id: brightness

    required property var theme

    implicitWidth: row.implicitWidth
    implicitHeight: 28

    property int percent: 100

    // Instant refresh: scripts/brightness.sh appends to this pipe after running
    // brightnessctl. sysfs doesn't emit reliable inotify events, hence the
    // explicit push instead of aggressive polling. Guarded by `detected` so a
    // keypress arriving before detectBacklight resolves a device doesn't reload
    // an empty path.
    Process {
        running: true
        command: ["sh", "-c", "touch " + Paths.brightness + " && tail -n 0 -f " + Paths.brightness]
        stdout: SplitParser { onRead: () => { if (brightness.detected) currentReader.reload() } }
    }

    // Slow backstop: brightness can change outside the keys (power-profiles,
    // auto-brightness). FileView doesn't spawn a process → cheap. max_brightness
    // is constant, read once via detectBacklight/reload above.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: { if (brightness.detected) currentReader.reload() }
    }

    property int rawCurrent: 0
    property int rawMax: 1
    // True once detectBacklight has assigned real paths to both readers. Guards
    // reload() calls from the pipe/timer above against firing while paths are
    // still empty (detection is async).
    property bool detected: false
    // True only once both readers have successfully loaded and rawMax is a
    // usable divisor. Never latched from device *detection* alone — resolving
    // a device name proves nothing about being able to read it. Recomputed on
    // every load/failure so a later read failure reverts the bar to "--"
    // instead of freezing on the last good percent.
    property bool currentOk: false
    property bool maxOk: false
    property bool available: false

    function refreshAvailability() {
        brightness.available = brightness.currentOk && brightness.maxOk && brightness.rawMax > 0
    }

    // Device name differs per host (intel_backlight, acpi_video0, ...), so resolve it at
    // runtime instead of hardcoding one. Real backlight devices (*_backlight, amdgpu_bl0,
    // ...) are preferred over acpi_video0 — ACPI firmware exposes acpi_video0 alongside
    // the real device on plenty of non-discrete-GPU hardware, and it's not necessarily
    // the one brightnessctl drives, so picking it first would desync the bar from the
    // actual backlight. acpi_video0 is only used when no real backlight device is present.
    // If the directory is empty, `available` stays false and the widget shows "--" instead
    // of a stale/default percent.
    Process {
        id: detectBacklight
        running: true
        command: [
            "sh", "-c",
            "{ ls -1 /sys/class/backlight/ 2>/dev/null | grep -v '^acpi_video'; ls -1 /sys/class/backlight/ 2>/dev/null | grep '^acpi_video'; } | head -n1"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                var name = line.trim()
                if (name === "") return
                var dir = "/sys/class/backlight/" + name
                currentReader.path = dir + "/brightness"
                maxReader.path = dir + "/max_brightness"
                brightness.detected = true
                currentReader.reload()
                maxReader.reload()
            }
        }
    }

    // Do NOT set `preload: false` here. With preload off, FileView.qml's
    // onPathChanged leaves __preload false, and reload() will not start a FIRST
    // read — it only re-reads an already-loaded file. Assigning `path` from
    // detectBacklight then produced no read at all: neither onLoaded nor
    // onLoadFailed ever fired, so currentOk/maxOk stayed false and the widget
    // showed "--" forever with nothing in the log to explain it (verified against
    // quickshell 0.3.0). With preload on, the path assignment itself loads, and
    // reload() still works for the pipe/timer refresh below. An empty initial
    // path does not emit a spurious load failure, so the guard is unnecessary.
    // qmllint cannot catch this — it is a runtime semantic, not a type error.
    FileView {
        id: currentReader
        onLoaded: {
            var v = parseInt(currentReader.text())
            brightness.currentOk = !isNaN(v)
            if (brightness.currentOk) brightness.rawCurrent = v
            brightness.refreshAvailability()
            if (brightness.available) brightness.percent = Math.round(brightness.rawCurrent / brightness.rawMax * 100)
        }
        onLoadFailed: {
            brightness.currentOk = false
            brightness.refreshAvailability()
        }
    }

    // Same as currentReader above: preload must stay on or reload() never fires.
    FileView {
        id: maxReader
        onLoaded: {
            var v = parseInt(maxReader.text())
            brightness.maxOk = !isNaN(v) && v > 0
            if (brightness.maxOk) brightness.rawMax = v
            brightness.refreshAvailability()
            if (brightness.available) brightness.percent = Math.round(brightness.rawCurrent / brightness.rawMax * 100)
        }
        onLoadFailed: {
            brightness.maxOk = false
            brightness.refreshAvailability()
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Text {
            text: "BRI:"
            color: brightness.theme.fgDim
            font.pixelSize: 11
            font.family: "Terminess Nerd Font Mono"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: brightness.available ? brightness.percent + "%" : "--"
            color: brightness.available ? brightness.theme.fg : brightness.theme.fgDim
            font.pixelSize: 11
            font.family: "Terminess Nerd Font Mono"
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
