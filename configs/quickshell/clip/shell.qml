import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root
    property var clips: []
    property var shown: []
    property int pick: 0
    property bool open: false
    property bool editing: false
    property string home: Quickshell.env("HOME")
    property string tool: home + "/.local/bin/clip"
    property string scratch: Quickshell.env("XDG_RUNTIME_DIR") + "/clip-edit"

    readonly property color ground: Qt.rgba(0.055, 0.09, 0.098, 0.77)
    readonly property color edge: Qt.rgba(1, 1, 1, 0.133)
    readonly property color body: "#D5ECE9"
    readonly property color cyan: "#7DE8DA"
    readonly property color dim: "#4C8581"
    readonly property color band: Qt.rgba(1, 1, 1, 0.086)
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property real rowH: 36.6
    readonly property int rows: 7
    readonly property int fit: Math.min(48, Math.floor((384 - 62 - 24 - 7 * smallM.advanceWidth) / monoM.advanceWidth))

    TextMetrics { id: monoM; font.family: root.mono; font.pointSize: 13; text: "M" }
    TextMetrics { id: smallM; font.family: root.mono; font.pointSize: 10; text: "M" }

    function parse(text) {
        var out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (!lines[i]) continue
            try {
                var c = JSON.parse(lines[i])
                out.push({ t: c.t, s: c.s, n: out.length })
            } catch (e) {}
        }
        clips = out
        filter()
    }

    function filter() {
        var q = input.text.toLowerCase()
        var out = []
        for (var i = 0; i < clips.length; i++)
            if (!q || clips[i].s.toLowerCase().indexOf(q) >= 0) out.push(clips[i])
        shown = out
        pick = 0
    }

    function two(n) { return (n < 10 ? "0" : "") + n }

    function clock(t) {
        if (!t) return ""
        var d = new Date(t * 1000)
        return two(d.getHours()) + ":" + two(d.getMinutes())
    }

    function tail(s, n) {
        if (s.length <= n) return s
        var cut = s.slice(s.length - (n - 1))
        var at = cut.indexOf("/")
        return "…" + (at >= 0 ? cut.slice(at) : cut)
    }

    function pathLabel(text) {
        var t = text.trim()
        if (!(t.charAt(0) === "/" || t.slice(0, 2) === "~/") || /[\n\r]/.test(t)) return ""
        var name = t.slice(t.lastIndexOf("/") + 1)
        var ext = name.indexOf(".") >= 0 ? name.slice(name.lastIndexOf(".") + 1).toLowerCase() : ""
        if (["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff"].indexOf(ext) >= 0) {
            var m = name.split(/[^0-9]+/).filter(function (x) { return x.length > 0 })
            if (m.length >= 4 && m[3].length === 6 && name.indexOf("hyprshot") >= 0)
                m = [m[0], m[1], m[2], m[3].slice(0, 2), m[3].slice(2, 4), m[3].slice(4, 6)]
            if ((name.indexOf("Screenshot ") === 0 || name.indexOf("hyprshot") >= 0) && m.length >= 6) {
                var day = new Date(parseInt(m[0]), parseInt(m[1]) - 1, parseInt(m[2]))
                var now = new Date()
                if (day.toDateString() === now.toDateString()) return "image " + m[3] + "." + m[4] + "." + m[5]
                var months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
                return "image " + day.getDate() + " " + months[day.getMonth()] + " " + m[3] + "." + m[4]
            }
            return "image " + tail(name, fit - 6)
        }
        if (/\s/.test(t)) return ""
        return tail(t, fit)
    }

    function label(text) {
        var p = pathLabel(text)
        if (p) return p
        var lines = text.split(/[\n\r]+/)
        var first = ""
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].split(/\s+/).filter(function (x) { return x.length > 0 }).join(" ")
            if (l) { first = l; break }
        }
        return first.length > fit ? first.slice(0, fit - 1).trim() + "…" : first
    }

    function show() {
        input.text = ""
        store.reload()
        editing = false
        open = true
        input.forceActiveFocus()
    }

    function hide() {
        open = false
        editing = false
    }

    function put(how) {
        if (pick < 0 || pick >= shown.length) return
        var c = shown[pick]
        hide()
        Quickshell.execDetached([tool, "put", String(c.t), String(c.n), how])
    }

    function edit() {
        if (pick < 0 || pick >= shown.length) return
        editText.text = shown[pick].s
        editText.cursorPosition = 0
        editView.contentY = 0
        open = false
        editing = true
        editText.forceActiveFocus()
    }

    FileView {
        id: store
        path: root.home + "/.local/state/clip/clips.jsonl"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parse(text())
    }

    FileView {
        id: scratchFile
        path: root.scratch
        printErrors: false
        onSaved: {
            Quickshell.execDetached([root.tool, "putfile", root.scratch])
            root.hide()
        }
    }

    IpcHandler {
        target: "clip"
        function toggle(): void { if (root.open || root.editing) root.hide(); else root.show() }
    }

    PanelWindow {
        visible: root.open
        implicitWidth: 384
        implicitHeight: 312
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "launcher"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: root.ground
            border.color: root.edge
            border.width: 1
            clip: true

            Text {
                x: 30
                y: 33 - height / 2
                text: ">"
                color: root.dim
                font.family: root.mono
                font.pointSize: 13
            }

            Text {
                x: 62
                y: 33 - height / 2
                visible: input.text.length === 0
                text: "clip"
                color: root.dim
                font.family: root.mono
                font.pointSize: 13
            }

            TextInput {
                id: input
                x: 62
                y: 33 - height / 2
                width: parent.width - 62 - 24
                clip: true
                focus: true
                color: root.body
                font.family: root.mono
                font.pointSize: 13
                cursorDelegate: Rectangle { width: 2; color: root.cyan; visible: input.cursorVisible }
                onTextChanged: root.filter()

                Keys.onPressed: event => {
                    var ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Escape) {
                        root.hide()
                    } else if (event.key === Qt.Key_Down) {
                        if (root.pick < root.shown.length - 1) root.pick++
                    } else if (event.key === Qt.Key_Up) {
                        if (root.pick > 0) root.pick--
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.put(ctrl ? "copy" : "paste")
                    } else if (event.key === Qt.Key_Tab) {
                        root.edit()
                    } else {
                        return
                    }
                    event.accepted = true
                }
            }

            ListView {
                id: list
                x: 0
                y: 69 - root.rowH / 2
                width: parent.width
                height: root.rows * root.rowH
                clip: true
                interactive: false
                model: root.shown
                currentIndex: root.pick
                highlightMoveDuration: 0
                highlightFollowsCurrentItem: true
                highlight: Item {
                    Rectangle {
                        x: 5
                        y: (root.rowH - 35.4) / 2
                        width: list.width - 10
                        height: 35.4
                        color: root.band
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: root.rowH

                    Text {
                        x: 62
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.label(row.modelData.s)
                        color: row.index === root.pick ? root.cyan : root.body
                        font.family: root.mono
                        font.pointSize: 13
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.clock(row.modelData.t)
                        color: root.dim
                        font.family: root.mono
                        font.pointSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.pick = row.index
                            root.put("paste")
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        visible: root.editing
        implicitWidth: 640
        implicitHeight: 420
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "launcher"
        WlrLayershell.keyboardFocus: root.editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: root.ground
            border.color: root.edge
            border.width: 1

            Flickable {
                id: editView
                anchors.fill: parent
                anchors.margins: 20
                clip: true
                contentWidth: width
                contentHeight: editText.implicitHeight

                function follow() {
                    var r = editText.cursorRectangle
                    if (r.y < contentY) contentY = r.y
                    else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height
                }

                TextEdit {
                    id: editText
                    width: editView.width
                    color: root.body
                    selectionColor: Qt.rgba(1, 1, 1, 0.18)
                    selectedTextColor: root.cyan
                    font.family: root.mono
                    font.pointSize: 13
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    cursorDelegate: Rectangle { width: 2; color: root.cyan; visible: editText.cursorVisible }
                    onCursorRectangleChanged: editView.follow()

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.hide()
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                   && (event.modifiers & Qt.ControlModifier)) {
                            scratchFile.setText(editText.text)
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }
}
