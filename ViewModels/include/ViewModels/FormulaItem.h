#pragma once

// FormulaItem — a QML item that renders LaTeX with real math typesetting.
//
// Why an item rather than a string: the previous renderer converted LaTeX into
// Qt rich text, which meant \frac{a}{b} could only ever be "a⁄b" — Qt's rich
// text has no math layout, so stacked fractions, radicals over an expression,
// and matrices are impossible. MicroTeX lays formulas out properly but draws
// through a painter, so the display has to be a painted item.
//
// Register in QML as `FormulaView` and give it `latex`, `color` and `fontSize`;
// it reports its natural size via implicitWidth/implicitHeight so layouts can
// size it like any other item.

#include <QColor>
#include <QQuickPaintedItem>
#include <QString>

#include <memory>

namespace Tenjin {

class FormulaItem : public QQuickPaintedItem
{
    Q_OBJECT
    // Registered explicitly with qmlRegisterType in main.cpp: ViewModels is a
    // plain static library, not a QML module, so QML_ELEMENT would do nothing.
    Q_PROPERTY(QString latex READ latex WRITE setLatex NOTIFY latexChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(qreal fontSize READ fontSize WRITE setFontSize NOTIFY fontSizeChanged)
    // Empty while the formula is valid; the parser error otherwise, so QML can
    // show the raw source with a hint instead of a blank box.
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    explicit FormulaItem(QQuickItem* parent = nullptr);
    ~FormulaItem() override;

    void paint(QPainter* painter) override;

    QString latex() const { return m_latex; }
    void    setLatex(const QString& v);

    QColor color() const { return m_color; }
    void   setColor(const QColor& v);

    qreal fontSize() const { return m_fontSize; }
    void  setFontSize(qreal v);

    QString errorString() const { return m_error; }

signals:
    void latexChanged();
    void colorChanged();
    void fontSizeChanged();
    void errorStringChanged();

private:
    void rebuild();
    void setError(const QString& e);

    QString m_latex;
    QColor  m_color    = Qt::black;
    qreal   m_fontSize = 20.0;
    QString m_error;

    // PIMPL: holds the MicroTeX TeXRender. Kept opaque so MicroTeX's headers
    // stay out of this public header — both to avoid leaking a third-party
    // include into everything that uses FormulaItem, and because the project
    // forbids class forward declarations (they break Qt's MOC).
    struct Impl;
    std::unique_ptr<Impl> d;
};

} // namespace Tenjin
