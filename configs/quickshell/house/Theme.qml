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
    readonly property real size: look.size
    readonly property int radius: look.radius
    readonly property real small: 9.75
    readonly property real rowH: 32
    readonly property real head: 56

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/house/palette.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: look
            property string font: "SF Mono"
            property real size: 12.75
            property int radius: 12
            property string ground: "#FFFFFF0F"
            property string edge: "#FFFFFF33"
            property string body: "#FFFFFFE0"
            property string pick: "#7DE8DA"
            property string dim: "#FFFFFF80"
            property string band: "#3CF2F238"
            property string harm: "#FF6EC7"
            property string warn: "#C58AB5"
        }
    }
}
