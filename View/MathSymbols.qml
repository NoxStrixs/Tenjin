pragma Singleton
import QtQuick

// Catalog of LaTeX snippets for the formula editor's symbol picker, grouped by
// category and tagged with search keywords. `$1` in a snippet marks where the
// caret should land after insertion (see FormulaBlock.insertSnippet).
//
// Kept as a singleton so both the inline quick row and the categorized popup
// draw from one source, and so it can be reused if a second formula surface is
// added later.
QtObject {
    // Each category: { name, key, items: [{ label, snippet, keywords }] }.
    // `label` is what the button shows (the rendered glyph or a short tag);
    // `keywords` drives search (space-separated, lowercase).
    readonly property var categories: [
        {
            "name": qsTr("Common"),
            "key": "common",
            "items": [
                { "label": "x\u00B2",  "snippet": "^{$1}",              "keywords": "power superscript exponent" },
                { "label": "x\u2082",  "snippet": "_{$1}",              "keywords": "subscript index" },
                { "label": "a/b",       "snippet": "\\frac{$1}{}",       "keywords": "fraction frac divide ratio" },
                { "label": "\u221A",    "snippet": "\\sqrt{$1}",         "keywords": "square root sqrt radical" },
                { "label": "\u207F\u221A", "snippet": "\\sqrt[$1]{}",    "keywords": "nth root radical" },
                { "label": "\u222B",    "snippet": "\\int_{$1}^{} \\, dx", "keywords": "integral int calculus" },
                { "label": "\u2211",    "snippet": "\\sum_{$1}^{}",      "keywords": "sum sigma series summation" },
                { "label": "\u220F",    "snippet": "\\prod_{$1}^{}",     "keywords": "product prod pi" },
                { "label": "lim",       "snippet": "\\lim_{$1 \\to }",   "keywords": "limit lim calculus" }
            ]
        },
        {
            "name": qsTr("Greek"),
            "key": "greek",
            "items": [
                { "label": "\u03B1", "snippet": "\\alpha",   "keywords": "alpha greek" },
                { "label": "\u03B2", "snippet": "\\beta",    "keywords": "beta greek" },
                { "label": "\u03B3", "snippet": "\\gamma",   "keywords": "gamma greek" },
                { "label": "\u03B4", "snippet": "\\delta",   "keywords": "delta greek" },
                { "label": "\u03B5", "snippet": "\\epsilon", "keywords": "epsilon greek" },
                { "label": "\u03B6", "snippet": "\\zeta",    "keywords": "zeta greek" },
                { "label": "\u03B7", "snippet": "\\eta",     "keywords": "eta greek" },
                { "label": "\u03B8", "snippet": "\\theta",   "keywords": "theta greek" },
                { "label": "\u03BB", "snippet": "\\lambda",  "keywords": "lambda greek" },
                { "label": "\u03BC", "snippet": "\\mu",      "keywords": "mu greek micro" },
                { "label": "\u03C0", "snippet": "\\pi",      "keywords": "pi greek" },
                { "label": "\u03C1", "snippet": "\\rho",     "keywords": "rho greek" },
                { "label": "\u03C3", "snippet": "\\sigma",   "keywords": "sigma greek" },
                { "label": "\u03C4", "snippet": "\\tau",     "keywords": "tau greek" },
                { "label": "\u03C6", "snippet": "\\phi",     "keywords": "phi greek" },
                { "label": "\u03C7", "snippet": "\\chi",     "keywords": "chi greek" },
                { "label": "\u03C8", "snippet": "\\psi",     "keywords": "psi greek" },
                { "label": "\u03C9", "snippet": "\\omega",   "keywords": "omega greek" },
                { "label": "\u0393", "snippet": "\\Gamma",   "keywords": "gamma greek capital uppercase" },
                { "label": "\u0394", "snippet": "\\Delta",   "keywords": "delta greek capital uppercase change" },
                { "label": "\u0398", "snippet": "\\Theta",   "keywords": "theta greek capital uppercase" },
                { "label": "\u039B", "snippet": "\\Lambda",  "keywords": "lambda greek capital uppercase" },
                { "label": "\u03A0", "snippet": "\\Pi",      "keywords": "pi greek capital uppercase" },
                { "label": "\u03A3", "snippet": "\\Sigma",   "keywords": "sigma greek capital uppercase" },
                { "label": "\u03A6", "snippet": "\\Phi",     "keywords": "phi greek capital uppercase" },
                { "label": "\u03A9", "snippet": "\\Omega",   "keywords": "omega greek capital uppercase ohm" }
            ]
        },
        {
            "name": qsTr("Operators"),
            "key": "operators",
            "items": [
                { "label": "\u00D7", "snippet": "\\times",  "keywords": "times multiply cross product" },
                { "label": "\u00F7", "snippet": "\\div",    "keywords": "divide division" },
                { "label": "\u00B1", "snippet": "\\pm",     "keywords": "plus minus plusminus" },
                { "label": "\u2213", "snippet": "\\mp",     "keywords": "minus plus" },
                { "label": "\u2219", "snippet": "\\cdot",   "keywords": "dot multiply cdot" },
                { "label": "\u2217", "snippet": "\\ast",    "keywords": "asterisk star convolution" },
                { "label": "\u2295", "snippet": "\\oplus",  "keywords": "oplus xor direct sum" },
                { "label": "\u2297", "snippet": "\\otimes", "keywords": "otimes tensor kronecker" },
                { "label": "\u221A", "snippet": "\\sqrt{$1}", "keywords": "root sqrt" },
                { "label": "\u2207", "snippet": "\\nabla",  "keywords": "nabla del gradient divergence" },
                { "label": "\u2202", "snippet": "\\partial", "keywords": "partial derivative" },
                { "label": "\u221E", "snippet": "\\infty",  "keywords": "infinity infinite" }
            ]
        },
        {
            "name": qsTr("Relations"),
            "key": "relations",
            "items": [
                { "label": "\u2264", "snippet": "\\leq",     "keywords": "less than equal leq" },
                { "label": "\u2265", "snippet": "\\geq",     "keywords": "greater than equal geq" },
                { "label": "\u2260", "snippet": "\\neq",     "keywords": "not equal neq" },
                { "label": "\u2248", "snippet": "\\approx",  "keywords": "approximately approx" },
                { "label": "\u2261", "snippet": "\\equiv",   "keywords": "equivalent identical equiv" },
                { "label": "\u221D", "snippet": "\\propto",  "keywords": "proportional propto" },
                { "label": "\u2208", "snippet": "\\in",      "keywords": "element in member set" },
                { "label": "\u2209", "snippet": "\\notin",   "keywords": "not in element set" },
                { "label": "\u2282", "snippet": "\\subset",  "keywords": "subset" },
                { "label": "\u2286", "snippet": "\\subseteq", "keywords": "subset equal" },
                { "label": "\u222A", "snippet": "\\cup",     "keywords": "union cup set" },
                { "label": "\u2229", "snippet": "\\cap",     "keywords": "intersection cap set" }
            ]
        },
        {
            "name": qsTr("Arrows"),
            "key": "arrows",
            "items": [
                { "label": "\u2192", "snippet": "\\to",            "keywords": "to right arrow" },
                { "label": "\u2190", "snippet": "\\leftarrow",     "keywords": "left arrow" },
                { "label": "\u2194", "snippet": "\\leftrightarrow", "keywords": "left right arrow bidirectional" },
                { "label": "\u21D2", "snippet": "\\Rightarrow",    "keywords": "implies right double arrow" },
                { "label": "\u21D0", "snippet": "\\Leftarrow",     "keywords": "left double arrow" },
                { "label": "\u21D4", "snippet": "\\Leftrightarrow", "keywords": "iff if and only if double arrow" },
                { "label": "\u21A6", "snippet": "\\mapsto",        "keywords": "maps to mapsto function" },
                { "label": "\u2191", "snippet": "\\uparrow",       "keywords": "up arrow" },
                { "label": "\u2193", "snippet": "\\downarrow",     "keywords": "down arrow" }
            ]
        },
        {
            "name": qsTr("Calculus"),
            "key": "calculus",
            "items": [
                { "label": "\u222B",       "snippet": "\\int_{$1}^{} \\, dx",   "keywords": "integral definite" },
                { "label": "\u222C",       "snippet": "\\iint_{$1} \\, dA",     "keywords": "double integral" },
                { "label": "\u222E",       "snippet": "\\oint_{$1} \\, ds",     "keywords": "contour integral line" },
                { "label": "\u2211",       "snippet": "\\sum_{$1}^{}",          "keywords": "sum series" },
                { "label": "\u220F",       "snippet": "\\prod_{$1}^{}",         "keywords": "product" },
                { "label": "lim",          "snippet": "\\lim_{$1 \\to }",       "keywords": "limit" },
                { "label": "d/dx",         "snippet": "\\frac{d}{dx}$1",        "keywords": "derivative differential" },
                { "label": "\u2202/\u2202x", "snippet": "\\frac{\\partial}{\\partial x}$1", "keywords": "partial derivative" },
                { "label": "\u2207",       "snippet": "\\nabla",                "keywords": "gradient nabla del" }
            ]
        },
        {
            "name": qsTr("Structures"),
            "key": "structures",
            "items": [
                { "label": "a/b",       "snippet": "\\frac{$1}{}",        "keywords": "fraction" },
                { "label": "()",        "snippet": "\\left($1\\right)",   "keywords": "parentheses brackets auto sizing" },
                { "label": "[]",        "snippet": "\\left[$1\\right]",   "keywords": "square brackets" },
                { "label": "{}",        "snippet": "\\left\\{$1\\right\\}", "keywords": "curly braces set" },
                { "label": "|x|",       "snippet": "\\left|$1\\right|",   "keywords": "absolute value modulus norm" },
                { "label": "x\u0302",   "snippet": "\\hat{$1}",           "keywords": "hat unit vector estimate" },
                { "label": "x\u0304",   "snippet": "\\bar{$1}",           "keywords": "bar mean average conjugate" },
                { "label": "x\u20D7",   "snippet": "\\vec{$1}",           "keywords": "vector arrow" },
                { "label": "x\u0307",   "snippet": "\\dot{$1}",           "keywords": "dot derivative time" },
                { "label": "\u2308\u2309", "snippet": "\\lceil $1 \\rceil", "keywords": "ceiling" },
                { "label": "\u230A\u230B", "snippet": "\\lfloor $1 \\rfloor", "keywords": "floor" },
                { "label": "(matrix)",  "snippet": "\\begin{pmatrix} $1 & \\\\ & \\end{pmatrix}", "keywords": "matrix pmatrix grid" },
                { "label": "cases",     "snippet": "\\begin{cases} $1 & \\\\ & \\end{cases}", "keywords": "cases piecewise system" }
            ]
        }
    ]

    // Flatten all items into one list, each tagged with its category name, for
    // search. Computed once (readonly binding) rather than per-keystroke.
    readonly property var allItems: {
        let out = []
        for (let c = 0; c < categories.length; ++c) {
            const cat = categories[c]
            for (let i = 0; i < cat.items.length; ++i) {
                const it = cat.items[i]
                out.push({
                    "label": it.label,
                    "snippet": it.snippet,
                    "keywords": it.keywords,
                    "category": cat.name
                })
            }
        }
        return out
    }

    // Case-insensitive keyword search. Returns the items whose keywords or label
    // contain every whitespace-separated term in `query` (AND semantics), so
    // "greek pi" narrows to the Greek pi rather than every pi-ish symbol.
    function search(query) {
        const q = (query || "").trim().toLowerCase()
        if (q.length === 0)
            return []
        const terms = q.split(/\s+/)
        return allItems.filter(function (it) {
            const hay = (it.keywords + " " + it.label + " " + it.category).toLowerCase()
            for (let t = 0; t < terms.length; ++t)
                if (hay.indexOf(terms[t]) === -1)
                    return false
            return true
        })
    }
}
