import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import TenjinView

// Isolated audio/video player with full transport controls. Lives in its own
// file so ContentBlock.qml needs no QtMultimedia import — a build without
// MEDIA_SUPPORT omits this file and the Loader referencing it stays empty.
//
// Video shows its first frame (keyframe) when not playing: the player is loaded
// paused so QtMultimedia decodes and presents frame 0 into the VideoOutput.
ColumnLayout {
    id: mpRoot
    property string source: ""
    property bool   isVideo: true
    property string tooltipText: ""
    property bool   fullscreen: false
    spacing: 6

    function fmtTime(ms) {
        if (ms <= 0) return "0:00"
        const s = Math.floor(ms / 1000)
        const m = Math.floor(s / 60)
        const sec = s % 60
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    Rectangle {
        id: stage
        Layout.fillWidth: true
        Layout.preferredHeight: mpRoot.isVideo ? Math.max(180, width * 0.5625)
                                               : Platform.touchTarget * 1.4
        Layout.maximumHeight: mpRoot.isVideo ? 480 : Platform.touchTarget * 1.4
        color: "#000000"
        radius: Platform.radius - 2
        clip: true

        VideoOutput {
            id: videoOut
            anchors.fill: parent
            anchors.margins: mpRoot.isVideo ? 0 : 6
            visible: mpRoot.isVideo
        }

        // Audio placeholder
        Text {
            anchors.centerIn: parent
            visible: !mpRoot.isVideo
            text: "\u266A  Audio"
            color: Platform.textOnDark
            font.pixelSize: Platform.fontBase
        }

        // Big center play overlay when paused/stopped (video only).
        Rectangle {
            anchors.centerIn: parent
            visible: mpRoot.isVideo && player.playbackState !== MediaPlayer.PlayingState
            width: 64; height: 64; radius: 32
            color: Qt.rgba(0, 0, 0, 0.55)
            Text { anchors.centerIn: parent; text: "\u25B6"; color: "#ffffff"; font.pixelSize: 30 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: player.play() }
        }

        HoverHandler { id: stageHover }
        ToolTip.visible: stageHover.hovered && mpRoot.tooltipText.length > 0
        ToolTip.text: mpRoot.tooltipText

        MediaPlayer {
            id: player
            source: mpRoot.source
            videoOutput: mpRoot.fullscreen ? fsVideoOut : videoOut
            audioOutput: AudioOutput { id: audioOut; volume: volumeSlider.value; muted: muteBtn.muted }
            // No autoplay. To show the first frame as a thumbnail without
            // starting playback, seek to position 0 once loaded; QtMultimedia
            // decodes and presents that frame into the VideoOutput.
            property bool primedFrame: false
            onMediaStatusChanged: {
                if (mpRoot.isVideo && !primedFrame
                    && mediaStatus === MediaPlayer.LoadedMedia) {
                    primedFrame = true
                    position = 0   // present frame 0 without playing
                }
            }
        }
    }

    // Transport bar
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // Play / pause
        Rectangle {
            implicitWidth: Platform.touchTarget; implicitHeight: Platform.touchTarget
            radius: Platform.radius
            color: playArea.containsMouse ? Platform.accentDark : Platform.accent
            Text {
                anchors.centerIn: parent
                text: player.playbackState === MediaPlayer.PlayingState ? "\u23F8" : "\u25B6"
                color: Platform.bg; font.pixelSize: Platform.fontLarge
            }
            MouseArea {
                id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
            }
        }

        // Current time
        Text {
            text: mpRoot.fmtTime(player.position)
            color: Platform.textMuted; font.pixelSize: Platform.fontBase - 2
            Layout.minimumWidth: 36
        }

        // Seek
        Slider {
            id: seekSlider
            Layout.fillWidth: true
            from: 0; to: player.duration > 0 ? player.duration : 1
            value: player.position
            onMoved: player.position = value
        }

        // Total time
        Text {
            text: mpRoot.fmtTime(player.duration)
            color: Platform.textMuted; font.pixelSize: Platform.fontBase - 2
            Layout.minimumWidth: 36
        }

        // Mute toggle
        Rectangle {
            id: muteBtn
            property bool muted: false
            implicitWidth: Platform.touchTarget; implicitHeight: Platform.touchTarget
            radius: Platform.radius
            color: muteArea.containsMouse ? Platform.surfaceAlt : "transparent"
            Text {
                anchors.centerIn: parent
                text: muteBtn.muted || volumeSlider.value === 0 ? "\uD83D\uDD07" : "\uD83D\uDD0A"
                font.pixelSize: Platform.fontBase
            }
            MouseArea {
                id: muteArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: muteBtn.muted = !muteBtn.muted
            }
        }

        // Volume
        Slider {
            id: volumeSlider
            Layout.preferredWidth: 80
            from: 0; to: 1; value: 0.8
        }

        // Playback speed
        ComboBox {
            id: speedBox
            Layout.preferredWidth: 72
            model: ["0.5x", "0.75x", "1x", "1.25x", "1.5x", "2x"]
            currentIndex: 2
            onActivated: {
                const v = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0][currentIndex]
                player.playbackRate = v
            }
        }

        // Fullscreen (video only)
        Rectangle {
            visible: mpRoot.isVideo
            implicitWidth: Platform.touchTarget; implicitHeight: Platform.touchTarget
            radius: Platform.radius
            color: fsArea.containsMouse ? Platform.surfaceAlt : "transparent"
            Text { anchors.centerIn: parent; text: "\u26F6"; font.pixelSize: Platform.fontBase }
            MouseArea {
                id: fsArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: mpRoot.fullscreen = true
            }
        }
    }

    // Fullscreen overlay: reparented to the window's overlay so it covers the
    // whole app. Avoids a separate Window (which can't take Keys and conflicts
    // on visible/visibility). Player output switches to fsVideoOut via the
    // MediaPlayer.videoOutput binding while fullscreen is true.
    Item {
        id: fsOverlay
        parent: Overlay.overlay
        anchors.fill: parent
        // Detach from the parent ColumnLayout's sizing (it's reparented to the
        // window overlay; the layout must not try to position it).
        Layout.preferredWidth: 0
        Layout.preferredHeight: 0
        visible: mpRoot.fullscreen
        z: 9999

        Rectangle {
            anchors.fill: parent
            color: "#000000"

            VideoOutput {
                id: fsVideoOut
                anchors.fill: parent
            }

            // Click anywhere (not on controls) toggles play/pause.
            MouseArea {
                anchors.fill: parent
                onClicked: player.playbackState === MediaPlayer.PlayingState
                           ? player.pause() : player.play()
            }

            // Minimal in-fullscreen controls: play/pause, seek, time, close.
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Platform.touchTarget + 24
                color: Qt.rgba(0, 0, 0, 0.6)
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 12
                    Rectangle {
                        implicitWidth: Platform.touchTarget; implicitHeight: Platform.touchTarget
                        radius: Platform.radius; color: Platform.accent
                        Text { anchors.centerIn: parent
                            text: player.playbackState === MediaPlayer.PlayingState ? "\u23F8" : "\u25B6"
                            color: Platform.bg; font.pixelSize: Platform.fontLarge }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: player.playbackState === MediaPlayer.PlayingState
                                       ? player.pause() : player.play() }
                    }
                    Text { text: mpRoot.fmtTime(player.position); color: "#ffffff"; font.pixelSize: Platform.fontBase }
                    Slider {
                        Layout.fillWidth: true
                        from: 0; to: player.duration > 0 ? player.duration : 1
                        value: player.position
                        onMoved: player.position = value
                    }
                    Text { text: mpRoot.fmtTime(player.duration); color: "#ffffff"; font.pixelSize: Platform.fontBase }
                }
            }

            // Close button.
            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: 16 }
                width: Platform.touchTarget + 30; height: Platform.touchTarget
                radius: Platform.radius; color: Qt.rgba(0, 0, 0, 0.6)
                Text { anchors.centerIn: parent; text: "\u2715  Close"; color: "#ffffff"; font.pixelSize: Platform.fontBase }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: mpRoot.fullscreen = false }
            }
        }

        // Esc exits fullscreen (Item can take Keys; Window can't).
        focus: mpRoot.fullscreen
        Keys.onEscapePressed: mpRoot.fullscreen = false
    }
}

