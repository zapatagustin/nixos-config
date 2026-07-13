import QtQuick
import Quickshell.Io

// IpcWatcher — tail -f sobre un named pipe, reconecta automáticamente si muere.
// Uso:
//   IpcWatcher {
//       pipePath: "/tmp/qs-theme"
//       onTriggered: (line) => { ... }
//   }
Item {
    id: rootWatcher

    required property string pipePath

    property bool running: true
    property int restartInterval: 1000

    signal triggered(string line)

    Process {
        command: ["sh", "-c", "touch " + rootWatcher.pipePath + " && tail -n 0 -f " + rootWatcher.pipePath]
        running: rootWatcher.running
        stdout: SplitParser {
            onRead: (line) => rootWatcher.triggered(line.trim())
        }
        onRunningChanged: {
            if (!running) restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        interval: rootWatcher.restartInterval
        repeat: false
        onTriggered: rootWatcher.running = true
    }
}