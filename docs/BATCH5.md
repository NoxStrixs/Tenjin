# Batch 5 — DatabaseManager split (verified, 16/16 green)

The 1,054-line `DatabaseManager.cpp` monolith is split into one translation
unit per aggregate. Same `DatabaseManager` class, same public API, same
behavior — just navigable. Compiled and tested here: all 16 tests still pass,
all 47 methods accounted for (none lost).

## Layout

```
Service/DatabaseManager/src/
├── DatabaseManager_Database.cpp      ctor, dtor, backfillGuids (3)
├── DatabaseManager_Entry.cpp         AddWord/GetWord/GetAllWords/DeleteWord (4)
├── DatabaseManager_Tag.cpp           tags + word↔tag links (8)
├── DatabaseManager_Content.cpp       content blocks + layout (5)
├── DatabaseManager_Search.cpp        FTS + substring search (5)
├── DatabaseManager_Relation.cpp      word relations (3)
├── DatabaseManager_Deck.cpp          decks, membership, smart filters (11)
├── DatabaseManager_Review.cpp        SM-2 + stats + analytics (6)
├── DatabaseManager_ImportExport.cpp  JSON export/import (2)
└── Schema.cpp                        migrations (from batch 2)
```

Largest file is now 380 lines (ImportExport) vs the old 1,544. To find the deck
logic you open `_Deck.cpp`, not line 552 of a monolith.

## Files

Replace:
- `Service/DatabaseManager/CMakeLists.txt` (lists the 9 split TUs + Schema.cpp,
  adds the `BUILD_TESTS` subdirectory hook)

Add (the 9 split sources):
- `Service/DatabaseManager/src/DatabaseManager_*.cpp`

Remove:
- `Service/DatabaseManager/src/DatabaseManager.cpp` (the monolith — its contents
  now live in the 9 files above)

The header (`include/DatabaseManager/DatabaseManager.h`) is unchanged.

## Why same-library, not 8 separate libraries

A full library-per-repository split would add 8 CMake targets and cross-library
dependencies (Search needs Entry+Content, Deck analytics needs Review) — real
wiring I couldn't compile-verify here, and a class of breakage the test sandbox
wouldn't catch. Splitting into translation units behind the existing class gives
the navigability and single-responsibility win at zero API/behaviour risk, fully
verified. If you later want hard module boundaries, the per-aggregate files are
already the natural seams to lift into separate libraries.

## After applying

```bash
cmake -S . -B build -DBUILD_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure   # expect 16/16
```
