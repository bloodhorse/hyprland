import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root
    property real value: 0
    property real drawn: 0
    property bool muted: false
    property bool shown: false

    Behavior on drawn { NumberAnimation { duration: 90 } }
    onDrawnChanged: line.requestPaint()
    onMutedChanged: line.requestPaint()

    IpcHandler {
        target: "osd"
        function pop(kind: string, title: string, value: real): void {
            root.muted = kind === "mute"
            root.value = Math.max(0, Math.min(1, value))
            root.drawn = root.value
            root.shown = true
            hide.restart()
        }
    }

    Pill {}

    Timer {
        id: hide
        interval: 1200
        onTriggered: root.shown = false
    }

    PanelWindow {
        visible: root.shown || glass.opacity > 0.01
        anchors { bottom: true }
        margins { bottom: 48 }
        implicitWidth: 190
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
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.shown ? 120 : 250 } }

            Canvas {
                id: line
                x: 16
                y: 8
                width: parent.width - 32
                height: parent.height - 16
                onPaint: {
                    var c = getContext("2d")
                    c.reset()
                    var w = width, mid = height / 2
                    var a = root.muted ? 0.35 : 1
                    c.lineCap = "round"
                    c.lineJoin = "round"
                    c.beginPath()
                    c.moveTo(0, mid)
                    c.lineTo(w, mid)
                    c.lineWidth = 0.8
                    c.strokeStyle = Qt.rgba(0.2375, 0.95, 0.95, 0.14)
                    c.stroke()
                    var end = w * root.drawn
                    if (end < 1)
                        return
                    var tail = Math.min(22, end)
                    var strokes = [[6.0, 0.10], [3.0, 0.22], [0.8, 1.0]]
                    for (var s = 0; s < 3; s++) {
                        var g = c.createLinearGradient(0, 0, end, 0)
                        var col = Qt.rgba(0.2375, 0.95, 0.95, strokes[s][1] * a)
                        g.addColorStop(0, col)
                        g.addColorStop(Math.max(0, (end - tail) / end), col)
                        g.addColorStop(1, Qt.rgba(0.2375, 0.95, 0.95, 0))
                        c.beginPath()
                        c.moveTo(0, mid)
                        c.lineTo(end, mid)
                        c.lineWidth = strokes[s][0]
                        c.strokeStyle = g
                        c.stroke()
                    }
                }
            }
        }
    }
}
