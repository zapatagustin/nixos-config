pragma Singleton
import QtQuick
import Quickshell

// Central resolver for the qs-* file paths. The ephemeral IPC signals and logs
// live under $XDG_RUNTIME_DIR (per-user, mode 0700) instead of world-writable
// /tmp; clipboardPinned is the one exception and is carved out below.
// The shell/Lua side (default.nix, scripts/) must resolve the exact same
// paths — see the matching "$XDG_RUNTIME_DIR/qs-*" usages there.
QtObject {
    id: paths

    // Deliberately no fallback. An earlier version fell back to /tmp to mirror
    // the shell side, but that puts these files back in a world-writable
    // directory — the exact exposure moving them here removed. Under a systemd
    // user session the variable is always set, so the unset case is a real
    // misconfiguration and should be loud, not quietly less safe. The shell side
    // uses "${XDG_RUNTIME_DIR:?...}" for the same reason.
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")

    Component.onCompleted: {
        if (paths.runtimeDir === "")
            console.error("Paths.qml: XDG_RUNTIME_DIR is unset — every qs-* path is "
                          + "invalid, so the OSDs and the launcher/clipboard/notification "
                          + "toggles will not work. Expected it from the systemd user session.")
    }

    // Theme has TWO paths on purpose. `theme` is the ephemeral push channel that
    // set-theme appends to so the bar flips instantly. `themeMode` is the persisted
    // choice, which must survive logout — otherwise every login starts on dark
    // regardless of the hour.
    //
    // themeMode deliberately does NOT use Quickshell.stateDir like clipboardPinned
    // does: stateDir is scoped per shell-id (~/.local/state/quickshell/by-shell/<id>),
    // which a plain shell script cannot resolve. XDG_STATE_HOME is computable
    // identically from both sides. Unlike XDG_RUNTIME_DIR it also has a spec-defined
    // default, so falling back here is correct rather than a silent downgrade.
    readonly property string theme: runtimeDir + "/qs-theme"
    readonly property string stateHome: {
        var s = Quickshell.env("XDG_STATE_HOME")
        return s !== "" ? s : Quickshell.env("HOME") + "/.local/state"
    }
    readonly property string themeMode: stateHome + "/hypr/theme-mode"
    readonly property string launcher: runtimeDir + "/qs-launcher"
    readonly property string clipboard: runtimeDir + "/qs-clipboard"
    // Genuine user data (not an ephemeral IPC signal/log), so it must survive
    // logout unlike the runtime-dir paths above — Quickshell.stateDir is the
    // per-user persistent state location for exactly this.
    readonly property string clipboardPinned: Quickshell.stateDir + "/qs-clipboard-pinned"
    readonly property string notif: runtimeDir + "/qs-notif"
    readonly property string volume: runtimeDir + "/qs-volume"
    readonly property string brightness: runtimeDir + "/qs-brightness"
}
