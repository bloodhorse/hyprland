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

    function brief(n) {
        if (n >= 1e9) return (n / 1e9).toFixed(2) + "B"
        if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e8 ? 0 : n >= 1e7 ? 1 : 2) + "M"
        if (n >= 1e3) return (n / 1e3).toFixed(n >= 1e5 ? 0 : 1) + "k"
        return String(Math.round(n))
    }

    function left(ts, now) {
        const s = Math.floor(ts - now)
        if (s <= 0) return "resets now"
        const days = Math.floor(s / 86400)
        const h = Math.floor(s % 86400 / 3600)
        const m = Math.floor(s % 3600 / 60)
        if (days) return "resets in " + days + "d" + h + "h"
        return h ? "resets in " + h + "h" + String(m).padStart(2, "0") + "m" : "resets in " + m + "m"
    }

    property bool sick: !answered || d === null || d.source === "down" || d.cache_age === null || d.cache_age > stale
    property color healthTone: sick ? Theme.harm : d.source === "oauth" ? Theme.warn : Theme.pick
    property string healthText: {
        if (!answered) return d === null ? "no answer from the mac" : "no answer · is the mac asleep?"
        if (d.source === "down") return "usage fetch is down"
        if (d.cache_age === null) return "no cache"
        if (d.cache_age > stale) return "stale · " + Math.floor(d.cache_age / 60) + "m"
        if (d.source === "oauth") return "safari cookie is cooked"
        return "fresh · " + Math.floor(d.cache_age) + "s"
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
        implicitWidth: 380
        implicitHeight: 74

        Text {
            id: label
            text: meter.title
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11
            font.letterSpacing: 1.6
            font.capitalization: Font.AllUppercase
        }

        Text {
            id: pct
            anchors.top: label.bottom
            anchors.topMargin: 8
            text: meter.visible ? meter.w.pct + "%" : ""
            color: meter.tone
            font.family: Theme.mono
            font.pixelSize: 26
            font.bold: true
        }

        Text {
            anchors.left: pct.right
            anchors.leftMargin: 10
            anchors.baseline: pct.baseline
            visible: meter.paced
            text: meter.visible && meter.paced ? "of " + meter.w.norm + "% by today" : ""
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 12
        }

        Text {
            anchors.right: parent.right
            anchors.baseline: pct.baseline
            text: meter.visible && meter.w.resets_at ? root.left(meter.w.resets_at, meter.now) : ""
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 12
        }

        Rectangle {
            id: bar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 10
            radius: 5
            color: Theme.band

            Rectangle {
                height: parent.height
                radius: 5
                color: meter.tone
                width: meter.visible ? parent.width * Math.min(meter.w.pct, 100) / 100 : 0

                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                visible: meter.paced
                y: -4
                width: 2
                height: parent.height + 8
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

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "cu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: card
                width: 868
                height: 404
                radius: Theme.radius
                color: Theme.ground
                border.color: Theme.edge
                border.width: 1

                Text {
                    id: name
                    x: 28
                    y: 20
                    text: "cu · claude"
                    color: Theme.pick
                    font.family: Theme.mono
                    font.pixelSize: 14
                    font.bold: true
                    font.letterSpacing: 0.6
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    anchors.verticalCenter: name.verticalCenter
                    spacing: 7

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: root.healthTone
                    }

                    Text {
                        text: root.healthText
                        color: root.sick ? Theme.harm : Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                }

                Item {
                    id: gauge
                    x: 28
                    y: 56
                    width: 320 * k
                    height: 268 * k

                    property real k: 1.15
                    property real cx: 160 * k
                    property real cy: 140 * k
                    property real r: 112 * k
                    property real max: root.d !== null ? root.d.gauge_max : 6000
                    property real budget: root.d !== null && root.d.budget !== null ? Math.min(root.d.budget, max) : max
                    property real speed: root.d !== null ? root.d.speed : 0
                    property bool over: root.d !== null && root.d.budget !== null && speed > root.d.budget
                    property real shown: Math.min(Math.max(speed, 0), max)
                    property real split: 240 * budget / max

                    Behavior on shown { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

                    function spot(rad, deg) {
                        const a = deg * Math.PI / 180
                        return Qt.point(cx + rad * Math.cos(a), cy + rad * Math.sin(a))
                    }

                    Text {
                        text: "speed"
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.letterSpacing: 1.6
                        font.capitalization: Font.AllUppercase
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: Qt.alpha(Theme.pick, 0.2)
                            strokeWidth: 14 * gauge.k
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap

                            PathAngleArc {
                                centerX: gauge.cx
                                centerY: gauge.cy
                                radiusX: gauge.r
                                radiusY: gauge.r
                                startAngle: 150
                                sweepAngle: gauge.split < 240 ? gauge.split - 1 : 240
                            }
                        }

                        ShapePath {
                            strokeColor: gauge.split < 240 ? Qt.alpha(Theme.harm, 0.2) : "transparent"
                            strokeWidth: 14 * gauge.k
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap

                            PathAngleArc {
                                centerX: gauge.cx
                                centerY: gauge.cy
                                radiusX: gauge.r
                                radiusY: gauge.r
                                startAngle: 150 + gauge.split + 1
                                sweepAngle: Math.max(240 - gauge.split - 1, 0.01)
                            }
                        }

                        ShapePath {
                            strokeColor: gauge.over ? Theme.harm : Theme.pick
                            strokeWidth: 14 * gauge.k
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap

                            PathAngleArc {
                                centerX: gauge.cx
                                centerY: gauge.cy
                                radiusX: gauge.r
                                radiusY: gauge.r
                                startAngle: 150
                                sweepAngle: Math.max(240 * gauge.shown / gauge.max, 0.5)
                            }
                        }
                    }

                    Repeater {
                        model: [0, 0.5, 1]

                        Text {
                            required property real modelData
                            property point at: gauge.spot(gauge.r - 26 * gauge.k, 150 + 240 * modelData)
                            x: at.x - width / 2
                            y: at.y - height / 2
                            text: modelData ? root.brief(gauge.max * modelData) : "0"
                            color: Theme.dim
                            font.family: Theme.mono
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        visible: gauge.split < 240
                        x: gauge.cx + gauge.r - 10 * gauge.k
                        y: gauge.cy - height / 2
                        width: 22 * gauge.k
                        height: 2.5
                        radius: 1
                        color: Theme.body
                        transform: Rotation {
                            origin.x: -(gauge.r - 10 * gauge.k)
                            origin.y: 1.25
                            angle: 150 + gauge.split
                        }
                    }

                    Text {
                        visible: gauge.split < 240
                        property point at: gauge.spot(gauge.r + 26 * gauge.k, 150 + gauge.split)
                        x: at.x - width / 2
                        y: at.y - height / 2
                        text: "budget"
                        color: Theme.body
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }

                    Rectangle {
                        x: gauge.cx - 16 * gauge.k
                        y: gauge.cy - height / 2
                        width: (gauge.r - 32 * gauge.k) + 16 * gauge.k
                        height: 4
                        radius: 2
                        color: Theme.body
                        antialiasing: true
                        transform: Rotation {
                            origin.x: 16 * gauge.k
                            origin.y: 2
                            angle: 150 + 240 * gauge.shown / gauge.max
                        }
                    }

                    Rectangle {
                        x: gauge.cx - 8
                        y: gauge.cy - 8
                        width: 16
                        height: 16
                        radius: 8
                        color: Theme.body
                    }

                    Text {
                        id: reading
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 188 * gauge.k
                        text: root.d !== null ? root.spaced(gauge.speed) : "–"
                        color: gauge.over ? Theme.harm : Theme.pick
                        font.family: Theme.mono
                        font.pixelSize: 44
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: reading.bottom
                        text: "output tokens / min"
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    anchors.verticalCenter: gauge.verticalCenter
                    spacing: 26

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

                Row {
                    x: 28
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    spacing: 12
                    visible: root.d !== null && root.d.today !== undefined

                    Text {
                        text: "today"
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.letterSpacing: 1.6
                        font.capitalization: Font.AllUppercase
                        anchors.baseline: totals.baseline
                    }

                    Text {
                        id: totals
                        text: parent.visible ? root.brief(root.d.today.in) + " in · " + root.brief(root.d.today.out) + " out" : ""
                        color: Theme.body
                        font.family: Theme.mono
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
