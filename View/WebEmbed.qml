import QtQuick
import QtWebView

// Cross-platform web/video embed using the system WebView (WKWebView on
// iOS/macOS, WebView2/WebKit elsewhere) — works on desktop AND mobile. Only
// compiled into the QML module when WEBVIEW_SUPPORT is enabled; ContentBlock.qml
// loads it by URL so this file's QtWebView import is never resolved otherwise.
WebView {
    id: web
    property string src: ""
    url: src.length > 0 ? src : ""
}

