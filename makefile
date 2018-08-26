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
VPATH = bin:roms:prototypes:stage1/High_level_prototypes:stage2/High_level_prototypes

# Collections of tools
all: libvm.so vm ALL-ROMS ALL-PROTOTYPES

production: libvm-production.so vm-production asm dis ALL-ROMS

development: vm libvm.so asm dis ALL-ROMS

# VM Builds
vm-minimal: vm.h vm_minimal.c vm_instructions.c vm_decode.c | bin
	gcc vm.h vm_minimal.c vm_instructions.c vm_decode.c -o bin/vm-minimal

vm: vm.h vm.c vm_instructions.c vm_decode.c tty.c | bin
	gcc -ggdb -DVM32=true -Dtty_lib=true vm.h vm.c vm_instructions.c vm_decode.c tty.c -o bin/vm

vm-production: vm.h vm.c vm_instructions.c vm_decode.c | bin
	gcc vm.h vm.c vm_instructions.c vm_decode.c -o bin/vm-production

vm-trace: vm.h vm.c vm_instructions.c vm_decode.c tty.c dynamic_execution_trace.c | bin
	gcc -ggdb -Dtty_lib=true -DTRACE=true vm.h vm.c vm_instructions.c vm_decode.c tty.c dynamic_execution_trace.c -o bin/vm

# Build the roms
ALL-ROMS: stage0_monitor stage1_assembler-0 SET DEHEX stage1_assembler-1 stage1_assembler-2 M0 CAT lisp cc_x86 forth

stage0_monitor: hex stage0/stage0_monitor.hex0 | roms
	./bin/hex < stage0/stage0_monitor.hex0 > roms/stage0_monitor

stage1_assembler-0: hex stage1/stage1_assembler-0.hex0 | roms
	./bin/hex < stage1/stage1_assembler-0.hex0 > roms/stage1_assembler-0

SET: stage1_assembler-2 vm stage1/SET.hex2 | roms
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 stage1/SET.hex2 --tape_02 roms/SET

DEHEX: stage1_assembler-0 vm stage1/dehex.hex0 | roms
	./bin/vm --rom roms/stage1_assembler-0 --tape_01 stage1/dehex.hex0 --tape_02 roms/DEHEX

stage1_assembler-1: stage1_assembler-0 vm stage1/stage1_assembler-1.hex0 | roms
	./bin/vm --rom roms/stage1_assembler-0 --tape_01 stage1/stage1_assembler-1.hex0  --tape_02 roms/stage1_assembler-1

stage1_assembler-2: stage1_assembler-1 vm stage1/stage1_assembler-2.hex1 | roms
	./bin/vm --rom roms/stage1_assembler-1 --tape_01 stage1/stage1_assembler-2.hex1 --tape_02 roms/stage1_assembler-2

M0: stage1_assembler-2 vm stage1/M0-macro.hex2 | roms
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 stage1/M0-macro.hex2 --tape_02 roms/M0 --memory 48K

CAT: M0 stage1_assembler-2 vm High_level_prototypes/defs stage1/CAT.s | roms
	cat High_level_prototypes/defs stage1/CAT.s >| CAT_TEMP
	./bin/vm --rom roms/M0 --tape_01 CAT_TEMP --tape_02 CAT_TEMP2 --memory 48K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 CAT_TEMP2 --tape_02 roms/CAT --memory 48K
	rm CAT_TEMP CAT_TEMP2

lisp: M0 stage1_assembler-2 vm High_level_prototypes/defs stage2/lisp.s | roms
	cat High_level_prototypes/defs stage2/lisp.s > lisp_TEMP
	./bin/vm --rom roms/M0 --tape_01 lisp_TEMP --tape_02 lisp_TEMP2 --memory 256K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 lisp_TEMP2 --tape_02 roms/lisp --memory 48K
	rm lisp_TEMP lisp_TEMP2

cc_x86: M0 stage1_assembler-2 vm High_level_prototypes/defs stage2/cc_x86.s | roms
	cat High_level_prototypes/defs stage2/cc_x86.s > cc_TEMP
	./bin/vm --rom roms/M0 --tape_01 cc_TEMP --tape_02 cc_TEMP2 --memory 256K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 cc_TEMP2 --tape_02 roms/cc_x86 --memory 48K
	rm cc_TEMP cc_TEMP2

forth: M0 stage1_assembler-2 vm High_level_prototypes/defs stage2/forth.s | roms
	cat High_level_prototypes/defs stage2/forth.s > forth_TEMP
	./bin/vm --rom roms/M0 --tape_01 forth_TEMP --tape_02 forth_TEMP2 --memory 128K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 forth_TEMP2 --tape_02 roms/forth --memory 48K
	rm forth_TEMP forth_TEMP2

# Primitive development tools, not required but it was handy
asm: High_level_prototypes/asm.c | bin
	gcc -ggdb High_level_prototypes/asm.c -o bin/asm

dis: High_level_prototypes/disasm.c | bin
	gcc -ggdb High_level_prototypes/disasm.c -o bin/dis

hex: Linux\ Bootstrap/hex.c | bin
	gcc Linux\ Bootstrap/hex.c -o bin/hex

xeh: Linux\ Bootstrap/xeh.c | bin
	gcc Linux\ Bootstrap/xeh.c -o bin/xeh

# libVM Builds for Development tools
libvm.so: wrapper.c vm_instructions.c vm_decode.c vm.h tty.c
	gcc -ggdb -DVM32=true -Dtty_lib=true -shared -Wl,-soname,libvm.so -o libvm.so -fPIC wrapper.c vm_instructions.c vm_decode.c vm.h tty.c

libvm-production.so: wrapper.c vm_instructions.c vm_decode.c vm.h
	gcc -DVM32=true -shared -Wl,-soname,libvm.so -o libvm-production.so -fPIC wrapper.c vm_instructions.c vm_decode.c vm.h

# Tests
Generate-rom-test: ALL-ROMS
	mkdir -p test
	sha256sum roms/* | sort -k2 >| test/SHA256SUMS

test: ALL-ROMS test/SHA256SUMS
	sha256sum -c test/SHA256SUMS

# Prototypes
ALL-PROTOTYPES: prototype_dehex prototype_M0 prototype_more prototype_SET prototype_stage1_assembler-1 prototype_stage1_assembler-2 prototype_lisp

prototype_dehex: dehex.c | prototypes
	gcc stage1/High_level_prototypes/dehex.c -o prototypes/prototype_dehex

prototype_M0: M0-macro.c | prototypes
	gcc stage1/High_level_prototypes/M0-macro.c -o prototypes/prototype_M0

prototype_more: more.c tty.c | prototypes
	gcc stage1/High_level_prototypes/more.c tty.c -o prototypes/prototype_more

prototype_SET: SET.c tty.c | prototypes
	gcc stage1/High_level_prototypes/SET.c tty.c -o prototypes/prototype_SET

prototype_stage1_assembler-1: stage1_assembler-1.c | prototypes
	gcc stage1/High_level_prototypes/stage1_assembler-1.c -o prototypes/prototype_stage1_assembler-1

prototype_stage1_assembler-2: stage1_assembler-2.c | prototypes
	gcc stage1/High_level_prototypes/stage1_assembler-2.c -o prototypes/prototype_stage1_assembler-2

prototype_lisp: lisp.c lisp.h lisp_cell.c lisp_eval.c lisp_print.c lisp_read.c | prototypes
	gcc -O2 stage2/High_level_prototypes/lisp.h \
	        stage2/High_level_prototypes/lisp.c \
	        stage2/High_level_prototypes/lisp_cell.c \
	        stage2/High_level_prototypes/lisp_eval.c \
	        stage2/High_level_prototypes/lisp_print.c \
	        stage2/High_level_prototypes/lisp_read.c \
	        -o prototypes/prototype_lisp


# Clean up after ourselves
.PHONY: clean
clean:
	rm -rf bin/ roms/ prototypes/ *.so

.PHONY: clean-hardest
clean-hard:
	git reset --hard
	git clean -fd
	rm -rf bin/ roms/ prototypes/

clean-SO-hard-You-probably-do-NOT-want-this-option-because-it-will-destory-everything:
	@echo "I REALLY REALLY HOPE you know what you are doing"
	git reset --hard
	git clean -xdf
	rm -rf bin/ roms/ prototypes/

# Our essential folders
bin:
	mkdir -p bin

roms:
	mkdir -p roms

prototypes:
	mkdir -p prototypes
