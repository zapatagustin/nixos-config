pragma Singleton
import QtQuick

QtObject {
    // VGA8 lacks Nerd Font and kanji glyphs; Qt falls back via fontconfig
    // (Symbols Nerd Font alias, IBM Plex Sans JP / udev-gothic) for those.
    readonly property string mono: "PxPlus IBM VGA8"
    // 16 = native 8x16 cell. The bar lays out in logical px at this size on every
    // output; crispness comes from NativeRendering on every text via
    // `renderType: Theme.render` (distance-field rendering blurs pixel fonts).
    readonly property int size: 16
    readonly property int render: Text.NativeRendering
}
