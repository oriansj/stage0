#!/bin/sh
## Copyright (C) 2017 rain1
## Copyright (C) 2017 Jeremiah Orians
## This file is part of stage0.
##
## stage0 is free software: you an redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## stage0 is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with stage0.  If not, see <http://www.gnu.org/licenses/>.

# Pass the name of the FORTH Script you wish to test as the only argument
# Example usage: ./stage3/shortcuts/forth.sh test.fs
TMP=$(mktemp)
cat stage3/inital_library.fs "$1" > "$TMP"
./bin/vm --rom roms/forth --memory 4M --tape_01 "$TMP"
rm "$TMP"
