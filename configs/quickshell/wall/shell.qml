import Quickshell
import Quickshell.Wayland
import QtQuick
import Qt.labs.folderlistmodel

PanelWindow {
    id: main

    property int shownTiles: 9
    property string tool: Quickshell.env("HOME") + "/.local/bin/wall"

    implicitHeight: 500
    implicitWidth: Screen.width
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wall"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    FolderListModel {
        id: folderModel
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers/"
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        sortField: FolderListModel.Name
    }

    ListView {
        id: list
        anchors.fill: parent
        focus: true

        model: folderModel
        orientation: ListView.Horizontal
        spacing: 10
        clip: true
        cacheBuffer: width * 2

        property int selectedIndex: 0
        property real tileWidth: width / main.shownTiles - 10

        function clampIndex(i) {
            return Math.max(0, Math.min(i, count - 1))
        }

        function clampX(x) {
            return Math.max(0, Math.min(x, contentWidth - width))
        }

        function activateCurrent() {
            const path = folderModel.get(selectedIndex, "filePath")
            Quickshell.execDetached([main.tool, path])
            Qt.quit()
        }

        function ensureVisibleAnimated(i) {
            const step = tileWidth + spacing
            const itemStart = i * step
            const itemEnd = itemStart + tileWidth + 20

            if (itemStart < contentX)
                contentX = clampX(itemStart)
            else if (itemEnd > contentX + width)
                contentX = clampX(itemEnd - width)

            selectedIndex = i
        }

        Keys.onLeftPressed: ensureVisibleAnimated(clampIndex(selectedIndex - 1))
        Keys.onRightPressed: ensureVisibleAnimated(clampIndex(selectedIndex + 1))
        Keys.onReturnPressed: activateCurrent()
        Keys.onSpacePressed: activateCurrent()
        Keys.onEscapePressed: Qt.quit()

        delegate: Item {
            id: delegateRoot
            width: list.tileWidth
            height: list.height

            property bool isSelected: index === list.selectedIndex

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * (isSelected ? 1.0 : 0.8)
                height: parent.height * (isSelected ? 0.9 : 0.75)
                radius: 16
                color: "transparent"
                border.color: isSelected ? "#7DE8DA" : "transparent"
                border.width: isSelected ? 4 : 0

                Behavior on width { NumberAnimation { duration: 120 } }
                Behavior on height { NumberAnimation { duration: 120 } }

                Image {
                    anchors.fill: parent
                    anchors.margins: isSelected ? 4 : 0
                    source: "file://" + filePath
                    sourceSize.height: 500
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (list.selectedIndex === index) {
                            list.activateCurrent()
                        } else {
                            list.selectedIndex = index
                        }
                    }
                }
            }
        }
    }
}
