pragma Singleton
import QtQuick

QtObject {
    // VGA8 lacks Nerd Font and kanji glyphs; Qt falls back via fontconfig
    // (Symbols Nerd Font alias, IBM Plex Sans JP / udev-gothic) for those.
    readonly property string mono: "PxPlus IBM VGA8"
    // 16 = native 8x16 cell. Crispness on the pixel grid comes from two things:
    // only multiples of 16 physical px (Bar.uiScale = 2 / monitorScale gives 32 px
    // on hidpi panels, 16 px at scale 1), and NativeRendering on every text via
    // `renderType: Theme.render` (distance-field rendering blurs pixel fonts).
    readonly property int size: 16
    readonly property int render: Text.NativeRendering
}
