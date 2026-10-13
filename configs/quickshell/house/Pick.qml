import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

Scope {
    id: root
    property var wins: []
    property int pick: 0
    property bool open: false
    property bool harm: false
    readonly property real rowH: 36.6
    readonly property color mark: harm ? Theme.harm : Theme.pick
    readonly property var shifted: [Qt.Key_Exclam, Qt.Key_At, Qt.Key_NumberSign, Qt.Key_Dollar, Qt.Key_Percent,
                                    Qt.Key_AsciiCircum, Qt.Key_Ampersand, Qt.Key_Asterisk, Qt.Key_ParenLeft]
    readonly property int nameCols: {
        var n = 0
        for (var i = 0; i < wins.length; i++) n = Math.max(n, wins[i].class.length)
        return Math.min(n, 18) + 2
    }

    TextMetrics { id: monoM; font.family: Theme.mono; font.pointSize: Theme.size; text: "M" }

    function fill(text) {
        var all = []
        try { all = JSON.parse(text) } catch (e) {}
        var out = all.filter(c => c.mapped !== false && c.class && c.class !== "dropterm")
        out.sort((a, b) => a.focusHistoryID - b.focusHistoryID)
        if (!harm && out.length > 1 && out[0].focusHistoryID === 0) out.push(out.shift())
        wins = out.slice(0, 9)
        if (!wins.length) {
            hide()
            return
        }
        if (pick >= wins.length) pick = wins.length - 1
        if (!open) {
            open = true
            Hyprland.dispatch("submap picker")
        }
    }

    function call(kill) {
        if (open && harm === kill) {
            step(1)
            return
        }
        harm = kill
        pick = 0
        fetch.running = true
    }

    function hide() {
        if (!open) return
        open = false
        Hyprland.dispatch("submap reset")
    }

    function step(by) {
        if (wins.length) pick = (pick + by + wins.length) % wins.length
    }

    function act(i) {
        if (i < 0 || i >= wins.length) return
        var w = wins[i]
        if (harm) {
            Quickshell.execDetached(["kill", "-KILL", String(w.pid)])
            return
        }
        hide()
        Hyprland.dispatch("focuswindow address:" + w.address)
    }

    function shut(i) {
        if (i < 0 || i >= wins.length) return
        Hyprland.dispatch("closewindow address:" + wins[i].address)
    }

    Process {
        id: fetch
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector { onStreamFinished: root.fill(text) }
    }

    Timer {
        id: again
        interval: 60
        onTriggered: fetch.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.open && event.name === "closewindow") again.restart()
        }
    }

    IpcHandler {
        target: "pick"
        function windows(): void { root.call(false) }
        function force(): void { root.call(true) }
        function hide(): void { root.hide() }
    }

    PanelWindow {
        visible: root.open
        implicitWidth: 600
        implicitHeight: 69 - root.rowH / 2 + Math.max(1, root.wins.length) * root.rowH + 8
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "launcher"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.ground
            border.color: Theme.edge
            border.width: 1
            clip: true
            focus: true

            Keys.onPressed: event => {
                var ctrl = event.modifiers & Qt.ControlModifier
                var digit = event.key >= Qt.Key_1 && event.key <= Qt.Key_9 ? event.key - Qt.Key_1 : root.shifted.indexOf(event.key)
                if (digit >= 0) {
                    if (ctrl) root.shut(digit)
                    else root.act(digit)
                } else if (event.key === Qt.Key_Escape) {
                    root.hide()
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                    root.step(1)
                } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                    root.step(-1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.act(root.pick)
                }
                event.accepted = true
            }

            Text {
                x: 30
                y: 33 - height / 2
                text: ">"
                color: Theme.dim
                font.family: Theme.mono
                font.pointSize: Theme.size
            }

            Text {
                x: 62
                y: 33 - height / 2
                text: root.harm ? "force quit" : "windows"
                color: root.harm ? Theme.harm : Theme.dim
                font.family: Theme.mono
                font.pointSize: Theme.size
            }

            Rectangle {
                x: 5
                y: 69 - root.rowH / 2 + root.pick * root.rowH + (root.rowH - 35.4) / 2
                width: parent.width - 10
                height: 35.4
                color: Theme.band
            }

            Repeater {
                model: root.wins

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    x: 0
                    y: 69 - root.rowH / 2 + index * root.rowH
                    width: parent.width
                    height: root.rowH

                    Text {
                        x: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.index + 1
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pointSize: Theme.size
                    }

                    Text {
                        id: name
                        x: 62
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.nameCols * monoM.advanceWidth
                        elide: Text.ElideRight
                        text: row.modelData.class
                        color: row.index === root.pick ? root.mark : Theme.body
                        font.family: Theme.mono
                        font.pointSize: Theme.size
                    }

                    Text {
                        anchors.left: name.right
                        anchors.right: space.left
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.title
                        color: Theme.body
                        opacity: row.index === root.pick ? 0.85 : 0.5
                        font.family: Theme.mono
                        font.pointSize: Theme.size
                    }

                    Text {
                        id: space
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.workspace.name
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pointSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.act(row.index)
                    }
                }
            }
        }
    }
}
