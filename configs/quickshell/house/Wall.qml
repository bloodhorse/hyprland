import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import Qt.labs.folderlistmodel

Scope {
    id: root
    property bool open: false
    property bool ready: false
    property bool moved: false
    property string tool: Quickshell.env("HOME") + "/.local/bin/wall"
    property string thumbs: Quickshell.env("HOME") + "/.cache/wall-thumbs/"
    property string was: ""
    property string desk: Quickshell.env("HOME") + "/.local/bin/desk"

    IpcHandler {
        target: "wall"
        function toggle(): void { if (root.open) root.cancel(); else root.show() }
    }

    function show() {
        ready = false
        moved = false
        current.running = true
        open = true
    }

    function keep() {
        var path = folderModel.get(view.currentIndex, "filePath")
        if (path) Quickshell.execDetached([tool, path])
        open = false
        Quickshell.execDetached([desk, "in"])
    }

    function cancel() {
        if (moved) Quickshell.execDetached([tool, "revert"])
        open = false
        Quickshell.execDetached([desk, "in"])
    }

    function settle() {
        for (var i = 0; i < folderModel.count; i++) {
            if (folderModel.get(i, "filePath") === was) {
                view.highlightMoveDuration = 0
                view.currentIndex = i
                view.highlightMoveDuration = 260
                break
            }
        }
        ready = true
    }

    Process {
        id: current
        command: ["sh", "-c", "cat \"${XDG_RUNTIME_DIR:-/tmp}/wall-was\""]
        stdout: StdioCollector {
            onStreamFinished: {
                root.was = text.trim()
                root.settle()
            }
        }
    }

    Timer {
        id: preview
        interval: 200
        onTriggered: {
            var path = folderModel.get(view.currentIndex, "filePath")
            if (path && path !== root.was) {
                root.moved = true
                Quickshell.execDetached([root.tool, "preview", path])
            }
        }
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers/"
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        sortField: FolderListModel.Name
    }

    PanelWindow {
        visible: root.open
        anchors { left: true; right: true; bottom: true }
        margins.bottom: 36
        implicitHeight: 400
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wall"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        PathView {
            id: view
            anchors.fill: parent
            anchors.bottomMargin: 56
            model: folderModel
            focus: root.open
            pathItemCount: 7
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            snapMode: PathView.SnapToItem
            highlightMoveDuration: 260

            onCurrentIndexChanged: if (root.open && root.ready) preview.restart()

            path: Path {
                startX: 0
                startY: view.height / 2
                PathAttribute { name: "s"; value: 0.42 }
                PathAttribute { name: "z"; value: 0 }
                PathAttribute { name: "o"; value: 0.25 }
                PathLine { x: view.width / 2; y: view.height / 2 }
                PathAttribute { name: "s"; value: 1.0 }
                PathAttribute { name: "z"; value: 10 }
                PathAttribute { name: "o"; value: 1.0 }
                PathLine { x: view.width; y: view.height / 2 }
                PathAttribute { name: "s"; value: 0.42 }
                PathAttribute { name: "z"; value: 0 }
                PathAttribute { name: "o"; value: 0.25 }
            }

            Keys.onLeftPressed: decrementCurrentIndex()
            Keys.onRightPressed: incrementCurrentIndex()
            Keys.onReturnPressed: root.keep()
            Keys.onEnterPressed: root.keep()
            Keys.onEscapePressed: root.cancel()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) view.decrementCurrentIndex()
                    else view.incrementCurrentIndex()
                }
            }

            delegate: Item {
                id: card
                required property string fileName
                required property string filePath
                required property int index
                readonly property bool here: PathView.isCurrentItem
                readonly property real ar: img.implicitHeight > 0 ? img.implicitWidth / img.implicitHeight : 1.6

                height: 300
                width: height * ar
                scale: PathView.s
                z: PathView.z
                opacity: PathView.o

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Theme.ground

                    Image {
                        id: img
                        anchors.fill: parent
                        source: "file://" + root.thumbs + card.fileName + ".jpg"
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        onStatusChanged: if (status === Image.Error && source.toString().indexOf("wall-thumbs") >= 0) source = "file://" + card.filePath
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.color: card.here ? Theme.pick : Theme.edge
                    border.width: card.here ? 2 : 1
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (card.here) root.keep()
                        else view.currentIndex = card.index
                    }
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: label.implicitWidth + 36
            height: 34
            radius: 17
            color: Theme.ground
            border.color: Theme.edge
            border.width: 1

            Text {
                id: label
                anchors.centerIn: parent
                text: {
                    var name = folderModel.get(view.currentIndex, "fileBaseName") || ""
                    if (name.length > 38) name = name.slice(0, 37) + "…"
                    return name + "   " + (view.currentIndex + 1) + " / " + folderModel.count
                }
                color: Theme.body
                font.family: Theme.mono
                font.pointSize: Theme.small
            }
        }
    }
}
