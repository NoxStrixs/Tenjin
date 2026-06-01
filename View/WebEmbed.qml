import QtQuick
import QtWebEngine

// Isolated WebEngine view. Only compiled into the QML module when
// WEBVIEW_SUPPORT is enabled; ContentBlock.qml loads it by URL so this file's
// QtWebEngine import never affects builds without it.
WebEngineView {
    id: web
    property string url: ""
    onUrlChanged: if (url.length > 0) web.url = url
}

