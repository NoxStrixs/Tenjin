#!/usr/bin/env bash
# One-shot cosmetic rename: Word → Entry across the C++ API and QML.
#
# The schema is already `entry` (migration v2); this aligns the *code* names so
# the vocabulary is consistent end to end. It is a pure identifier rename — no
# behavior changes — and the DatabaseManager test suite (16 tests) is your
# backstop: run it before and after and confirm it still passes.
#
# WHY A SCRIPT (not hand edits): the substitution order matters. Renaming
# "Word" before "WordService" would corrupt the latter into "EntryService"
# inconsistently. The list below is ordered most-specific-first so each token is
# rewritten exactly once.
#
# USAGE:
#   git switch -c rename-entry          # work on a branch — this touches ~27 files
#   ./tools/rename-to-entry.sh
#   cmake --build build && ctest --test-dir build   # verify green
#   # then build the app and smoke-test the QML before merging.
#
# REVERSIBLE: it's a branch + a mechanical map; `git checkout .` undoes it.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FILES=$(grep -rln -E 'Word_t|WordService|WordViewModel|wordVM|WordPage|WordRelation_t|AddWord|GetWord|DeleteWord|SearchWord|wordSelected|selectWord|wordList|wordModel' \
        --include='*.h' --include='*.cpp' --include='*.qml' . | grep -v '/build/' || true)

if [[ -z "$FILES" ]]; then
    echo "Nothing to rename."
    exit 0
fi

echo "Renaming Word → Entry in:"
echo "$FILES" | sed 's/^/  /'
echo

# Ordered: compound/specific identifiers first, bare "Word" last.
# Each line:  s/OLD/NEW/g
apply() {
    sed -i \
        -e 's/\bWordService\b/EntryService/g' \
        -e 's/\bWordViewModel\b/EntryViewModel/g' \
        -e 's/\bWordRelation_t\b/EntryRelation_t/g' \
        -e 's/\bWordReviewEvent_t\b/EntryReviewEvent_t/g' \
        -e 's/\bWordPage\b/EntryPage/g' \
        -e 's/\bAddWordToDeck\b/AddEntryToDeck/g' \
        -e 's/\bRemoveWordFromDeck\b/RemoveEntryFromDeck/g' \
        -e 's/\bAddWordRelation\b/AddEntryRelation/g' \
        -e 's/\bRemoveWordRelation\b/RemoveEntryRelation/g' \
        -e 's/\bGetWordsForDeck\b/GetEntriesForDeck/g' \
        -e 's/\bGetWordsForTag\b/GetEntriesForTag/g' \
        -e 's/\bGetWordsByTags\b/GetEntriesByTags/g' \
        -e 's/\bGetWordHistory\b/GetEntryHistory/g' \
        -e 's/\bGetRelationsForWord\b/GetRelationsForEntry/g' \
        -e 's/\bGetTagsForWord\b/GetTagsForEntry/g' \
        -e 's/\bGetContentForWord\b/GetContentForEntry/g' \
        -e 's/\bAddTagToWord\b/AddTagToEntry/g' \
        -e 's/\bRemoveTagFromWord\b/RemoveTagFromEntry/g' \
        -e 's/\bSearchWordsByName\b/SearchEntriesByName/g' \
        -e 's/\bSearchWordsByContent\b/SearchEntriesByContent/g' \
        -e 's/\bSearchWords\b/SearchEntries/g' \
        -e 's/\bAddWord\b/AddEntry/g' \
        -e 's/\bGetWord\b/GetEntry/g' \
        -e 's/\bGetAllWords\b/GetAllEntries/g' \
        -e 's/\bDeleteWord\b/DeleteEntry/g' \
        -e 's/\bwordSelected\b/entrySelected/g' \
        -e 's/\bselectWord\b/selectEntry/g' \
        -e 's/\bwordListChanged\b/entryListChanged/g' \
        -e 's/\bwordList\b/entryList/g' \
        -e 's/\bwordModel\b/entryModel/g' \
        -e 's/\bwordVM\b/entryVM/g' \
        -e 's/\bWord_t\b/Entry_t/g' \
        "$1"
}

for f in $FILES; do
    apply "$f"
done

# File renames (do last, after content is rewritten).
git_mv() { if [[ -e "$1" ]]; then git mv "$1" "$2" 2>/dev/null || mv "$1" "$2"; fi; }
git_mv View/WordPage.qml                                   View/EntryPage.qml
git_mv Service/WordService                                 Service/EntryService
git_mv View/ViewModels/include/ViewModels/WordViewModel.h  View/ViewModels/include/ViewModels/EntryViewModel.h
git_mv View/ViewModels/src/WordViewModel.cpp               View/ViewModels/src/EntryViewModel.cpp

echo
echo "Done. Now:"
echo "  - Update CMakeLists.txt references to the renamed dirs/files"
echo "    (Service/EntryService, EntryViewModel.{h,cpp}, EntryPage.qml in QML_FILES)."
echo "  - Rebuild and run: ctest --test-dir build --output-on-failure"
echo "  - Note: the .word struct field and 'word' QML props still read 'word'"
echo "    where they mean the literal vocabulary term; rename those by hand only"
echo "    if you want, they are semantically correct as-is."
