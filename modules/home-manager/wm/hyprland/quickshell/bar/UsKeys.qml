pragma Singleton
import QtQuick

// Resolves a key event to the letter at that PHYSICAL position in the US
// (qwerty) layout, so the vim-style shortcuts in NotificationCenter and
// ClipboardViewer stay on the same physical keys when the active XKB group
// is us(dvorak) — the same policy as the Hyprland binds (matched against
// the first kb_layout entry) and the editors' dvorak->qwerty command remap.
//
// event.key can't do this: Qt fills it from the keysym the active layout
// produces, so letter comparisons drift with the layout. nativeScanCode is
// the XKB keycode (evdev + 8) on both Wayland and X11 — layout-independent.
QtObject {
    readonly property var scanToUs: ({
        24: "q", 25: "w", 26: "e", 27: "r", 28: "t", 29: "y", 30: "u", 31: "i", 32: "o", 33: "p",
        38: "a", 39: "s", 40: "d", 41: "f", 42: "g", 43: "h", 44: "j", 45: "k", 46: "l",
        52: "z", 53: "x", 54: "c", 55: "v", 56: "b", 57: "n", 58: "m"
    })

    // Lowercase US letter at the event's physical key, or "" for anything else.
    function letter(event) {
        return scanToUs[event.nativeScanCode] || ""
    }
}
