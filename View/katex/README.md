# KaTeX offline assets (vendored, not committed)

This directory holds the KaTeX distribution used for offline LaTeX formula
rendering. The files are **not** checked into the repo — fetch them once:

    tools/fetch-katex.sh

That populates:

    katex/katex.min.js
    katex/katex.min.css
    katex/fonts/*

The View/CMakeLists.txt qrc resource bundles whatever is here into the binary
(under qrc:/katex) when FORMULA_SUPPORT is ON. If this directory is empty,
configure still succeeds (with a warning) and formulas use the text fallback.
