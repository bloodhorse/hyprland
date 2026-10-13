import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: root
    property var shown: []
    property int pick: 0
    property bool open: false
    property string now: ""
    readonly property int rows: 5

    function score(q, s) {
        var hay = s.toLowerCase(), needle = q.toLowerCase()
        var i = 0, total = 0, streak = 0
        for (var k = 0; k < hay.length && i < needle.length; k++) {
            if (hay[k] === needle[i]) {
                streak++
                total += 1 + streak * 2 + (k === 0 || hay[k - 1] === " " || hay[k - 1] === "." ? 6 : 0)
                i++
            } else {
                streak = 0
            }
        }
        return i === needle.length ? total : 0
    }

    function apps() {
        var seen = {}
        var out = []
        var all = DesktopEntries.applications.values
        for (var i = 0; i < all.length; i++) {
            var a = all[i]
            if (a.noDisplay || !a.name || seen[a.name]) continue
            seen[a.name] = true
            out.push(a)
        }
        out.sort((a, b) => a.name.localeCompare(b.name))
        return out
    }

    function filter() {
        var q = input.text
        var all = apps()
        var out = []
        if (!q) {
            out = all.slice(0, rows).map(a => ({ title: a.name, detail: "", app: a }))
        } else {
            for (var i = 0; i < all.length; i++) {
                var a = all[i]
                var n = Math.max(score(q, a.name), score(q, a.name + " " + (a.genericName || "")) - 1)
                if (n > 0) out.push({ title: a.name, detail: "", app: a, n: n })
            }
            out.sort((a, b) => a.n !== b.n ? b.n - a.n : a.title.length - b.title.length)
            out = out.slice(0, rows)
        }
        shown = out
        pick = 0
    }

    function two(n) { return (n < 10 ? "0" : "") + n }

    function show() {
        var d = new Date()
        now = two(d.getHours()) + ":" + two(d.getMinutes())
        input.text = ""
        filter()
        open = true
        input.forceActiveFocus()
    }

    function hide() {
        open = false
    }

    function go() {
        if (pick < 0 || pick >= shown.length) return
        var app = shown[pick].app
        hide()
        var names = [app.startupClass, app.id].filter(x => x).map(x => x.toLowerCase())
        var tops = ToplevelManager.toplevels.values
        for (var i = 0; i < tops.length; i++) {
            if (names.indexOf((tops[i].appId || "").toLowerCase()) >= 0) {
                tops[i].activate()
                return
            }
        }
        app.execute()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.filter() }
    }

    Component.onCompleted: filter()

    IpcHandler {
        target: "launch"
        function toggle(): void { if (root.open) root.hide(); else root.show() }
    }

    PanelWindow {
        visible: root.open
        implicitWidth: 384
        implicitHeight: Theme.head + root.rows * Theme.rowH + 6
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

            Text {
                x: 30
                y: 33 - height / 2
                text: ">"
                color: Theme.dim
                font.family: Theme.mono
                font.pointSize: Theme.size
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 24
                y: 33 - height / 2
                text: root.now
                color: Theme.dim
                font.family: Theme.mono
                font.pointSize: Theme.small
            }

            TextInput {
                id: input
                x: 62
                y: 33 - height / 2
                width: parent.width - 62 - 80
                clip: true
                focus: true
                color: Theme.body
                font.family: Theme.mono
                font.pointSize: Theme.size
                cursorDelegate: Rectangle { width: 2; color: Theme.pick; visible: input.cursorVisible }
                onTextChanged: root.filter()

                Keys.onPressed: event => {
                    var ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Escape) {
                        root.hide()
                    } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                        if (root.pick < root.shown.length - 1) root.pick++
                    } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                        if (root.pick > 0) root.pick--
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.go()
                    } else {
                        return
                    }
                    event.accepted = true
                }
            }

            Rectangle {
                visible: root.shown.length > 0
                x: 5
                y: Theme.head + root.pick * Theme.rowH + (Theme.rowH - 35.4) / 2
                width: parent.width - 10
                height: 35.4
                color: Theme.band
            }

            Repeater {
                model: root.shown

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    y: Theme.head + index * Theme.rowH
                    width: parent.width
                    height: Theme.rowH

                    Text {
                        id: title
                        x: 62
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - 62 - 24)
                        elide: Text.ElideRight
                        text: row.modelData.title
                        color: row.index === root.pick ? Theme.pick : Theme.body
                        font.family: Theme.mono
                        font.pointSize: Theme.size
                    }

                    Text {
                        anchors.left: title.right
                        anchors.leftMargin: 14
                        anchors.baseline: title.baseline
                        text: row.modelData.detail
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pointSize: Theme.small
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.pick = row.index
                            root.go()
                        }
                    }
                }
            }
        }
    }
}
