import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebView
import TenjinView

// Inline web embed with a click-to-play poster.
//
// Behavior:
//   1. Poster mode (default): show a thumbnail (YouTube hqdefault or generic
//      preview card) with a play overlay. No WebView is instantiated, so the
//      page isn't fetched, no JS runs, no autoplay triggers.
//   2. Play mode: tap → swap the poster for the live WebView with the URL.
//      For YouTube, we rewrite watch?v=ID into embed/ID?autoplay=1 so playback
//      starts immediately and the page chrome stays inline.
//   3. Close button (✕, top-right) returns to poster mode and unloads the
//      WebView so memory and audio are released.
//   4. Loading state covers the page until WebView reports LoadSucceededStatus.
//   5. On LoadFailedStatus, show an error card with an "Open externally" link.
//
// Public API (used by ContentBlock.qml's web-embed loader):
//   property string src   — the URL to embed.
//
// Sizing comes from the parent (Loader anchors.fill); we just paint within it.
Item {
    id: web

    // Set by ContentBlock.qml after Loader.onLoaded fires.
    property string src: ""

    // ── State ─────────────────────────────────────────────────────────────────
    // playing : true once the user has clicked the poster. While false, the
    //           WebView is not created (Loader.sourceComponent = null), so the
    //           network is quiet and CPU is idle.
    // loading : the WebView is up but its document hasn't finished loading.
    // failed  : the document load reported failure.
    property bool playing: false
    property bool loading: false
    property bool failed:  false

    // ── URL classification ────────────────────────────────────────────────────
    // YouTube detection drives the thumbnail and embed-URL rewriting. Three
    // common forms are recognised: watch?v=, youtu.be/, and the bare /embed/
    // (already an embed; no rewrite needed).
    readonly property string _ytId: web._extractYouTubeId(web.src)
    readonly property bool   _isYouTube: _ytId.length > 0

    // Best-effort YouTube thumbnail. hqdefault is the highest resolution that
    // is guaranteed present for any public video; sddefault/maxresdefault
    // sometimes 404 for older or low-resolution uploads.
    readonly property string _ytThumb: _isYouTube
        ? "https://i.ytimg.com/vi/" + _ytId + "/hqdefault.jpg"
        : ""

    // URL to actually feed the WebView once playing — autoplay for YouTube.
    readonly property string _embedUrl: _isYouTube
        ? "https://www.youtube.com/embed/" + _ytId + "?autoplay=1&rel=0"
        : web.src

    function _extractYouTubeId(url) {
        if (!url) return ""
        // youtu.be/<id>[?...]
        let m = url.match(/youtu\.be\/([A-Za-z0-9_-]{6,})/)
        if (m) return m[1]
        // youtube.com/watch?...&v=<id>&...
        m = url.match(/[?&]v=([A-Za-z0-9_-]{6,})/)
        if (m) return m[1]
        // youtube.com/embed/<id>
        m = url.match(/youtube\.com\/embed\/([A-Za-z0-9_-]{6,})/)
        if (m) return m[1]
        // youtube.com/shorts/<id>
        m = url.match(/youtube\.com\/shorts\/([A-Za-z0-9_-]{6,})/)
        if (m) return m[1]
        return ""
    }

    // ── Poster mode ───────────────────────────────────────────────────────────
    // Single component covers both the YouTube thumbnail case and the generic
    // preview case. The play button is the same in both.
    Rectangle {
        id: poster
        anchors.fill: parent
        visible: !web.playing
        color: Platform.bg
        radius: Platform.radius
        clip: true

        // Thumbnail. For YouTube we load the remote image; for everything else
        // we draw a centred globe glyph over a tinted surface. Image is
        // asynchronous so we never block while the bytes come in.
        Image {
            id: thumb
            anchors.fill: parent
            visible: web._isYouTube && status === Image.Ready
            source: web._isYouTube ? web._ytThumb : ""
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            // YouTube thumbnails come back with letterboxing bars built in;
            // a small horizontal crop hides them without losing the subject.
            sourceClipRect: status === Image.Ready
                ? Qt.rect(0, sourceSize.height * 0.10,
                          sourceSize.width, sourceSize.height * 0.80)
                : Qt.rect(0, 0, 0, 0)
        }

        // Subtle gradient overlay — keeps the play button legible regardless
        // of thumbnail content.
        Rectangle {
            anchors.fill: parent
            visible: thumb.visible
            gradient: Gradient {
                GradientStop { position: 0.0; color: Platform.mediaScrimLight }
                GradientStop { position: 1.0; color: Platform.mediaScrimHeavy }
            }
        }

        // Generic preview content shown when there's no thumbnail.
        ColumnLayout {
            anchors.centerIn: parent
            visible: !thumb.visible
            spacing: Platform.spacingSm

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: TenjinIcons.globe
                font.family: TenjinIcons.family
                color: Platform.textMuted
                font.pixelSize: Platform.fontTitle + 16
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: poster.width - 2 * Platform.spacingLg
                horizontalAlignment: Text.AlignHCenter
                text: web.src
                color: Platform.textMuted
                font.pixelSize: Platform.fontSmall
                elide: Text.ElideMiddle
            }
        }

        // ▶ play button — large, centred, hover-highlighted.
        Rectangle {
            id: playButton
            anchors.centerIn: parent
            width:  Platform.touchTarget * 1.75
            height: width
            radius: width / 2
            color: playArea.containsMouse ? Platform.accent : Platform.mediaControlBg
            border.color: Platform.textOnDark
            border.width: Platform.borderWidth

            Behavior on color { ColorAnimation { duration: Platform.durationFast } }

            Text {
                // Off-centre the glyph slightly so the triangle reads centred.
                anchors {
                    centerIn: parent
                    horizontalCenterOffset: 3
                }
                text: TenjinIcons.play
                font.family: TenjinIcons.family
                color: Platform.textOnDark
                font.pixelSize: Platform.fontTitle + 6
            }
        }

        MouseArea {
            id: playArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                web.failed  = false
                web.loading = true
                web.playing = true
            }
        }
    }

    // ── Play mode ─────────────────────────────────────────────────────────────
    // WebView is in a Loader so it is genuinely absent (not just hidden) until
    // the user opts in. Closing returns the Loader to null and frees the page.
    Loader {
        id: viewLoader
        anchors.fill: parent
        active: web.playing
        sourceComponent: webComponent
    }

    Component {
        id: webComponent
        WebView {
            id: liveView
            url: web._embedUrl
            onLoadingChanged: function (loadRequest) {
                if (loadRequest.status === WebView.LoadStartedStatus) {
                    web.loading = true
                    web.failed  = false
                } else if (loadRequest.status === WebView.LoadSucceededStatus) {
                    web.loading = false
                } else if (loadRequest.status === WebView.LoadFailedStatus) {
                    web.loading = false
                    web.failed  = true
                }
            }
        }
    }

    // ── Loading overlay ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: web.playing && web.loading && !web.failed
        color: Platform.overlayDim

        BusyIndicator {
            anchors.centerIn: parent
            running: parent.visible
        }
    }

    // ── Error overlay ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: web.playing && web.failed
        color: Platform.bg
        radius: Platform.radius

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Platform.spacingMd
            width: parent.width - 2 * Platform.spacingLg

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: TenjinIcons.warning
                font.family: TenjinIcons.family
                color: Platform.danger
                font.pixelSize: Platform.fontTitle + 8
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Couldn't load this page in the embed.")
                color: Platform.textPrimary
                font.pixelSize: Platform.fontBase
                font.bold: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Tap to open in your browser instead.")
                color: Platform.textMuted
                font.pixelSize: Platform.fontSmall
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: web.src
                color: Platform.accentDark
                font.pixelSize: Platform.fontSmall
                font.underline: true
                elide: Text.ElideMiddle
                Layout.maximumWidth: parent.width
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally(web.src)
                }
            }
        }
    }

    // ── Close button (only while playing) ─────────────────────────────────────
    // Lets the user return to the poster without destroying the surrounding
    // ContentBlock or scrolling away. Anchored to the top-right corner.
    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: Platform.spacingSm
            rightMargin: Platform.spacingSm
        }
        visible: web.playing
        width:  Math.round(Platform.touchTarget * 0.7)
        height: width
        radius: width / 2
        color: closeArea.containsMouse ? Platform.danger : Platform.mediaCloseBg
        border.color: Platform.textOnDark
        border.width: Platform.borderWidth
        z: 10

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: Platform.textOnDark
            font.pixelSize: Platform.fontBase
            font.bold: true
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // Unloads the WebView via Loader.active = false.
                web.playing = false
                web.loading = false
                web.failed  = false
            }
        }
    }
}

