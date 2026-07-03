import QtQuick
import TenjinView

// A space-separated row of flag SVGs for a language. `codes` is a pre-resolved
// list of ISO-3166 alpha-2 codes (from LanguageFlags). Flags render from the
// bundled lipis/flag-icons SVGs via Qt6::Svg. Images load asynchronously and
// the row collapses to zero width when `codes` is empty (custom languages with
// no flag), so it is safe to place unconditionally in a delegate.
Row {
    id: root
    property var codes: []
    spacing: 4
    visible: codes.length > 0

    Repeater {
        model: root.codes
        delegate: Image {
            required property string modelData
            source: "qrc:/qt/qml/TenjinView/flags/" + modelData + ".svg"
            sourceSize.width: Math.round(Platform.fontBase * 1.4)
            sourceSize.height: Platform.fontBase
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            // Hide broken/missing flag silently rather than show an error icon.
            onStatusChanged: if (status === Image.Error) visible = false
        }
    }
}
