#!/bin/sh
# Pass the name of the FORTH Script you wish to test as the only argument
TMP=$(mktemp)
cat stage3/inital_library.fs "$1" > "$TMP"
./bin/vm --rom roms/forth --memory 4M --tape_01 "$TMP"
rm "$TMP"
