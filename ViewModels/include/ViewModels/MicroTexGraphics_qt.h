#pragma once

// MicroTeX -> QPainter bridge.
//
// MicroTeX parses LaTeX into a box model and issues drawing calls through the
// abstract tex::Graphics2D interface; this supplies the Qt implementation, so
// formulas render with the same painter (and thus the same DPI/theme handling)
// as the rest of the app.
//
// Contract notes taken from MicroTeX's graphic.h:
//   * tex::color is a uint32 ARGB value (0xAARRGGBB).
//   * drawChar/drawText are BASELINE aligned, not top-left.
//   * Scaling on the y-direction is authoritative when x/y scales differ.
//   * Font/TextLayout are abstract with static factories that the host must
//     define (tex::Font::create, tex::Font::_create, tex::TextLayout::create) —
//     those live in MicroTexGraphics_qt.cpp.

#include <QFont>
#include <QPainter>
#include <QString>

#include "graphic/graphic.h"

// MicroTeX's tex::TextLayout and tex::Graphics2D abstract bases have no virtual
// destructor (an upstream oversight in vendored headers we can't edit). Our
// subclasses are either stack-allocated (QtGraphics2D) or owned via shared_ptr
// (QtTextLayout/QtFont) — and shared_ptr stores a type-erased deleter that
// destroys the concrete type regardless of the base's dtor — so no object is
// ever destroyed through a base pointer with a non-virtual dtor. The warning is
// therefore a false positive here; silence it narrowly rather than leave noise
// on every build. (tex::Font DOES declare a virtual dtor, so QtFont is fine, but
// the pragma spans all three for simplicity.)
#if defined(__GNUC__) || defined(__clang__)
#  pragma GCC diagnostic push
#  pragma GCC diagnostic ignored "-Wnon-virtual-dtor"
#endif

namespace tenjin {

// Wraps a QFont so MicroTeX can carry it through its box model.
class QtFont final : public tex::Font
{
public:
    QtFont(QString family, int style, float size);
    explicit QtFont(const QFont& f);

    float             getSize() const override;
    tex::sptr<tex::Font> deriveFont(int style) const override;
    bool              operator==(const tex::Font& f) const override;
    bool              operator!=(const tex::Font& f) const override;

    const QFont& qfont() const { return m_font; }

private:
    QFont m_font;
    float m_size = 0.f;
};

// Lays out text MicroTeX doesn't recognize (e.g. CJK) using Qt's shaper.
class QtTextLayout final : public tex::TextLayout
{
public:
    QtTextLayout(const std::wstring& src, const tex::sptr<tex::Font>& font);

    void getBounds(tex::Rect& bounds) override;
    void draw(tex::Graphics2D& g2, float x, float y) override;

private:
    QString m_text;
    QFont   m_font;
};

// The Graphics2D implementation. Construct around an active QPainter; MicroTeX
// then drives it via TeXRender::draw(g2, x, y).
class QtGraphics2D final : public tex::Graphics2D
{
public:
    explicit QtGraphics2D(QPainter* painter);

    void              setColor(tex::color c) override;
    tex::color        getColor() const override;
    void              setStroke(const tex::Stroke& s) override;
    const tex::Stroke& getStroke() const override;
    void              setStrokeWidth(float w) override;
    const tex::Font*  getFont() const override;
    void              setFont(const tex::Font* font) override;

    void  translate(float dx, float dy) override;
    void  scale(float sx, float sy) override;
    void  rotate(float angle) override;
    void  rotate(float angle, float px, float py) override;
    void  reset() override;
    float sx() const override;
    float sy() const override;

    void drawChar(wchar_t c, float x, float y) override;
    void drawText(const std::wstring& c, float x, float y) override;
    void drawLine(float x1, float y1, float x2, float y2) override;
    void drawRect(float x, float y, float w, float h) override;
    void fillRect(float x, float y, float w, float h) override;
    void drawRoundRect(float x, float y, float w, float h, float rx, float ry) override;
    void fillRoundRect(float x, float y, float w, float h, float rx, float ry) override;

private:
    void applyPen();

    QPainter*        m_painter = nullptr;
    tex::color       m_color   = tex::black;
    tex::Stroke      m_stroke;
    const tex::Font* m_font    = nullptr;
    // Tracked separately: QTransform can't be decomposed back into the scale
    // MicroTeX expects from sx()/sy() once rotation is involved.
    float m_sx = 1.f;
    float m_sy = 1.f;
};

} // namespace tenjin

#if defined(__GNUC__) || defined(__clang__)
#  pragma GCC diagnostic pop
#endif
