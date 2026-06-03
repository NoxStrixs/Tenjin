#pragma once

#include <QString>

namespace Tenjin {

// Converts a small, practical subset of LaTeX into Qt rich text (the HTML-ish
// markup understood by QML Text with textFormat: RichText). Pure, offline, and
// dependency-free — no WebView, no KaTeX, no network. Suitable for the inline
// math a vocabulary app needs:
//
//   superscripts   x^2      x^{12}        -> x<sup>2</sup>, x<sup>12</sup>
//   subscripts     H_2      a_{ij}        -> H<sub>2</sub>, a<sub>ij</sub>
//   fractions      \frac{a}{b}            -> a&frasl;b  (inline, parenthesised
//                                            when either side is compound)
//   roots          \sqrt{x}               -> &radic;(x)
//   commands       \alpha \sum \to \leq … -> Unicode glyphs
//   spacing/braces \, \; \! ~ and bare {} -> handled/stripped
//
// Anything unrecognised is passed through (HTML-escaped) so the result is always
// legible even for input outside the supported subset.
class FormulaRenderer
{
public:
    // Returns rich text. Safe on empty input (returns empty string).
    static QString toRichText(const QString& latex);
};

} // namespace Tenjin
