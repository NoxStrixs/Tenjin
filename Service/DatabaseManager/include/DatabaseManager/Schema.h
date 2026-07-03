#pragma once

#include <QSqlDatabase>

namespace Service {

// Owns schema creation and forward migrations for a single connection.

// Versioning uses SQLite's `PRAGMA user_version`. Each migration step upgrades
// the DB by exactly one version; `Migrate` runs every step from the DB's
// current version up to kSchemaVersion, inside one transaction.
//
// NEVER edit or reorder existing steps to prevent backward compatibility issues.
namespace Schema {

// The version the application code expects. A freshly created DB jumps straight
// to this; an older DB is migrated up to it.
// Pre-release schema epoch. Because the kV2/kV3 migrations were folded into the
// single consolidated base schema, there is no forward-migration path from older
// dev databases. Bumping this number forces any database created under a
// previous layout to be wiped and rebuilt (see Migrate). Start high (100) to
// stay clear of the old 1/2/3 sequence, and bump again on any pre-release schema
// change. Replace this wipe-on-mismatch policy with real migrations at launch.
inline constexpr int kSchemaVersion = 100;

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
