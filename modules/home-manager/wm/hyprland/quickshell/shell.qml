// shell.qml — Entry point de la barra Gruvbox para Hyprland
import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    id: root

    // ─── Detección día/noche ───────────────────────────────────────────────
    // Día:   07:00–19:00 → Gruvbox Light
    // Noche: 19:00–07:00 → Gruvbox Dark
    property bool isDark: {
        var h = new Date().getHours();
        return (h < 7 || h >= 19);
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            var h = new Date().getHours();
            root.isDark = (h < 7 || h >= 19);
        }
    }

    // ─── Gruvbox Dark ──────────────────────────────────────────────────────
    property var darkTheme: ({
        bg:          "#282828",
        bg1:         "#3c3836",
        bg2:         "#504945",
        fg:          "#ebdbb2",
        fgDim:       "#a89984",
        yellow:      "#d79921",
        blue:        "#83a598",
        aqua:        "#689d6a",
        wsActive:    "#d79921",
        wsOccupied:  "#83a598",
        wsEmpty:     "#3c3836",
        wsActiveText:"#282828",
        wsOccText:   "#282828",
        wsEmptyText: "#665c54",
        sep:         "#504945"
    })

    // ─── Gruvbox Light ─────────────────────────────────────────────────────
    property var lightTheme: ({
        bg:          "#f9f5d7",
        bg1:         "#ebdbb2",
        bg2:         "#d5c4a1",
        fg:          "#3c3836",
        fgDim:       "#7c6f64",
        yellow:      "#b57614",
        blue:        "#076678",
        aqua:        "#427b58",
        wsActive:    "#b57614",
        wsOccupied:  "#076678",
        wsEmpty:     "#ebdbb2",
        wsActiveText:"#f9f5d7",
        wsOccText:   "#f9f5d7",
        wsEmptyText: "#bdae93",
        sep:         "#d5c4a1"
    })

    property var theme: isDark ? darkTheme : lightTheme

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
            barTheme: root.theme
            barIsDark: root.isDark
        }
    }
}
