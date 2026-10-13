import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root
    property string kind: "brightness"
    property string title: "Display"
    property real value: 0
    property bool shown: false

    IpcHandler {
        target: "osd"
        function pop(kind: string, title: string, value: real): void {
            root.kind = kind
            root.title = title
            root.value = Math.max(0, Math.min(1, value))
            root.shown = true
            hide.restart()
        }
    }

    Timer {
        id: hide
        interval: 1500
        onTriggered: root.shown = false
    }

    component Glyph: Canvas {
        property real k: 1
        property bool muted: false
        width: 22
        height: 22
        onKChanged: requestPaint()
        onMutedChanged: requestPaint()
        Connections {
            target: root
            function onKindChanged() { requestPaint() }
        }
        onPaint: {
            var c = getContext("2d")
            c.reset()
            c.strokeStyle = c.fillStyle = Qt.rgba(1, 1, 1, 0.92)
            c.lineWidth = 1.6
            c.lineCap = "round"
            var m = width / 2
            if (root.kind === "volume") {
                c.beginPath()
                c.moveTo(m - 8, m - 3); c.lineTo(m - 4, m - 3); c.lineTo(m, m - 7)
                c.lineTo(m, m + 7); c.lineTo(m - 4, m + 3); c.lineTo(m - 8, m + 3)
                c.closePath(); c.fill()
                if (muted) {
                    c.beginPath(); c.moveTo(m + 3, m - 3); c.lineTo(m + 9, m + 3); c.stroke()
                    c.beginPath(); c.moveTo(m + 9, m - 3); c.lineTo(m + 3, m + 3); c.stroke()
                } else {
                    for (var i = 1; i <= Math.round(1 + k); i++) {
                        c.beginPath(); c.arc(m, m, 3 + i * 3, -0.7, 0.7); c.stroke()
                    }
                }
            } else {
                var r = 3 + k * 1.6
                c.beginPath(); c.arc(m, m, r, 0, Math.PI * 2); c.fill()
                for (var j = 0; j < 8; j++) {
                    var a = j * Math.PI / 4
                    c.beginPath()
                    c.moveTo(m + Math.cos(a) * (r + 2.2), m + Math.sin(a) * (r + 2.2))
                    c.lineTo(m + Math.cos(a) * (r + 3.4 + k), m + Math.sin(a) * (r + 3.4 + k))
                    c.stroke()
                }
            }
        }
    }

    PanelWindow {
        visible: root.shown || box.opacity > 0.01
        anchors { top: true; right: true }
        margins { top: 30; right: 38 }
        implicitWidth: 340
        implicitHeight: 74
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "osd"
        mask: Region {}

        Rectangle {
            id: box
            anchors.fill: parent
            radius: 24
            color: Qt.rgba(118 / 255, 104 / 255, 150 / 255, 0.42)
            border.color: Qt.rgba(1, 1, 1, 0.22)
            border.width: 1
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            Row {
                x: 20
                y: 12
                spacing: 10
                Text {
                    text: root.title
                    color: "white"
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: pct.implicitWidth + 14
                    height: 17
                    radius: 9
                    color: Qt.rgba(1, 1, 1, 0.82)
                    Text {
                        id: pct
                        anchors.centerIn: parent
                        text: root.kind === "mute" ? "muted" : Math.round(root.value * 100) + "%"
                        color: "#2a2338"
                        font.family: "Inter"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }

            Glyph { x: 16; y: 40; k: 0; muted: root.kind === "mute" }
            Glyph { x: parent.width - 38; y: 40; k: 1 }

            Rectangle {
                id: trough
                x: 44
                y: 49
                width: parent.width - 88
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.22)
                Rectangle {
                    width: parent.width * root.value
                    height: parent.height
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.95)
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }
            Row {
                x: trough.x + 6
                y: 58
                spacing: (trough.width - 12 - 16 * 2) / 15
                Repeater {
                    model: 16
                    Rectangle { width: 2; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.3) }
                }
            }
        }
    }
}
