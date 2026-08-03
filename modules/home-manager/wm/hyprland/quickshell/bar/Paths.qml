pragma Singleton
import QtQuick
import Quickshell

// Central resolver for the qs-* file paths. The ephemeral IPC signals and logs
// live under $XDG_RUNTIME_DIR (per-user, mode 0700) instead of world-writable
// /tmp; clipboardPinned is the one exception and is carved out below.
// The shell/Lua side (default.nix, scripts/) must resolve the exact same
// paths — see the matching "${XDG_RUNTIME_DIR}/qs-*" usages there.
QtObject {
    // Mirrors the shell side's "${XDG_RUNTIME_DIR:-/tmp}" fallback so reader
    // and writer never silently disagree if the var is ever unset.
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    readonly property string theme: runtimeDir + "/qs-theme"
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
