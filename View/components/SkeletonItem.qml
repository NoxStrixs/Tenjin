import QtQuick
import TenjinView

// SkeletonItem — an animated shimmer placeholder shown while content loads.
// Use a column of these in a list while data is being fetched, then swap them
// for the real delegates once the model populates.
//
// Usage:
//   Column {
//       Repeater {
//           model: 6
//           SkeletonItem { width: parent.width; height: 56 }
//       }
//   }
Rectangle {
    id: skel
    radius: Platform.radius
    color: Platform.surfaceAlt
    clip: true

    // Moving highlight band that sweeps left→right.
    Rectangle {
        id: band
        height: parent.height
        width: parent.width * 0.4
        rotation: 12
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, Platform.isDark ? 0.06 : 0.35) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        x: -width
        SequentialAnimation on x {
            loops: Animation.Infinite
            running: skel.visible
            NumberAnimation {
                from: -band.width
                to:   skel.width + band.width
                duration: 1100
                easing.type: Easing.InOutQuad
            }
            PauseAnimation { duration: 350 }
        }
    }
}
