#include <ViewModels/EntryViewModel.h>

#include <EntryService/EntryService.h>

#include <QByteArray>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>

namespace {
// Directory where imported media is stored: <AppData>/media
QString mediaDir()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return base + QStringLiteral("/media");
}
} // namespace

QString EntryViewModel::importMedia(const QString& sourceUrl)
{
    const QUrl url(sourceUrl);
    QString    srcPath = url.isLocalFile() ? url.toLocalFile()
                         : sourceUrl.startsWith(QStringLiteral("file:"))
                             ? QUrl(sourceUrl).toLocalFile()
                             : sourceUrl;

    QFile in(srcPath);
    if (!in.open(QIODevice::ReadOnly)) {
        emit errorOccurred(QStringLiteral("Cannot open media file: %1").arg(srcPath));
        return {};
    }

    const QFileInfo info(srcPath);
    const QString   baseName =
        info.completeBaseName().isEmpty() ? QStringLiteral("media") : info.completeBaseName();
    const QString suffix =
        info.suffix().isEmpty() ? QString() : QStringLiteral(".") + info.suffix();

    const QString dir = mediaDir();
    if (!QDir().mkpath(dir)) {
        emit errorOccurred(QStringLiteral("Could not create media directory."));
        in.close();
        return {};
    }

    QString fileName = baseName + suffix;
    QString dest     = dir + QStringLiteral("/") + fileName;
    for (int n = 1; QFile::exists(dest); n++) {
        fileName = QStringLiteral("%1_%2%3").arg(baseName).arg(n).arg(suffix);
        dest     = dir + QStringLiteral("/") + fileName;
    }

    QFile out(dest);
    if (!out.open(QIODevice::WriteOnly)) {
        emit errorOccurred(QStringLiteral("Failed to create destination file."));
        in.close();
        return {};
    }

    // Stream the copy so it works regardless of how the source URL is backed.
    constexpr qint64 chunk = 1 << 16;
    while (!in.atEnd()) {
        const QByteArray buf = in.read(chunk);
        if (buf.isEmpty() && !in.atEnd()) {
            emit errorOccurred(QStringLiteral("Failed to read media file."));
            in.close();
            out.close();
            QFile::remove(dest);
            return {};
        }
        if (out.write(buf) != buf.size()) {
            emit errorOccurred(QStringLiteral("Failed to write media file."));
            in.close();
            out.close();
            QFile::remove(dest);
            return {};
        }
    }
    in.close();
    out.close();

    // Store only the relative file name so the DB stays portable.
    return fileName;
}

QString EntryViewModel::resolveMediaUrl(const QString& storedPath) const
{
    if (storedPath.isEmpty())
        return {};

    if (storedPath.startsWith(QStringLiteral("file:")))
        return storedPath;

    QFileInfo info(storedPath);
    // Legacy absolute paths resolve directly.
    // Relative paths live in the media dir.
    const QString abs =
        info.isAbsolute() ? storedPath : mediaDir() + QStringLiteral("/") + storedPath;
    return QUrl::fromLocalFile(abs).toString();
}
