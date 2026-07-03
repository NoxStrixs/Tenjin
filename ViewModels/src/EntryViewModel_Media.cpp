#include <ViewModels/EntryViewModel.h>

#include <EntryService/EntryService.h>

#include <QByteArray>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QSysInfo>
#include <QUrl>

namespace {

// Directory for Tenjin-managed media copies: <AppData>/media
// Files here are owned by the app. External links stored as absolute
// paths bypass this directory entirely.
QString mediaDir()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return base + QStringLiteral("/media");
}

// Sandboxed platforms can't reliably keep external file references --
// the OS moves files around (Files.app on iOS) or revokes access
// (Android scoped storage). Always copy on these. Desktop platforms
// link in place by default.
bool platformPrefersCopy()
{
#if defined(Q_OS_IOS) || defined(Q_OS_ANDROID)
    return true;
#else
    return false;
#endif
}

// SHA-256 of the file's contents, used for content-addressable
// deduplication. Streamed in 1MB chunks so we don't load big media
// into memory.
QByteArray hashFile(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    QCryptographicHash h(QCryptographicHash::Sha256);
    if (!h.addData(&f))
        return {};
    return h.result().toHex();
}

// Resolve a stored content string to a real path on disk. Mirrors
// resolveMediaUrl's logic so cleanup can stat the file.
QString storedToAbsolute(const QString& stored)
{
    if (stored.isEmpty())
        return {};
    if (stored.startsWith(QStringLiteral("file:")))
        return QUrl(stored).toLocalFile();
    const QFileInfo info(stored);
    if (info.isAbsolute())
        return stored;
    return mediaDir() + QStringLiteral("/") + stored;
}

// True if the stored string points into Tenjin's managed media dir
// (i.e. it's a copy we made, not an external link). Cleanup is only
// safe for these -- we never delete files outside our own dir.
bool isManagedCopy(const QString& stored)
{
    if (stored.isEmpty())
        return false;
    const QFileInfo info(stored);
    // Plain relative filename -> by definition managed.
    if (!info.isAbsolute() && !stored.startsWith(QStringLiteral("file:")))
        return true;
    // Absolute path: managed iff it lives under mediaDir().
    const QString abs = storedToAbsolute(stored);
    return abs.startsWith(mediaDir() + QStringLiteral("/"));
}

} // namespace

QString EntryViewModel::importMedia(const QString& sourceUrl)
{
    // -- 1. Resolve input to a local filesystem path -------------------
    QString srcPath;
    if (sourceUrl.startsWith(QStringLiteral("file:")))
        srcPath = QUrl(sourceUrl).toLocalFile();
    else
        srcPath = sourceUrl;

    if (srcPath.isEmpty()) {
        emit errorOccurred(QStringLiteral("Empty media path."));
        return {};
    }

    const QFileInfo info(srcPath);
    if (!info.exists() || !info.isReadable()) {
        emit errorOccurred(QStringLiteral("Cannot read media file: %1").arg(srcPath));
        return {};
    }

    // -- 2. Already under our media dir? Use the relative name as-is.
    // The user re-picked a file they've already imported; no copy
    // needed, no new DB entry needed -- the stored filename Just Works.
    const QString absSrc = info.absoluteFilePath();
    const QString mDir   = QDir(mediaDir()).absolutePath();
    if (absSrc.startsWith(mDir + QStringLiteral("/"))) {
        return absSrc.mid(mDir.length() + 1);
    }

    // -- 3. Desktop: link in place. -------------------------------------
    // Store the absolute path; resolveMediaUrl will turn it into a
    // file:// URL at read time. No bytes copied, no disk used. This
    // is the common path on Linux/macOS/Windows where the user
    // typically wants their library left intact (videos in a movies
    // folder, images in a pictures folder, etc.).
    //
    // We skip linking on iOS/Android where the source path is likely
    // a sandbox-scoped URL that won't be valid on the next launch.
    if (!platformPrefersCopy()) {
        return absSrc;
    }

    // -- 4. Mobile: copy, with content-hash deduplication. -------------
    // Hash the source. If a file with the same hash already lives in
    // our media dir, reuse it -- the user picked the same audio clip
    // twice from Files.app and we don't need two copies.
    const QByteArray srcHash = hashFile(srcPath);
    if (!srcHash.isEmpty()) {
        QDir d(mediaDir());
        if (d.exists()) {
            const auto entries = d.entryInfoList(QDir::Files | QDir::Readable);
            for (const QFileInfo& fi : entries) {
                if (hashFile(fi.absoluteFilePath()) == srcHash)
                    return fi.fileName(); // dedup hit
            }
        }
    }

    // -- 5. New file. Pick a non-colliding name and copy. --------------
    const QString baseName =
        info.completeBaseName().isEmpty() ? QStringLiteral("media") : info.completeBaseName();
    const QString suffix =
        info.suffix().isEmpty() ? QString() : QStringLiteral(".") + info.suffix();

    if (!QDir().mkpath(mediaDir())) {
        emit errorOccurred(QStringLiteral("Could not create media directory."));
        return {};
    }

    QString fileName = baseName + suffix;
    QString dest     = mediaDir() + QStringLiteral("/") + fileName;
    for (int n = 1; QFile::exists(dest); n++) {
        fileName = QStringLiteral("%1_%2%3").arg(baseName).arg(n).arg(suffix);
        dest     = mediaDir() + QStringLiteral("/") + fileName;
    }

    // QFile::copy is implemented as sendfile() / CopyFileEx() /
    // copyfile() on the major platforms. Much faster than the userland
    // chunk loop we had before, and avoids the multi-second UI freeze
    // on multi-MB imports.
    if (!QFile::copy(srcPath, dest)) {
        emit errorOccurred(QStringLiteral("Failed to copy media file to %1").arg(dest));
        return {};
    }
    return fileName;
}

QString EntryViewModel::resolveMediaUrl(const QString& storedPath) const
{
    if (storedPath.isEmpty())
        return {};

    if (storedPath.startsWith(QStringLiteral("file:")))
        return storedPath;

    const QFileInfo info(storedPath);
    const QString   abs =
        info.isAbsolute() ? storedPath : mediaDir() + QStringLiteral("/") + storedPath;
    return QUrl::fromLocalFile(abs).toString();
}

void EntryViewModel::cleanupOrphanedMedia(const QString& storedPath)
{
    // Called when a media block (or an entry containing media blocks)
    // is removed. We delete the file ONLY if:
    //   1. It's a Tenjin-managed copy (lives under mediaDir(), not an
    //      external link), AND
    //   2. No other content block references it.
    //
    // Rule (1) protects the user's existing files when they used the
    // desktop link-in-place path. Rule (2) handles dedup correctly --
    // a single managed file can be referenced by N blocks, and we
    // only remove it when the last reference is gone.

    if (storedPath.isEmpty() || !isManagedCopy(storedPath))
        return;

    // Count remaining references across all entries' content blocks.
    // We compare on the stored string verbatim -- the dedup logic in
    // importMedia ensures duplicates share the same filename string.
    auto refs = m_entryService->CountMediaReferences(storedPath.toStdString());
    if (!refs) {
        // Soft-fail: better to leak a media file than to throw a
        // user-visible error during a delete.
        return;
    }
    if (*refs > 0)
        return; // still in use

    const QString abs = storedToAbsolute(storedPath);
    if (abs.isEmpty() || !abs.startsWith(QDir(mediaDir()).absolutePath() + QStringLiteral("/")))
        return; // safety belt -- never delete outside our dir

    QFile::remove(abs);
}
