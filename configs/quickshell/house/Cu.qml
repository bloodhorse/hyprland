import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes

Scope {
    id: root
    property int home: 1
    property string source: "https://cu.x/panel.json"
    property int stale: 360
    property bool here: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === home
    property var d: null
    property bool answered: false

    function take(text) {
        try {
            const o = JSON.parse(text)
            if (o.session === undefined || o.speed === undefined) throw 0
            d = o
            answered = true
        } catch (e) {
            answered = false
        }
    }

    function spaced(n) {
        return Math.round(n).toString().replace(/\B(?=(\d{3})+$)/g, " ")
    }

    function left(ts, now) {
        const s = Math.floor(ts - now)
        if (s <= 0) return "now"
        const days = Math.floor(s / 86400)
        const h = Math.floor(s % 86400 / 3600)
        const m = Math.floor(s % 3600 / 60)
        if (days) return days + "d" + h + "h"
        return h ? h + "h" + String(m).padStart(2, "0") : m + "m"
    }

    property bool sick: !answered || d === null || d.source === "down" || d.cache_age === null || d.cache_age > stale
    property string healthText: {
        if (!answered) return d === null ? "no answer from the mac" : "mac asleep?"
        if (d.source === "down") return "usage fetch is down"
        if (d.cache_age === null) return "no cache"
        if (d.cache_age > stale) return "stale · " + Math.floor(d.cache_age / 60) + "m"
        return ""
    }

    Process {
        id: fetch
        command: ["curl", "-sk", "-m", "4", root.source]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
    }

    Timer {
        interval: 5000
        running: root.here
        repeat: true
        triggeredOnStart: true
        onTriggered: fetch.running = true
    }

    component Meter: Item {
        id: meter
        property string title
        property var w: null
        property bool paced: false
        property real now: 0
        property bool hot: w !== null && (paced ? w.pct > w.norm : w.pct >= 90)
        property color tone: hot ? (paced ? Theme.warn : Theme.harm) : Theme.pick

        visible: w !== null && w !== undefined
        width: parent.width
        height: 38

        Text {
            id: label
            text: meter.title
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 10
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
        }

        Text {
            anchors.right: parent.right
            anchors.baseline: label.baseline
            text: meter.visible && meter.w.resets_at ? root.left(meter.w.resets_at, meter.now) : ""
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 10
        }

        Text {
            id: pct
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -2
            width: 44
            text: meter.visible ? meter.w.pct + "%" : ""
            color: meter.tone
            font.family: Theme.mono
            font.pixelSize: 16
            font.bold: true
        }

        Rectangle {
            anchors.left: pct.right
            anchors.right: parent.right
            anchors.verticalCenter: pct.verticalCenter
            height: 6
            radius: 3
            color: Theme.band

            Rectangle {
                height: parent.height
                radius: 3
                color: meter.tone
                width: meter.visible ? parent.width * Math.min(meter.w.pct, 100) / 100 : 0

                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                visible: meter.paced
                y: -3
                width: 2
                height: parent.height + 6
                radius: 1
                color: Theme.body
                x: meter.visible && meter.paced ? parent.width * Math.min(meter.w.norm, 100) / 100 - 1 : 0
            }
        }
    }

    LazyLoader {
        active: root.here

        PanelWindow {
            implicitWidth: card.width
            implicitHeight: card.height
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors.left: true
            anchors.bottom: true
            margins.left: 14
            margins.bottom: 14

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "cu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: card
                width: 420
                height: 160
                radius: Theme.radius
                color: Theme.ground
                border.color: Theme.edge
                border.width: 1

                Item {
                    id: gauge
                    x: 14
                    y: 12
                    width: 156
                    height: 136

                    property real cx: width / 2
                    property real cy: 66
                    property real r: 58
                    property real thick: 7
                    property real max: root.d !== null ? root.d.gauge_max : 6000
                    property real budget: root.d !== null && root.d.budget !== null ? Math.min(root.d.budget, max) : max
                    property real speed: root.d !== null ? root.d.speed : 0
                    property bool over: root.d !== null && root.d.budget !== null && speed > root.d.budget
                    property real shown: Math.min(Math.max(speed, 0), max)
                    property real split: 240 * budget / max

                    Behavior on shown { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: Qt.alpha(Theme.pick, 0.2)
                            strokeWidth: gauge.thick
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap

                            PathAngleArc {
                                centerX: gauge.cx
                                centerY: gauge.cy
                                radiusX: gauge.r
                                radiusY: gauge.r
                                startAngle: 150
                                sweepAngle: gauge.split < 240 ? gauge.split - 1.5 : 240
                            }
                        }

                        ShapePath {
                            strokeColor: gauge.split < 240 ? Qt.alpha(Theme.harm, 0.2) : "transparent"
                            strokeWidth: gauge.thick
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap

                            PathAngleArc {
                                centerX: gauge.cx
                                centerY: gauge.cy
                                radiusX: gauge.r
                                radiusY: gauge.r
                                startAngle: 150 + gauge.split + 1.5
                                sweepAngle: Math.max(240 - gauge.split - 1.5, 0.01)
                            }
                        }

                        ShapePath {
                            strokeColor: gauge.over ? Theme.harm : Theme.pick
                            strokeWidth: gauge.thick
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap

                            PathAngleArc {
                                centerX: gauge.cx
                                centerY: gauge.cy
                                radiusX: gauge.r
                                radiusY: gauge.r
                                startAngle: 150
                                sweepAngle: Math.max(240 * gauge.shown / gauge.max, 1)
                            }
                        }
                    }

                    Rectangle {
                        visible: gauge.split < 240
                        x: gauge.cx + gauge.r - 7
                        y: gauge.cy - 1
                        width: 14
                        height: 2
                        color: Theme.body
                        antialiasing: true
                        transform: Rotation {
                            origin.x: -(gauge.r - 7)
                            origin.y: 1
                            angle: 150 + gauge.split
                        }
                    }

                    Rectangle {
                        x: gauge.cx - 8
                        y: gauge.cy - 1.5
                        width: gauge.r - 10
                        height: 3
                        radius: 1.5
                        color: Theme.body
                        antialiasing: true
                        transform: Rotation {
                            origin.x: 8
                            origin.y: 1.5
                            angle: 150 + 240 * gauge.shown / gauge.max
                        }
                    }

                    Rectangle {
                        x: gauge.cx - 5
                        y: gauge.cy - 5
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.body
                    }

                    Text {
                        id: reading
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 92
                        text: root.d !== null ? root.spaced(gauge.speed) : "–"
                        color: gauge.over ? Theme.harm : Theme.pick
                        font.family: Theme.mono
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: reading.bottom
                        anchors.topMargin: -1
                        text: root.sick ? root.healthText : "tok / min"
                        color: root.sick ? Theme.harm : Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                }

                Column {
                    x: 196
                    width: card.width - x - 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9

                    Meter {
                        title: "session"
                        w: root.d !== null ? root.d.session : null
                        now: root.d !== null ? root.d.ts : 0
                    }

                    Meter {
                        title: "week"
                        paced: true
                        w: root.d !== null ? root.d.week : null
                        now: root.d !== null ? root.d.ts : 0
                    }

                    Meter {
                        title: "fable week"
                        paced: true
                        w: root.d !== null ? root.d.fable : null
                        now: root.d !== null ? root.d.ts : 0
                    }
                }
            }
        }
    }
}
