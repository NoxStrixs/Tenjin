pragma ComponentBehavior: Bound

import QtQuick
import QtWebView
import TenjinView

// Renders a LaTeX string with KaTeX inside the system WebView (WKWebView on
// iOS/macOS, WebView2/WebKit elsewhere) — NOT QtWebEngine, so it works on iOS
// and adds almost no binary weight. Kept in its own file so the QtWebView
// import only resolves when FORMULA_SUPPORT is compiled in (FormulaBlock gates
// instantiation behind a Loader on appVM.formulaRenderingAvailable).
//
// KaTeX assets are bundled offline under qrc:/katex (populated by
// tools/fetch-katex.sh). If the bundle is missing at runtime the KaTeX <script>
// simply fails and we fall back to showing the raw LaTeX text inside the page,
// so nothing crashes.
Item {
    id: root
    property string latex: ""

    implicitHeight: web.formulaHeight

    // Escape the LaTeX for safe embedding in a JS single-quoted string literal.
    function jsEscape(s) {
        return s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\n/g, " ")
    }

    // Offline KaTeX from the bundled qrc resource.
    readonly property string katexBase: "qrc:/katex"

    readonly property string html:
        "<!DOCTYPE html><html><head><meta charset='utf-8'>" +
        "<meta name='viewport' content='width=device-width, initial-scale=1'>" +
        "<link rel='stylesheet' href='" + katexBase + "/katex.min.css'>" +
        "<script defer src='" + katexBase + "/katex.min.js'></script>" +
        "<style>html,body{margin:0;padding:6px;background:transparent;" +
        "color:" + Platform.textPrimary + ";font-size:18px;overflow:hidden}</style></head>" +
        "<body><span id='f'></span>" +
        "<script>window.addEventListener('load',function(){" +
        "try{katex.render('" + jsEscape(root.latex) + "',document.getElementById('f')," +
        "{displayMode:true,throwOnError:false});}catch(e){" +
        "document.getElementById('f').textContent='" + jsEscape(root.latex) + "';}" +
        "});</script></body></html>"

    WebView {
        id: web
        anchors.fill: parent

        property real formulaHeight: 48

        function reload() { loadHtml(root.html, "qrc:/") }
        Component.onCompleted: reload()

        // Measure rendered height so the block sizes to its content.
        onLoadingChanged: function (req) {
            if (req.status === WebView.LoadSucceededStatus) {
                runJavaScript("document.body.scrollHeight", function (h) {
                    if (h && h > 0) web.formulaHeight = h
                })
            }
        }
    }

    // Re-render when the source changes while mounted (single handler).
    onLatexChanged: web.reload()
}
