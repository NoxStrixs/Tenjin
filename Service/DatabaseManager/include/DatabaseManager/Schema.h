#pragma once

#include <QSqlDatabase>

namespace Service {

// Owns schema creation and forward migrations for a single connection.
//
// Versioning uses SQLite's `PRAGMA user_version`. Each migration step upgrades
// the DB by exactly one version; `Migrate` runs every step from the DB's
// current version up to kSchemaVersion, inside one transaction.
//
// To evolve the schema: bump kSchemaVersion and append a step to the migration
// table in Schema.cpp. NEVER edit or reorder existing steps — they have already
// run on real databases.
namespace Schema {

// The version the application code expects. A freshly created DB jumps straight
// to this; an older DB is migrated up to it.
inline constexpr int kSchemaVersion = 3;

// Brings `db` from its current user_version up to kSchemaVersion. Throws
// std::runtime_error on failure (transaction is rolled back first).
//
// v1: baseline word-centric schema (word/tag/content/relation/deck/review +
//     FTS + guid/updated_at columns) — the historical state of the DB.
// v2: generalize to entries. Renames word→entry (+ kind column), word_id→
//     entry_id across content/tag/relation/deck/review, and rebuilds the FTS
//     table and triggers against entry. Data-preserving.
// v3: content blocks become type-blind. Adds entry_content.kind (TEXT),
//     backfilled from the legacy integer `type` column. New block kinds
//     (e.g. "formula") need no further schema change.
void Migrate(QSqlDatabase& db);

} // namespace Schema
} // namespace Service
