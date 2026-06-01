# Tenjin refactor — Phases 1–3 integration guide

Everything in `Service/` was compiled with Qt 6 and functionally tested
(real CRUD + a real v0→v3 migration with data preserved). The two `View/`
QML files are written to your conventions but could not be runtime-tested
here (no QtDeclarative in the build sandbox) — treat them as drop-in but
verify on a real build.

## What changed

**Phase 1 — unbreak.** `DatabaseManager.h` was corrupt (self-including, no
class declaration). Reconstructed it from the intact `.cpp`, and split the
value types into `Types.h`. Compiles clean against the real implementation.

**Phase 2 — generalize to Entry.** New `Schema.{h,cpp}`: a
`PRAGMA user_version` migration runner replacing the constructor's inline
CREATE/ALTER block. Migration v2 renames `word`→`entry` (+ a `kind` column),
`word_id`→`entry_id` across content/tag/relation/deck/review, and rebuilds the
FTS table + triggers against `entry`. Data-preserving and idempotent — your
existing vocabulary survives. `DatabaseManager.cpp`'s SQL was retargeted to the
new schema; the **public C++ API is unchanged** (still `Word_t`, `AddWord`,
`.word`), so WordService / ViewModels / QML compile untouched.

**Phase 3 — type-blind content + formulas.** Migration v3 adds
`entry_content.kind` (TEXT), backfilled from the legacy integer `type`. Every
content-block write now persists `kind` derived from the type. `ContentType_t`
gains `Formula = 4` plus `ToKindString` / `FromKindString` helpers. Adding any
future block kind is now: a new enumerator + a View delegate — **no schema
change**. Formula payload is a LaTeX string stored opaquely.

## Files

Replace:
- `Service/DatabaseManager/include/DatabaseManager/DatabaseManager.h`
- `Service/DatabaseManager/src/DatabaseManager.cpp`

Add:
- `Service/DatabaseManager/include/DatabaseManager/Types.h`
- `Service/DatabaseManager/include/DatabaseManager/Schema.h`
- `Service/DatabaseManager/src/Schema.cpp`
- `View/FormulaBlock.qml`
- `View/FormulaWebView.qml`

## CMake

In the DatabaseManager library's `CMakeLists.txt`, add `Schema.cpp` to
`target_sources` (it links `Qt6::Sql` and `Qt6::Core`, already present).

In the View module, register the two new QML files alongside the existing ones
(same `qt_add_qml_module`/`QML_FILES` list as `ContentBlock.qml`).

## Migration behavior (important)

On first launch with these changes, any existing `.db` is migrated
0/1 → 3 inside one transaction. **Back up the user DB once before shipping**,
and confirm a real old DB opens and shows its words. A fresh DB jumps straight
to v3. The migration is re-entrant: launching again is a no-op.

## Remaining QML wiring (mechanical, do on a real build)

The new formula delegate exists but isn't dispatched yet. Three small edits:

1. **`ContentBlock.qml`** — it branches on `blockType` (0=def,1=media,2=note,
   3=divider). Add the formula case: when `blockType === 4`, show a
   `FormulaBlock { ... }` instead of the text/media body, forwarding
   `blockId`, `blockContent`, `editMode`, and the `contentEdited`/`deleteRequested`
   signals. Extend `typeNames` to `["definition","media","note","divider","formula"]`.

2. **`GridContentView.qml`** — passes `blockType: cell.modelData.type`; no change
   needed beyond letting type 4 flow through (it already does).

3. **Block-type picker** (wherever a new block's type is chosen, e.g.
   `AddWordDialog.qml`/the add-block menu) — add a "Formula" option that
   creates a block with type 4.

The ViewModel path needs no change: it already round-trips `type` as an int,
and 4 flows through like any other value. The `kind` column is maintained in
C++ automatically.

## KaTeX (offline-first)

`FormulaWebView.qml` renders via KaTeX. It currently points at the jsDelivr CDN
as a fallback. For true offline use, bundle KaTeX into the View resources under
a `katex/` prefix (`katex.min.css`, `katex.min.js`, `fonts/`) and change
`katexBase` to `qrc:/katex`. KaTeX only loads when `WEBVIEW_SUPPORT` is
compiled in; without it, the block shows raw LaTeX in monospace (still legible).

## Suggested next passes (not yet done)

- Cosmetic rename `Word_t`→`Entry_t`, `AddWord`→`AddEntry`, `wordVM`→`entryVM`,
  `WordPage`→`EntryPage`. Pure find/replace now that the schema is `entry`.
- Split `DatabaseManager` into repositories (Entry/Tag/Content/Search/Relation/
  Deck/Review/ImportExport) behind the connection+migration core.
- Add new entry kinds (math-note, kanji, concept) — now just `kind` values.
