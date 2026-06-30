import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TenjinView

// Tag filter UI. Chips flow into a wrapping grid so several short tag
// names fit per row — the previous one-per-row ListView made the popup
// feel taller than it needed to be on long tag sets.
//
// QtQuick.Window deliberately not imported: it dead-strips on iOS static
// builds and crashes startup. Sizing and overlay dimensions go through
// the Platform singleton instead.
Item {
    id: root

    implicitWidth: trigger.implicitWidth
    implicitHeight: trigger.implicitHeight

    readonly property var _vm: appVM.entryVM
    readonly property var _activeIds: _vm.activeTagIds
    readonly property int _activeCount: _activeIds.length
    // 0 = Any (OR), 1 = All (AND). Mirrors FilterMode_t::Or / FilterMode_t::And.
    readonly property int _matchMode: _vm.tagMatchMode

    // Trigger button.
    Rectangle {
        id: trigger
        readonly property bool _hover: triggerArea.containsMouse
        readonly property bool _hasFilters: root._activeCount > 0

        implicitWidth:  triggerRow.implicitWidth + 2 * Platform.spacingMd
        implicitHeight: Platform.touchTarget - (Platform.isMobile ? 8 : 4)
        radius: Platform.radius
        color: _hasFilters ? Platform.accent
             : _hover      ? Platform.surfaceAlt
                           : Platform.surface
        border.color: _hasFilters ? Platform.accent : Platform.border
        border.width: Platform.borderWidth
        Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }

        Row {
            id: triggerRow
            anchors.centerIn: parent
            spacing: Platform.spacingSm
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Tags")
                color: trigger._hasFilters ? Platform.textOnDark : Platform.textPrimary
                font.pixelSize: Platform.fontSmall
                font.bold: true
            }
            Text {
                visible: trigger._hasFilters
                anchors.verticalCenter: parent.verticalCenter
                text: "· " + root._activeCount
                color: Platform.textOnDark
                font.pixelSize: Platform.fontSmall
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: popup.opened ? TenjinIcons.expandLess : TenjinIcons.expandMore
                font.family: TenjinIcons.family
                color: trigger._hasFilters ? Platform.textOnDark : Platform.textMuted
                font.pixelSize: Platform.fontTiny
            }
        }

        MouseArea {
            id: triggerArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.opened ? popup.close() : popup.open()
        }
    }

    Popup {
        id: popup
        parent: trigger
        x: 0
        y: trigger.height + Platform.spacingXs

        // Popup width: enough room for chips to wrap meaningfully. On
        // mobile, fill most of the screen; on desktop, give a comfortable
        // 360 px and clamp to the screen so it never overflows a small
        // window. Platform.screenWidth provides the fallback that used to
        // come from root.Window.width.
        readonly property int _screenW: Platform.screenWidth > 0 ? Platform.screenWidth : 1280
        readonly property int _screenH: Platform.screenHeight > 0 ? Platform.screenHeight : 1920
        width: Platform.isMobile
               ? Math.min(_screenW - 2 * Platform.spacingLg, 420)
               : Math.min(_screenW - 4 * Platform.spacingLg, 360)

        readonly property int _maxHeight: Math.round(_screenH * 0.7)
        height: Math.min(implicitHeight, _maxHeight)

        padding: Platform.spacingMd
        modal: Platform.isMobile
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle { color: Platform.overlayDim }

        background: Rectangle {
            color: Platform.surface
            radius: Platform.radiusLarge
            border.color: Platform.border
            border.width: Platform.borderWidth
        }

        // Subtle open/close transition.
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Platform.effDurationMed; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale";   from: 0.96; to: 1.0; duration: Platform.effDurationMed; easing.type: Easing.OutCubic }
            }
        }

        onAboutToShow: tagListInternal.reload()

        contentItem: ColumnLayout {
            spacing: Platform.spacingMd

            // Search field.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Platform.touchTarget - 4
                radius: Platform.radius
                color: Platform.bg
                border.color: searchField.activeFocus ? Platform.accent : Platform.border
                border.width: Platform.borderWidth
                Behavior on border.color { ColorAnimation { duration: Platform.effDurationFast } }

                TextField {
                    id: searchField
                    anchors {
                        fill: parent
                        leftMargin: Platform.spacingMd
                        rightMargin: Platform.spacingMd
                    }
                    placeholderText: qsTr("Search tags\u2026")
                    placeholderTextColor: Platform.textMuted
                    background: Item {}
                    color: Platform.textPrimary
                    font.pixelSize: Platform.fontSmall
                    verticalAlignment: TextInput.AlignVCenter
                    onTextChanged: tagListInternal.refilter()
                    Keys.onEscapePressed: { text = ""; popup.close() }
                }
            }

            // Any / All segmented toggle.
            RowLayout {
                Layout.fillWidth: true
                spacing: Platform.spacingSm

                Repeater {
                    model: [ { label: qsTr("Any"), mode: 0 },
                             { label: qsTr("All"), mode: 1 } ]
                    delegate: TagChip {
                        required property var modelData
                        Layout.fillWidth: true
                        tagName:     modelData.label
                        active:      root._matchMode === modelData.mode
                        interactive: true
                        onClicked:   root._vm.tagMatchMode = modelData.mode
                    }
                }
            }

            // Active-count + Clear row. Lives above the grid so users can
            // see at a glance how many tags they've selected and clear
            // them without scrolling to the footer.
            RowLayout {
                Layout.fillWidth: true
                visible: root._activeCount > 0
                spacing: Platform.spacingSm
                Text {
                    Layout.fillWidth: true
                    text: root._activeCount + (root._activeCount === 1 ? qsTr(" tag selected") : qsTr(" tags selected"))
                    color: Platform.textMuted
                    font.pixelSize: Platform.fontSmall
                }
                Text {
                    text: qsTr("Clear all")
                    color: clearArea.containsMouse ? Platform.danger : Platform.accentDark
                    font.pixelSize: Platform.fontSmall
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: Platform.effDurationFast } }
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._vm.clearTagFilters()
                    }
                }
            }

            // Tag grid. Flow wraps chips left-to-right top-to-bottom; the
            // surrounding Flickable handles overflow when the user has a
            // long tag set.
            Flickable {
                id: tagGrid
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(
                    Math.max(flow.implicitHeight + 2 * Platform.spacingSm,
                             Platform.chipHeight * 3),
                    Math.round(popup._maxHeight * 0.55))
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: flow.implicitHeight + 2 * Platform.spacingSm
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Flow {
                    id: flow
                    width: parent.width
                    spacing: Platform.spacingSm
                    padding: Platform.spacingXs

                    Repeater {
                        model: ListModel { id: tagModel }
                        delegate: TagChip {
                            required property var model
                            tagName:     model.name
                            tagId:       model.id
                            active:      model.active
                            interactive: true
                            onClicked: {
                                if (model.active) root._vm.removeTagFilter(model.id)
                                else              root._vm.addTagFilter(model.id)
                            }
                        }
                    }
                }

                // Empty state.
                Column {
                    anchors.centerIn: parent
                    visible: tagModel.count === 0
                    spacing: Platform.spacingSm
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: TenjinIcons.tags
                        font.family: TenjinIcons.family
                        font.pixelSize: 32
                        color: Platform.textMuted
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: searchField.text.length > 0
                              ? "No tags match \"" + searchField.text + "\"."
                              : "No tags yet — create one from the Tags page."
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Done footer.
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                TagChip {
                    tagName: "Done"
                    interactive: true
                    active: true
                    onClicked: popup.close()
                }
            }
        }

        QtObject {
            id: tagListInternal
            property var _all: []
            function reload() { _all = root._vm.getAllTags(); refilter() }
            function refilter() {
                tagModel.clear()
                const query = searchField.text.trim().toLowerCase()
                const activeIds = root._activeIds
                const isActive = function (id) {
                    for (let i = 0; i < activeIds.length; ++i)
                        if (activeIds[i] === id) return true
                    return false
                }
                const actives = []
                const inactives = []
                for (let i = 0; i < _all.length; ++i) {
                    const t = _all[i]
                    if (query.length > 0 && t.name.toLowerCase().indexOf(query) < 0) continue
                    const row = { id: t.id, name: t.name, active: isActive(t.id) }
                    if (row.active) actives.push(row)
                    else            inactives.push(row)
                }
                const cmpName = (a, b) => a.name.localeCompare(b.name)
                actives.sort(cmpName)
                inactives.sort(cmpName)
                for (let i = 0; i < actives.length; ++i)   tagModel.append(actives[i])
                for (let i = 0; i < inactives.length; ++i) tagModel.append(inactives[i])
            }
        }

        Connections {
            target: root._vm
            function onTagFiltersChanged() { if (popup.opened) tagListInternal.refilter() }
            function onEntryListChanged()  { if (popup.opened) tagListInternal.reload() }
        }
    }
}


