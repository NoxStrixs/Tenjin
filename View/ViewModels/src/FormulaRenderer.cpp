#include "ViewModels/FormulaRenderer.h"

#include <QChar>
#include <QHash>
#include <QSet>

namespace Tenjin {

namespace {

// LaTeX command (without the backslash) to Unicode replacement.
// Covers:
//  - Greek
//  - common operators/relations
//  - arrows
//  - set symbols
const QHash<QString, QString>& commandTable()
{
    static const QHash<QString, QString> t = {
        // lowercase Greek
        {"alpha", "\u03B1"},
        {"beta", "\u03B2"},
        {"gamma", "\u03B3"},
        {"delta", "\u03B4"},
        {"epsilon", "\u03B5"},
        {"varepsilon", "\u03B5"},
        {"zeta", "\u03B6"},
        {"eta", "\u03B7"},
        {"theta", "\u03B8"},
        {"vartheta", "\u03D1"},
        {"iota", "\u03B9"},
        {"kappa", "\u03BA"},
        {"lambda", "\u03BB"},
        {"mu", "\u03BC"},
        {"nu", "\u03BD"},
        {"xi", "\u03BE"},
        {"pi", "\u03C0"},
        {"rho", "\u03C1"},
        {"sigma", "\u03C3"},
        {"tau", "\u03C4"},
        {"upsilon", "\u03C5"},
        {"phi", "\u03C6"},
        {"varphi", "\u03D5"},
        {"chi", "\u03C7"},
        {"psi", "\u03C8"},
        {"omega", "\u03C9"},
        // uppercase Greek
        {"Gamma", "\u0393"},
        {"Delta", "\u0394"},
        {"Theta", "\u0398"},
        {"Lambda", "\u039B"},
        {"Xi", "\u039E"},
        {"Pi", "\u03A0"},
        {"Sigma", "\u03A3"},
        {"Phi", "\u03A6"},
        {"Psi", "\u03A8"},
        {"Omega", "\u03A9"},
        // operators / big symbols
        {"sum", "\u2211"},
        {"prod", "\u220F"},
        {"int", "\u222B"},
        {"oint", "\u222E"},
        {"partial", "\u2202"},
        {"nabla", "\u2207"},
        {"infty", "\u221E"},
        {"pm", "\u00B1"},
        {"mp", "\u2213"},
        {"times", "\u00D7"},
        {"div", "\u00F7"},
        {"cdot", "\u00B7"},
        {"ast", "\u2217"},
        {"star", "\u22C6"},
        {"circ", "\u2218"},
        // relations
        {"leq", "\u2264"},
        {"le", "\u2264"},
        {"geq", "\u2265"},
        {"ge", "\u2265"},
        {"neq", "\u2260"},
        {"ne", "\u2260"},
        {"approx", "\u2248"},
        {"equiv", "\u2261"},
        {"sim", "\u223C"},
        {"propto", "\u221D"},
        {"ll", "\u226A"},
        {"gg", "\u226B"},
        // arrows
        {"to", "\u2192"},
        {"rightarrow", "\u2192"},
        {"leftarrow", "\u2190"},
        {"Rightarrow", "\u21D2"},
        {"Leftarrow", "\u21D0"},
        {"leftrightarrow", "\u2194"},
        {"Leftrightarrow", "\u21D4"},
        {"mapsto", "\u21A6"},
        {"uparrow", "\u2191"},
        {"downarrow", "\u2193"},
        // sets / logic
        {"in", "\u2208"},
        {"notin", "\u2209"},
        {"subset", "\u2282"},
        {"subseteq", "\u2286"},
        {"supset", "\u2283"},
        {"supseteq", "\u2287"},
        {"cup", "\u222A"},
        {"cap", "\u2229"},
        {"emptyset", "\u2205"},
        {"forall", "\u2200"},
        {"exists", "\u2203"},
        {"neg", "\u00AC"},
        {"land", "\u2227"},
        {"lor", "\u2228"},
        {"mathbb{R}", "\u211D"},
        {"mathbb{N}", "\u2115"},
        {"mathbb{Z}", "\u2124"},
        {"mathbb{Q}", "\u211A"},
        {"mathbb{C}", "\u2102"},
        // dots / misc
        {"ldots", "\u2026"},
        {"cdots", "\u22EF"},
        {"dots", "\u2026"},
        {"angle", "\u2220"},
        {"degree", "\u00B0"},
        {"deg", "\u00B0"},
        {"prime", "\u2032"},
        {"hbar", "\u210F"},
        {"ell", "\u2113"},
        // named functions render upright; map to themselves (handled below)
    };
    return t;
}

// Functions that should render as upright literal text (sin, cos, log, …).
bool isNamedFunction(const QString& cmd)
{
    static const QSet<QString> fns = {
        "sin",  "cos",  "tan",  "cot", "sec", "csc", "arcsin", "arccos", "arctan",
        "sinh", "cosh", "tanh", "log", "ln",  "lg",  "exp",    "lim",    "min",
        "max",  "gcd",  "det",  "dim", "ker", "deg", "arg",
    };
    return fns.contains(cmd);
}

QString escapeHtml(const QString& s)
{
    QString out;
    out.reserve(s.size());
    for (QChar c : s) {
        switch (c.unicode()) {
        case '&':
            out += "&amp;";
            break;
        case '<':
            out += "&lt;";
            break;
        case '>':
            out += "&gt;";
            break;
        default:
            out += c;
            break;
        }
    }
    return out;
}

// Forward declaration: the core recursive converter.
QString convert(const QString& in);

// Read a {...}-delimited group starting at in[i] == '{'. Returns the inner text
// (converted) and advances i past the closing '}'. If the char isn't '{', reads
// a single token (one char, or one \command) instead — matches LaTeX's "next
// group or next token" argument rule for ^, _, \sqrt, \frac.
QString readArg(const QString& in, int& i)
{
    if (i >= in.size())
        return QString();

    if (in[i] == '{') {
        int depth = 0;
        int start = i + 1;
        for (; i < in.size(); i++) {
            if (in[i] == '{')
                depth++;
            else if (in[i] == '}') {
                if (--depth == 0) {
                    QString inner = in.mid(start, i - start);
                    i++; // consume '}'
                    return convert(inner);
                }
            }
        }
        // Unbalanced: take the rest.
        return convert(in.mid(start));
    }

    if (in[i] == '\\') {
        // A single command token, e.g. x^\alpha.
        int start = i++;
        while (i < in.size() && in[i].isLetter())
            i++;
        return convert(in.mid(start, i - start));
    }

    // A single character.
    QString one = in.mid(i, 1);
    i++;
    return escapeHtml(one);
}

// Wrap a script body in parentheses if it's "compound" (more than one visible
// glyph after stripping tags) so x^{a+b} reads x^(a+b), not x^a+b.
QString maybeParen(const QString& body)
{
    // Count characters outside tags.
    int  visible = 0;
    bool inTag   = false;
    for (QChar c : body) {
        if (c == '<')
            inTag = true;
        else if (c == '>')
            inTag = false;
        else if (!inTag)
            visible++;
    }
    return visible > 1 ? "(" + body + ")" : body;
}

QString convert(const QString& in)
{
    QString   out;
    int       i = 0;
    const int n = in.size();

    while (i < n) {
        const QChar c = in[i];

        // Superscript / subscript.
        if (c == '^' || c == '_') {
            i++;
            QString     arg = readArg(in, i);
            const char* tag = (c == '^') ? "sup" : "sub";
            out += QString("<%1>%2</%1>").arg(tag, maybeParen(arg));
            continue;
        }

        // Command.
        if (c == '\\') {
            i++;
            if (i >= n)
                break;

            // Escaped specials and spacing commands.
            const QChar nx = in[i];
            if (nx == ',' || nx == ';' || nx == ' ' || nx == '!' || nx == ':') {
                // thin/med spaces and negative space -> a normal space (or none)
                out += (nx == '!') ? "" : " ";
                i++;
                continue;
            }
            if (nx == '{' || nx == '}' || nx == '%' || nx == '$' || nx == '#' || nx == '&' ||
                nx == '_') {
                out += escapeHtml(QString(nx));
                i++;
                continue;
            }
            if (nx == '\\') { // line break
                out += "<br/>";
                i++;
                continue;
            }

            // \frac{a}{b}
            // Read the command name.
            int start = i;
            while (i < n && in[i].isLetter())
                i++;
            QString cmd = in.mid(start, i - start);

            if (cmd == "frac" || cmd == "dfrac" || cmd == "tfrac") {
                QString num = readArg(in, i);
                QString den = readArg(in, i);
                out += maybeParen(num) + "\u2044" + maybeParen(den); // fraction slash
                continue;
            }
            if (cmd == "sqrt") {
                // Optional [n] index is ignored for simplicity.
                if (i < n && in[i] == '[') {
                    while (i < n && in[i] != ']')
                        i++;
                    if (i < n)
                        i++; // skip ']'
                }
                QString rad = readArg(in, i);
                out += "\u221A(" + rad + ")";
                continue;
            }
            if (cmd == "text" || cmd == "mathrm" || cmd == "operatorname") {
                out += readArg(in, i); // already escaped+converted
                continue;
            }
            if (cmd == "left" || cmd == "right") {
                // Drop the sizing command; the following delimiter stays.
                continue;
            }

            // \mathbb{R} style — try the table with the brace arg appended.
            if (cmd == "mathbb" && i < n && in[i] == '{') {
                int save = i;
                // peek the single-letter group
                if (i + 2 < n && in[i + 2] == '}') {
                    QString key = "mathbb{" + QString(in[i + 1]) + "}";
                    auto    it  = commandTable().find(key);
                    if (it != commandTable().end()) {
                        out += it.value();
                        i += 3;
                        continue;
                    }
                }
                i = save;
            }

            if (isNamedFunction(cmd)) {
                out += escapeHtml(cmd); // upright, literal
                continue;
            }

            auto it = commandTable().find(cmd);
            if (it != commandTable().end()) {
                out += it.value();
                continue;
            }

            // Unknown command: render its name literally (without backslash).
            out += escapeHtml(cmd);
            continue;
        }

        // Bare braces are grouping only — strip but convert contents inline.
        if (c == '{') {
            // Treat as a transparent group.
            i++;
            int depth = 1, startInner = i;
            while (i < n && depth > 0) {
                if (in[i] == '{')
                    depth++;
                else if (in[i] == '}')
                    depth--;
                if (depth > 0)
                    i++;
            }
            out += convert(in.mid(startInner, i - startInner));
            if (i < n)
                i++; // skip '}'
            continue;
        }
        if (c == '}') {
            i++;
            continue;
        }

        if (c == '~') {
            out += " ";
            i++;
            continue;
        } // non-breaking space -> space

        out += escapeHtml(QString(c));
        i++;
    }

    return out;
}

} // namespace

QString FormulaRenderer::toRichText(const QString& latex)
{
    if (latex.trimmed().isEmpty())
        return QString();
    return convert(latex);
}

} // namespace Tenjin
