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
    property var commands: Object.create(null)
    property string mode: ""
    property var list: []
    property int first: 0
    readonly property int rows: 5
    readonly property int fit: Math.floor((384 - 31 - 14 - 14 - 5 * smallM.advanceWidth) / monoM.advanceWidth)
    readonly property string home: Quickshell.env("HOME")
    readonly property string dictated: home + "/tower/forge/hypragain/dictate/dictated.py"
    readonly property var ownRows: [{ title: "micinput", detail: "dictation", own: "inputs" },
                                    { title: "history", detail: "dictation", own: "history" }]

    TextMetrics { id: monoM; font.family: Theme.mono; font.pointSize: Theme.size; text: "M" }
    TextMetrics { id: smallM; font.family: Theme.mono; font.pointSize: Theme.small; text: "M" }

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
        var all = mode ? list : apps().map(a => ({ title: a.name, detail: "", hay: a.genericName || "", app: a })).concat(ownRows)
        var out = []
        if (!q) {
            out = mode ? all : all.slice(0, rows)
        } else {
            for (var i = 0; i < all.length; i++) {
                var r = all[i]
                var n = Math.max(score(q, r.title), score(q, r.title + " " + (r.hay || r.detail)) - 1)
                if (n > 0) out.push(Object.assign({ n: n }, r))
            }
            out.sort((a, b) => a.n !== b.n ? b.n - a.n : a.title.length - b.title.length)
            if (!mode) out = out.slice(0, rows)
            var word = q.trim().split(/\s+/)[0]
            if (!mode && commands[word]) {
                var run = { title: q, detail: "run", run: q }
                out = q.trim().indexOf(" ") >= 0 || !out.length ? [run].concat(out.slice(0, rows - 1)) : out.slice(0, rows - 1).concat([run])
            }
        }
        shown = out
        pick = 0
        first = 0
    }

    function swap(to) {
        mode = to
        list = []
        input.text = ""
        if (to === "inputs") inputs.running = true
        else takes(history.text())
        filter()
    }

    function takes(text) {
        var lines = text.split("\n")
        var out = []
        for (var i = lines.length - 1; i >= 0 && out.length < 60; i--) {
            var f = lines[i].split("\t")
            var said = f.slice(2).join("\t").trim()
            if (f.length < 3 || !said) continue
            out.push({ title: said.length > fit ? said.slice(0, fit - 1).trim() + "…" : said, detail: f[0].slice(11, 16), hay: said, take: said })
        }
        list = out
        filter()
    }

    function two(n) { return (n < 10 ? "0" : "") + n }

    function show() {
        var d = new Date()
        now = two(d.getHours()) + ":" + two(d.getMinutes())
        mode = ""
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
        var row = shown[pick]
        if (row.own) {
            swap(row.own)
            return
        }
        hide()
        if (row.source) {
            Quickshell.execDetached([dictated, "input", row.source])
            return
        }
        if (row.take) {
            Quickshell.execDetached(["wl-copy", "--", row.take])
            return
        }
        if (row.run) {
            Quickshell.execDetached(["sh", "-c", 'zsh -ic "$1" > /tmp/launcher-run.log 2>&1', "sh", row.run])
            return
        }
        var app = row.app
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

    onPickChanged: {
        if (pick < first) first = pick
        else if (pick >= first + rows) first = pick - rows + 1
    }

    Process {
        id: inputs
        command: [root.dictated, "inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split("\t")
                    if (f.length === 3) out.push({ title: f[1] + (f[2] === "1" ? "  ✓" : ""), detail: "", source: f[0] })
                }
                root.list = out
                root.filter()
            }
        }
    }

    FileView {
        id: history
        path: root.home + "/.local/state/dictate/dictations"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: if (root.mode === "history") root.takes(text())
    }

    Component.onCompleted: {
        filter()
        names.running = true
    }

    Process {
        id: names
        command: ["zsh", "-ic", "print -rl -- ${(k)commands} ${(k)functions} ${(k)aliases}"]
        stdout: StdioCollector {
            onStreamFinished: {
                var set = Object.create(null)
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) if (lines[i]) set[lines[i]] = true
                root.commands = set
            }
        }
    }

    IpcHandler {
        target: "launch"
        function toggle(): void { if (root.open) root.hide(); else root.show() }
        function reload(): void { names.running = true }
    }

    PanelWindow {
        visible: root.open
        implicitWidth: 384
        implicitHeight: Theme.head + root.rows * Theme.rowH + 10
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
                x: 22
                y: 31 - height / 2
                text: ">"
                color: Theme.dim
                font.family: Theme.mono
                font.pointSize: Theme.size
            }

            Text {
                x: 46
                y: 31 - height / 2
                visible: input.text.length === 0 && root.mode !== ""
                text: root.mode === "inputs" ? "input" : root.mode
                color: Theme.dim
                font.family: Theme.mono
                font.pointSize: Theme.size
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 9
                y: 31 - height / 2
                text: root.now
                color: Theme.dim
                font.family: Theme.mono
                font.pointSize: Theme.small
            }

            TextInput {
                id: input
                x: 46
                y: 31 - height / 2
                width: parent.width - 46 - 69
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
                x: 0
                y: Theme.head + (root.pick - root.first) * Theme.rowH
                width: parent.width
                height: Theme.rowH
                color: Theme.band
            }

            Repeater {
                model: root.shown.slice(root.first, root.first + root.rows)

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    y: Theme.head + index * Theme.rowH
                    width: parent.width
                    height: Theme.rowH

                    Text {
                        id: title
                        x: 31
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - 31 - 14)
                        elide: Text.ElideRight
                        text: row.modelData.title
                        color: Theme.body
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
                            root.pick = row.index + root.first
                            root.go()
                        }
                    }
                }
            }
        }
    }
}
