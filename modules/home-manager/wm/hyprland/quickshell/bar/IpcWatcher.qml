import QtQuick
import Quickshell.Io

// IpcWatcher — tail -F sobre un named pipe, reconecta automáticamente si muere.
//
// -F (seguir por nombre) y no -f (seguir por descriptor): el archivo de runtime
// se borra y se recrea, y con -f tail se queda pegado al inode viejo — sin error,
// sin salir, simplemente muda. Los cuatro paneles que dependen de esto pierden
// sus hotkeys en silencio y el restartTimer de abajo nunca se entera, porque el
// proceso sigue vivo. -F reabre por path.
// Uso:
//   IpcWatcher {
//       pipePath: Paths.theme
//       onTriggered: (line) => { ... }
//   }
Item {
    id: rootWatcher

    required property string pipePath

    property bool running: true
    property int restartInterval: 1000

    signal triggered(string line)

    Process {
        command: ["sh", "-c", "touch " + rootWatcher.pipePath + " && tail -n 0 -F " + rootWatcher.pipePath]
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