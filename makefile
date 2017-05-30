## Copyright (C) 2016 Jeremiah Orians
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

# Don't rebuild the built things in bin or roms
VPATH = bin:roms

# Collections of tools
all: libvm.so vm ALL-ROMS

production: libvm-production.so vm-production asm dis ALL-ROMS

development: vm libvm.so asm dis ALL-ROMS

# VM Builds
vm-minimal: vm.h vm_minimal.c vm_instructions.c vm_decode.c | bin
	gcc vm.h vm_minimal.c vm_instructions.c vm_decode.c -o bin/vm-minimal

vm: vm.h vm.c vm_instructions.c vm_decode.c tty.c | bin
	gcc -ggdb -Dtty_lib=true vm.h vm.c vm_instructions.c vm_decode.c tty.c -o bin/vm

vm-production: vm.h vm.c vm_instructions.c vm_decode.c | bin
	gcc vm.h vm.c vm_instructions.c vm_decode.c -o bin/vm-production

vm-trace: vm.h vm.c vm_instructions.c vm_decode.c tty.c dynamic_execution_trace.c | bin
	gcc -ggdb -Dtty_lib=true -DTRACE=true vm.h vm.c vm_instructions.c vm_decode.c tty.c dynamic_execution_trace.c -o bin/vm

# Build the roms
ALL-ROMS: stage0_monitor stage1_assembler-0 SET stage1_assembler-1 stage1_assembler-2 M0 CAT lisp forth

stage0_monitor: hex stage0/stage0_monitor.hex0 | roms
	./bin/hex < stage0/stage0_monitor.hex0 > roms/stage0_monitor

stage1_assembler-0: hex stage1/stage1_assembler-0.hex0 | roms
	./bin/hex < stage1/stage1_assembler-0.hex0 > roms/stage1_assembler-0

SET: stage1_assembler-0 vm stage1/SET.hex0 | roms
	./bin/vm --rom roms/stage1_assembler-0 --tape_01 stage1/SET.hex0 --tape_02 roms/SET

stage1_assembler-1: stage1_assembler-0 vm stage1/stage1_assembler-1.hex0 | roms
	./bin/vm --rom roms/stage1_assembler-0 --tape_01 stage1/stage1_assembler-1.hex0  --tape_02 roms/stage1_assembler-1

stage1_assembler-2: stage1_assembler-1 vm stage1/stage1_assembler-2.hex1 | roms
	./bin/vm --rom roms/stage1_assembler-1 --tape_01 stage1/stage1_assembler-2.hex1 --tape_02 roms/stage1_assembler-2

M0: stage1_assembler-2 vm stage1/M0-macro.hex2 | roms
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 stage1/M0-macro.hex2 --tape_02 roms/M0 --memory 48K

CAT: M0 stage1_assembler-2 vm High_level_prototypes/defs stage1/CAT.s | roms
	cat High_level_prototypes/defs stage1/CAT.s >| temp
	./bin/vm --rom roms/M0 --tape_01 temp --tape_02 temp2 --memory 48K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 temp2 --tape_02 roms/CAT --memory 48K

lisp: M0 stage1_assembler-2 vm High_level_prototypes/defs stage2/lisp.s | roms
	cat High_level_prototypes/defs stage2/lisp.s > temp
	./bin/vm --rom roms/M0 --tape_01 temp --tape_02 temp2 --memory 256K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 temp2 --tape_02 roms/lisp --memory 48K

forth: M0 stage1_assembler-2 vm High_level_prototypes/defs stage2/forth.s | roms
	cat High_level_prototypes/defs stage2/forth.s > temp
	./bin/vm --rom roms/M0 --tape_01 temp --tape_02 temp2 --memory 128K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 temp2 --tape_02 roms/forth --memory 48K

# Primitive development tools, not required but it was handy
asm: High_level_prototypes/asm.c | bin
	gcc -ggdb High_level_prototypes/asm.c -o bin/asm

dis: High_level_prototypes/disasm.c | bin
	gcc -ggdb High_level_prototypes/disasm.c -o bin/dis

hex: Linux\ Bootstrap/hex.c | bin
	gcc Linux\ Bootstrap/hex.c -o bin/hex

# libVM Builds for Development tools
libvm.so: wrapper.c vm_instructions.c vm_decode.c vm.h tty.c
	gcc -ggdb -Dtty_lib=true -shared -Wl,-soname,libvm.so -o libvm.so -fPIC wrapper.c vm_instructions.c vm_decode.c vm.h tty.c

libvm-production.so: wrapper.c vm_instructions.c vm_decode.c vm.h
	gcc -shared -Wl,-soname,libvm.so -o libvm-production.so -fPIC wrapper.c vm_instructions.c vm_decode.c vm.h

# Tests
Generate-rom-test: ALL-ROMS
	mkdir -p test
	sha256sum roms/* | sort -k2 >| test/SHA256SUMS

test: ALL-ROMS test/SHA256SUMS
	sha256sum -c test/SHA256SUMS

# Clean up after ourselves
.PHONY: clean
clean:
	rm -f libvm.so libvm-production.so bin/vm bin/vm-production

.PHONY: clean-hard
clean-hard: clean
	rm -rf bin/ roms/

.PHONY: clean-hardest
clean-hardest:
	git reset --hard
	git clean -fd

clean-SO-hard-You-probably-do-NOT-want-this-option-because-it-will-destory-everything:
	@echo "I REALLY REALLY HOPE you know what you are doing"
	git reset --hard
	git clean -xdf

# Our essential folders
bin:
	mkdir -p bin

roms:
	mkdir -p roms
