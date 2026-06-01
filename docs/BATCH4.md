# Batch 4 — date fix, test suite, and the Entry rename

## 1. Review date bug — FIXED (verified)

`InitReview` wrote the initial due date in UTC (`date('now')`) while
`SubmitReview` wrote local dates (`QDate::currentDate()`), and `GetDueReviews`
compared against UTC. Near midnight, in any non-UTC timezone, cards could appear
due a day early/late. Now all three use local time consistently
(`date('now','localtime')` in SQL, matching the local `QDate` writes).

Replace: `Service/DatabaseManager/src/DatabaseManager.cpp`

Proven by two tests below: a new card is due *today* on local time, and a
reviewed card (scheduled +1 day) correctly leaves the due queue.

## 2. Test component — NEW (16/16 passing here)

A GoogleTest suite laid out as its own component exactly as requested:

```
Service/DatabaseManager/tests/
├── CMakeLists.txt
└── src/
    ├── TestHelpers.h     (TempDb fixture — real on-disk SQLite per test)
    ├── SchemaTest.cpp    (6 tests: migrations)
    └── Sm2Test.cpp       (10 tests: CRUD + SM-2 + due-date)
```

Coverage:
- **Migrations:** fresh DB → latest version; entry schema + FTS exist; legacy
  v0 → v3 preserves rows *and ids* (word 42 → entry 42); FTS index rebuilt and
  searchable; v3 backfills `kind` from the integer `type` for all four legacy
  types; migration is idempotent.
- **CRUD:** add/get word, duplicate rejection, formula block persists `kind`.
- **SM-2:** interval ladder (1 → 6 → ×ease), ease rises on quality 5, failure
  resets streak, ease-factor floor of 1.3 holds over 20 low passes, new review
  is due today, reviewed card leaves the queue.

Add the whole `tests/` dir. Then wire it into the library's CMake — append to
`Service/DatabaseManager/CMakeLists.txt`:

```cmake
if(BUILD_TESTS)
    add_subdirectory(tests)
endif()
```

The test `CMakeLists.txt` links `TenjinDatabaseManager` (adjust if your library
target is named differently), finds a system GoogleTest, and falls back to
fetching v1.15.2 if none is installed. Run:

```bash
cmake -S . -B build -DBUILD_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

Per your earlier call, this is **not** wired into the `tool` CLI — it's a pure
CMake/ctest component you invoke directly.

## 3. Word → Entry rename — SCRIPTED (dry-run verified)

The schema is already `entry`; this aligns the *code* names. It touches ~27
files and has real ordering hazards (rename "Word" before "WordService" and you
corrupt the latter), so it's delivered as an ordered, idempotent script rather
than loose edited files.

Add: `tools/rename-to-entry.sh`

```bash
git switch -c rename-entry
./tools/rename-to-entry.sh
# update CMakeLists references to renamed dirs/files (it lists them)
cmake --build build && ctest --test-dir build --output-on-failure   # must stay green
# build the app, smoke-test QML, then merge
```

I dry-ran it against the real headers: no double-substitution, signatures come
out clean (`AddEntry`, `GetEntriesForDeck`, `EntryService`, `Entry_t`). Two
deliberate non-renames: the `.word` struct field and `word` QML props that mean
the literal vocabulary term stay as-is (semantically correct), and
`WordService::CreateWord` — rename that one by hand to `CreateEntry` if you want
full consistency (left out because it's a thin validation wrapper you may fold
into `AddEntry` anyway).

**Run the tests as your backstop** before and after — that's exactly why the
suite came first.

## Still pending (not done — need a real build to verify safely)

These touch files I can't compile-check here (QML/MOC), so dumping them
unverified would risk a broken build:

- **DatabaseManager repository split** (Entry/Tag/Content/Search/Relation/Deck/
  Review/ImportExport behind the connection+migration core). The test suite now
  makes this safe to do incrementally — split one repo, keep tests green, repeat.
- **Formula QML wiring** (3 edits in `ContentBlock.qml` / `GridContentView.qml`
  / the add-block picker) so the `FormulaBlock.qml` delegate from batch 3
  actually renders. Mechanical; do it on a real build where you can see it.

Suggested order: apply batch 4 → confirm tests green → run the rename → then the
repository split using the green suite as the safety net.
