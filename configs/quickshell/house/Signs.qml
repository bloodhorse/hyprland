import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

Scope {
    id: root
    property bool ru: false
    property bool mode: false
    property real breath: 0.35
    property real phase: 0
    property real arm: 1
    readonly property real width: 4
    readonly property real alphaOn: 0.57

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                root.ru = event.data.indexOf("Russian") >= 0
                root.arm = 1
            } else if (event.name === "submap") {
                root.mode = event.data === "c"
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "hyprctl -j devices | jq -r '.keyboards[] | select(.main) | .active_keymap'"]
        stdout: StdioCollector {
            onStreamFinished: root.ru = text.indexOf("Russian") >= 0
        }
    }

    Timer {
        interval: 200
        repeat: true
        running: root.ru
        onTriggered: root.phase = (root.phase + 0.025) % 1
    }

    IdleMonitor {
        enabled: root.ru
        respectInhibitors: false
        timeout: 18
        onIsIdleChanged: {
            if (isIdle) fade.start()
            else { fade.stop(); root.arm = 1 }
        }
    }

    IdleMonitor {
        enabled: root.ru
        respectInhibitors: false
        timeout: 30
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "0"])
    }

    SequentialAnimation on breath {
        running: root.mode
        loops: Animation.Infinite
        NumberAnimation { to: 0.6; duration: 1000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.35; duration: 1000; easing.type: Easing.InOutSine }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.mode
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "mode-glow"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                id: glowBox
                anchors.fill: parent
                opacity: root.breath
                readonly property real depth: 24
                readonly property color glow: "#40E0D0"
                readonly property color none: "#0040E0D0"

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: parent.depth
                    gradient: Gradient {
                        GradientStop { position: 0; color: glowBox.glow }
                        GradientStop { position: 1; color: glowBox.none }
                    }
                }
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: parent.depth
                    gradient: Gradient {
                        GradientStop { position: 0; color: glowBox.none }
                        GradientStop { position: 1; color: glowBox.glow }
                    }
                }
                Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                    width: parent.depth
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: glowBox.glow }
                        GradientStop { position: 1; color: glowBox.none }
                    }
                }
                Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                    width: parent.depth
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: glowBox.none }
                        GradientStop { position: 1; color: glowBox.glow }
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: fade
        target: root
        property: "arm"
        to: 0.2
        duration: 12000
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.ru
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ru-frame"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Shape {
                id: frame
                anchors.fill: parent
                opacity: root.alphaOn * root.arm
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillRule: ShapePath.OddEvenFill
                    strokeWidth: -1
                    fillGradient: ConicalGradient {
                        centerX: frame.width / 2
                        centerY: frame.height / 2
                        angle: root.phase * 360
                        GradientStop { position: 0.0; color: "#00FFD1" }
                        GradientStop { position: 0.25; color: "#0047FF" }
                        GradientStop { position: 0.5; color: "#00FFD1" }
                        GradientStop { position: 0.75; color: "#0047FF" }
                        GradientStop { position: 1.0; color: "#00FFD1" }
                    }

                    PathRectangle { x: 0; y: 0; width: frame.width; height: frame.height }
                    PathRectangle {
                        x: root.width
                        y: root.width
                        width: frame.width - 2 * root.width
                        height: frame.height - 2 * root.width
                        radius: 8
                    }
                }
            }
        }
    }
}
