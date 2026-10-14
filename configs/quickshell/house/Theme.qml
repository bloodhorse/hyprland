pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    function tone(s) { return s.length === 9 ? "#" + s.slice(7) + s.slice(1, 7) : s }

    readonly property color ground: tone(look.ground)
    readonly property color edge: tone(look.edge)
    readonly property color body: tone(look.body)
    readonly property color pick: tone(look.pick)
    readonly property color dim: tone(look.dim)
    readonly property color band: tone(look.band)
    readonly property color harm: tone(look.harm)
    readonly property color warn: tone(look.warn)
    readonly property string mono: look.font
    readonly property int size: look.size
    readonly property int radius: look.radius
    readonly property int small: 10
    readonly property real rowH: 36.6
    readonly property real head: 75.5

    FileView {
        path: Quickshell.shellPath("palette.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: look
            property string font: "JetBrainsMono Nerd Font"
            property int size: 13
            property int radius: 12
            property string ground: "#0E1719C4"
            property string edge: "#FFFFFF22"
            property string body: "#D5ECE9"
            property string pick: "#7DE8DA"
            property string dim: "#4C8581"
            property string band: "#FFFFFF16"
            property string harm: "#FF6EC7"
            property string warn: "#C58AB5"
        }
    }
}
