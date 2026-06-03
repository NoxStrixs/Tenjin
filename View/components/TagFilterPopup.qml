import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import TenjinView

// Tag filter UI
Item {
    id: root

    implicitWidth: trigger.implicitWidth
    implicitHeight: trigger.implicitHeight

    readonly property var _vm: appVM.entryVM
    readonly property var _activeIds: _vm.activeTagIds
    readonly property int _activeCount: _activeIds.length
    // 0 = Any, 1 = All. Matches FilterMode_t::Or / FilterMode_t::And.
    readonly property int _matchMode: _vm.tagMatchMode

    // Trigger button
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

        Behavior on color { ColorAnimation { duration: Platform.durationFast } }

        Row {
            id: triggerRow
            anchors.centerIn: parent
            spacing: Platform.spacingSm

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Tags"
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
                text: popup.opened ? "▴" : "▾"
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

    // Popup
    Popup {
        id: popup
        parent: trigger
        x: 0
        y: trigger.height + Platform.spacingXs

        width: Platform.isMobile
               ? Math.min(360, root.Window.width - 2 * Platform.spacingLg)
               : Math.max(trigger.implicitWidth, root.width)

        readonly property int _maxHeight: Math.round(root.Window.height * 0.7)
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

        onAboutToShow: tagListInternal.reload()

        contentItem: ColumnLayout {
            id: contents
            spacing: Platform.spacingMd

            // Header: search and Any/All toggle
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Platform.spacingSm

                // Search field
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Platform.touchTarget - 4
                    radius: Platform.radius
                    color: Platform.bg
                    border.color: searchField.activeFocus ? Platform.accent : Platform.border
                    border.width: Platform.borderWidth

                    Behavior on border.color { ColorAnimation { duration: Platform.durationFast } }

                    TextField {
                        id: searchField
                        anchors {
                            fill: parent
                            leftMargin: Platform.spacingMd
                            rightMargin: Platform.spacingMd
                        }
                        placeholderText: "Search tags…"
                        background: Item {}
                        color: Platform.textPrimary
                        font.pixelSize: Platform.fontSmall
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: tagListInternal.refilter()
                        Keys.onEscapePressed: { text = ""; popup.close() }
                    }
                }

                // Any/All segmented toggle. Mirrors smart-deck filter modes:
                // Any = entry has at least one of the selected tags (OR),
                // All = entry has every selected tag (AND).
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Platform.spacingSm

                    Repeater {
                        model: [ { label: "Any", mode: 0 },
                                 { label: "All", mode: 1 } ]
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
            }

            // Tag list
            Rectangle {
                id: listFrame
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(
                    Platform.chipHeight * 3,
                    Math.min(tagList.contentHeight + 2,
                             Platform.chipHeight * Platform.popupMaxRows))
                Layout.fillHeight: true
                color: "transparent"

                ListView {
                    id: tagList
                    anchors.fill: parent
                    clip: true
                    spacing: Platform.spacingXs
                    model: ListModel { id: tagModel }
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        // Delegate row spans the list and contains a
                        // natural-width chip at the left. Whole row is tappable
                        // so users can hit the row, not just the pill.
                        required property var modelData
                        width: tagList.width
                        height: Platform.chipHeight + Platform.spacingXs

                        TagChip {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                                leftMargin: Platform.spacingXs
                                rightMargin: Platform.spacingXs
                            }
                            tagName:     parent.modelData.name
                            tagId:       parent.modelData.id
                            active:      parent.modelData.active
                            interactive: true
                            onClicked: {
                                if (parent.modelData.active)
                                    root._vm.removeTagFilter(parent.modelData.id)
                                else
                                    root._vm.addTagFilter(parent.modelData.id)
                            }
                        }
                    }

                    // Empty state
                    Text {
                        anchors.centerIn: parent
                        visible: tagList.count === 0
                        width: parent.width - 2 * Platform.spacingMd
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: searchField.text.length > 0
                              ? "No tags match \"" + searchField.text + "\"."
                              : "No tags yet — create one from the Tags page."
                        color: Platform.textMuted
                        font.pixelSize: Platform.fontSmall
                    }
                }
            }

            // Footer: Clear and Close
            RowLayout {
                Layout.fillWidth: true
                spacing: Platform.spacingMd

                TagChip {
                    visible: root._activeCount > 0
                    tagName: "Clear all"
                    interactive: true
                    onClicked: root._vm.clearTagFilters()
                }

                Item { Layout.fillWidth: true }

                TagChip {
                    tagName: "Done"
                    interactive: true
                    active: true
                    onClicked: popup.close()
                }
            }
        }

        // We rebuild it on three triggers:
        //   1. popup opens (refresh upstream data)
        //   2. search text changes (refilter)
        //   3. activeTagIds or tag list changes (re-sort actives to the top)
        QtObject {
            id: tagListInternal
            // All tags fetched from the VM, cached so the user typing in
            // the search field doesn't re-hit the database on every keystroke.
            property var _all: []

            function reload() {
                _all = root._vm.getAllTags()
                refilter()
            }

            function refilter() {
                tagModel.clear()
                const query = searchField.text.trim().toLowerCase()
                const activeIds = root._activeIds
                const isActive = function (id) {
                    for (let i = 0; i < activeIds.length; ++i)
                        if (activeIds[i] === id) return true
                    return false
                }

                // Partition into active / inactive, applying search filter
                // to both groups. Alphabetised within each group.
                const actives = []
                const inactives = []
                for (let i = 0; i < _all.length; ++i) {
                    const t = _all[i]
                    if (query.length > 0 && t.name.toLowerCase().indexOf(query) < 0)
                        continue
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

        // React to upstream VM signals while the popup is open.
        Connections {
            target: root._vm
            function onTagFiltersChanged() { if (popup.opened) tagListInternal.refilter() }
            function onEntryListChanged()  { if (popup.opened) tagListInternal.reload() }
        }
    }
}

