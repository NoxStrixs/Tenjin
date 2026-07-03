#pragma once

#include <DatabaseManager/Types.h>

#include <QString>
#include <expected>
#include <string>
#include <vector>

namespace Service {

// AnkiImporter — extracts notes from an Anki .apkg package.
//
// An .apkg is a ZIP archive containing:
//   collection.anki2 (or .anki21) — a SQLite database
//   media                          — a JSON map of "0":"filename.mp3", ...
//   0, 1, 2, ...                   — the actual media files (numbered)
//
// Notes live in the `notes` table; each note's `flds` column holds the field
// values joined by the 0x1f unit-separator character. The first field is the
// front (becomes the Tenjin word title); remaining fields become content
// blocks. Tags live in the note's space-separated `tags` column.
//
// This first version imports TEXT fields only. Media references inside fields
// (e.g. [sound:x.mp3], <img src="y.jpg">) are preserved verbatim in the block
// text so no information is lost, but the media files themselves are not yet
// copied. The architecture (AnkiNote::mediaRefs) is in place to add that later.
struct AnkiNote {
    QString              title;       // first field, HTML-stripped
    std::vector<QString> extraFields; // remaining fields (kept as blocks)
    std::vector<QString> tags;        // Anki tags
    std::vector<QString> mediaRefs;   // media filenames referenced (for future)
    QString              deckName;    // originating Anki deck, if resolvable
};

struct AnkiImportResult {
    std::vector<AnkiNote> notes;
    int                   skipped = 0; // notes with no usable content
    QString               sourceDeck;  // collection-level deck name if single
};

// Parse an .apkg file at `apkgPath`. Returns the extracted notes or an error
// string. Does not touch the Tenjin database — the caller decides how to map
// notes onto entries/blocks/tags (see DatabaseManager::ImportFromAnki).
std::expected<AnkiImportResult, std::string> ParseApkg(const QString& apkgPath);

} // namespace Service
