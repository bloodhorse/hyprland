import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: pill
    property var points: []
    property bool shown: false
    property bool dim: false

    function feed(line) {
        if (line.startsWith("rec")) {
            var p = line.split(" ")
            p.shift()
            points = p.map(Number)
            dim = false
            shown = true
        } else if (line === "think") {
            dim = true
        } else {
            shown = false
        }
        wave.requestPaint()
    }

    Socket {
        id: sock
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/dictate.sock"
        connected: true
        onConnectedChanged: {
            if (connected) {
                write("watch\n")
                flush()
            } else {
                pill.shown = false
            }
        }
        parser: SplitParser {
            onRead: line => pill.feed(line)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: if (!sock.connected) sock.connected = true
    }

    PanelWindow {
        visible: pill.shown || glass.opacity > 0.01
        anchors { bottom: true }
        margins { bottom: 48 }
        implicitWidth: 140
        implicitHeight: 44
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "pill"
        mask: Region {}

        Rectangle {
            id: glass
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(0.6, 1, 1, 0.07)
            border.color: Qt.rgba(1, 1, 1, 0.16)
            border.width: 1
            opacity: pill.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: pill.shown ? 120 : 250 } }

            Canvas {
                id: wave
                x: 16
                y: 8
                width: parent.width - 32
                height: parent.height - 16
                onPaint: {
                    var c = getContext("2d")
                    c.reset()
                    var w = width, h = height, mid = h / 2
                    var pts = pill.points
                    var a = pill.dim ? 0.35 : 1
                    c.lineJoin = "round"
                    c.lineCap = "round"
                    var strokes = [[6.0, 0.10], [3.0, 0.22], [0.8, 1.0]]
                    for (var s = 0; s < 3; s++) {
                        c.beginPath()
                        if (pts.length < 2) {
                            c.moveTo(0, mid)
                            c.lineTo(w, mid)
                        } else {
                            for (var i = 0; i < pts.length; i++) {
                                var x = i / (pts.length - 1) * w
                                var y = mid - pts[i] * (h / 2 - 4)
                                if (i === 0) c.moveTo(x, y); else c.lineTo(x, y)
                            }
                        }
                        c.lineWidth = strokes[s][0]
                        c.strokeStyle = Qt.rgba(0.2375, 0.95, 0.95, strokes[s][1] * a)
                        c.stroke()
                    }
                }
            }
        }
    }
}
