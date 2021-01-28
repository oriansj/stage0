## Copyright (C) 2016 Jeremiah Orians
## This file is part of stage0.
##
## stage0 is free software: you can redistribute it and/or modify
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
vm-minimal: vm.h vm_types.h vm_globals.c vm_minimal.c vm_instructions.c vm_halcode.c vm_decode.c functions/require.c functions/file_print.c functions/match.c | bin
	$(CC) -DVM32=true vm_minimal.c vm_globals.c vm_instructions.c vm_halcode.c vm_decode.c functions/require.c functions/file_print.c functions/match.c -o bin/vm-minimal

vm16: vm.h vm_types.h vm_globals.c vm.c vm_instructions.c vm_halcode.c vm_decode.c tty.c functions/require.c functions/file_print.c functions/match.c | bin
	$(CC) -ggdb -DVM16=true -Dtty_lib=true vm.c vm_globals.c vm_instructions.c vm_halcode.c vm_decode.c tty.c functions/require.c functions/file_print.c functions/match.c -o bin/vm16

vm: vm.h vm_types.h vm_globals.c vm.c vm_instructions.c vm_halcode.c vm_decode.c tty.c functions/require.c functions/file_print.c functions/match.c | bin
	$(CC) -ggdb -DVM32=true -Dtty_lib=true vm.c vm_globals.c vm_instructions.c vm_halcode.c vm_decode.c tty.c functions/require.c functions/file_print.c functions/match.c -o bin/vm

vm64: vm.h vm_types.h vm_globals.c vm.c vm_instructions.c vm_halcode.c vm_decode.c tty.c functions/require.c functions/file_print.c functions/match.c | bin
	$(CC) -ggdb -DVM64=true -Dtty_lib=true vm.c vm_globals.c vm_instructions.c vm_halcode.c vm_decode.c tty.c functions/require.c functions/file_print.c functions/match.c -o bin/vm64

vm-production: vm.h vm_types.h vm_globals.c vm.c vm_instructions.c vm_halcode.c vm_decode.c functions/require.c functions/file_print.c functions/match.c | bin
	$(CC) -DVM32=true vm.c vm_globals.c vm_instructions.c vm_halcode.c vm_decode.c functions/require.c functions/file_print.c functions/match.c -o bin/vm-production

vm-trace: vm.h vm_types.h vm_globals.c vm.c vm_instructions.c vm_halcode.c vm_decode.c tty.c dynamic_execution_trace.c functions/require.c functions/file_print.c functions/match.c | bin
	$(CC) -DVM32=true -ggdb -Dtty_lib=true -DTRACE=true vm.c vm_globals.c vm_instructions.c vm_halcode.c vm_decode.c tty.c dynamic_execution_trace.c functions/require.c functions/file_print.c functions/match.c -o bin/vm

# Build the roms
ALL-ROMS: stage0_monitor stage1_assembler-0 SET DEHEX stage1_assembler-1 stage1_assembler-2 M0 CAT lisp cc_x86 forth

stage0_monitor: vm stage0/stage0_monitor.hex0 | roms
	./bin/vm --rom seed/NATIVE/knight/hex0-seed --tape_01 stage0/stage0_monitor.hex0 --tape_02 roms/stage0_monitor

stage1_assembler-0: vm stage1/stage1_assembler-0.hex0 | roms
	./bin/vm --rom seed/NATIVE/knight/hex0-seed --tape_01 stage1/stage1_assembler-0.hex0 --tape_02 roms/stage1_assembler-0

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

M0-compact: M0 stage1_assembler-2 vm stage1/M0-macro-compact.s | roms
	cat High_level_prototypes/defs stage1/M0-macro-compact.s >| M0_TEMP
	./bin/vm --rom roms/M0 --tape_01 M0_TEMP --tape_02 M0_TEMP2 --memory 64K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 M0_TEMP2 --tape_02 roms/M0-compact --memory 5K
	rm M0_TEMP M0_TEMP2

CAT: M0 stage1_assembler-2 vm High_level_prototypes/defs stage1/CAT.s | roms
	cat High_level_prototypes/defs stage1/CAT.s >| CAT_TEMP
	./bin/vm --rom roms/M0 --tape_01 CAT_TEMP --tape_02 CAT_TEMP2 --memory 48K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 CAT_TEMP2 --tape_02 roms/CAT --memory 48K
	rm CAT_TEMP CAT_TEMP2

lisp: M0-compact stage1_assembler-2 vm High_level_prototypes/defs stage2/lisp.s | roms
	cat High_level_prototypes/defs stage2/lisp.s > lisp_TEMP
	./bin/vm --rom roms/M0-compact --tape_01 lisp_TEMP --tape_02 lisp_TEMP2 --memory 8K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 lisp_TEMP2 --tape_02 roms/lisp --memory 48K
	rm lisp_TEMP lisp_TEMP2

cc_x86: M0-compact stage1_assembler-2 vm High_level_prototypes/defs stage2/cc_x86.s | roms
	cat High_level_prototypes/defs stage2/cc_x86.s > cc_TEMP
	./bin/vm --rom roms/M0-compact --tape_01 cc_TEMP --tape_02 cc_TEMP2 --memory 8K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 cc_TEMP2 --tape_02 roms/cc_x86 --memory 32K
	rm cc_TEMP cc_TEMP2

forth: M0-compact stage1_assembler-2 vm High_level_prototypes/defs stage2/forth.s | roms
	cat High_level_prototypes/defs stage2/forth.s > forth_TEMP
	./bin/vm --rom roms/M0-compact --tape_01 forth_TEMP --tape_02 forth_TEMP2 --memory 8K
	./bin/vm --rom roms/stage1_assembler-2 --tape_01 forth_TEMP2 --tape_02 roms/forth --memory 12K
	rm forth_TEMP forth_TEMP2

# Primitive development tools, not required but it was handy
asm: High_level_prototypes/asm.c | bin
	$(CC) -ggdb High_level_prototypes/asm.c -o bin/asm

dis: High_level_prototypes/disasm.c | bin
	$(CC) -ggdb High_level_prototypes/disasm.c -o bin/dis

hex: Linux\ Bootstrap/Legacy_pieces/hex.c | bin
	$(CC) Linux\ Bootstrap/Legacy_pieces/hex.c -o bin/hex

xeh: Linux\ Bootstrap/Legacy_pieces/xeh.c | bin
	$(CC) Linux\ Bootstrap/Legacy_pieces/xeh.c -o bin/xeh

# libVM Builds for Development tools
libvm.so: wrapper.c vm_instructions.c vm_halcode.c vm_decode.c vm.h tty.c
	$(CC) -ggdb -DVM32=true -Dtty_lib=true -shared -Wl,-soname,libvm.so -o libvm.so -fPIC wrapper.c vm_globals.c vm_instructions.c vm_halcode.c vm_decode.c tty.c functions/require.c functions/file_print.c

libvm-production.so: wrapper.c vm_instructions.c vm_halcode.c vm_decode.c vm.h
	$(CC) -DVM32=true -shared -Wl,-soname,libvm.so -o libvm-production.so -fPIC wrapper.c vm_globals.c vm_instructions.c vm_halcode.c vm_decode.c functions/require.c functions/file_print.c

# Tests
Generate-rom-test: ALL-ROMS
	mkdir -p test
	sha256sum roms/* | sort -k2 >| test/SHA256SUMS

test_stage0_monitor_asm_match: asm hex stage0_monitor
	mkdir -p test/stage0_test_scratch
	sed 's/^[^#]*# //' stage0/stage0_monitor.hex0 > test/stage0_test_scratch/stage0_monitor.hex0.s
	bin/asm test/stage0_test_scratch/stage0_monitor.hex0.s > test/stage0_test_scratch/stage0_monitor.hex0.hex0
	bin/hex < test/stage0_test_scratch/stage0_monitor.hex0.hex0 > test/stage0_test_scratch/stage0_monitor.hex0.bin
	bin/asm stage0/stage0_monitor.s > test/stage0_test_scratch/stage0_monitor.s.hex0
	bin/hex < test/stage0_test_scratch/stage0_monitor.s.hex0 > test/stage0_test_scratch/stage0_monitor.s.bin
	sha256sum roms/stage0_monitor | sed 's@roms/stage0_monitor@test/stage0_test_scratch/stage0_monitor.s.bin@' > test/stage0_test_scratch/stage0_monitor.s.expected_sum
	sha256sum -c test/stage0_test_scratch/stage0_monitor.s.expected_sum
	sha256sum roms/stage0_monitor | sed 's@roms/stage0_monitor@test/stage0_test_scratch/stage0_monitor.hex0.bin@' > test/stage0_test_scratch/stage0_monitor.hex0.expected_sum
	sha256sum -c test/stage0_test_scratch/stage0_monitor.hex0.expected_sum

.SILENT: testM0
.PHONY: testM0
testM0: vm16 vm vm64 M0-compact prototype_M0-compact ALL-ROMS
	echo assembling ALL-ROMS with prototype_M0-compact and M0 with 32 bit vm and M0-compact with vm, vm64 and vm16; \
	VM_LIST='vm vm64 vm16'; \
	STAGE_1_UNIFORM_PROG_LIST="stage1_assembler-0 stage1_assembler-1 \
stage1_assembler-2 CAT SET"; \
	STAGE_2_UNIFORM_PROG_LIST='cc_x86 forth lisp'; \
	ASSEMBLER_PROG_LIST="stage0/stage0_monitor"; \
	for stage1prog in $$STAGE_1_UNIFORM_PROG_LIST; do \
	ASSEMBLER_PROG_LIST="$$ASSEMBLER_PROG_LIST stage1/$$stage1prog"; \
	done; \
	ASSEMBLER_PROG_LIST="$$ASSEMBLER_PROG_LIST \
stage1/M0-macro stage1/M0-macro-compact stage1/dehex"; \
	for stage2prog in $$STAGE_2_UNIFORM_PROG_LIST; do \
	ASSEMBLER_PROG_LIST="$$ASSEMBLER_PROG_LIST stage2/$$stage2prog"; \
	done; \
	for prog in $$ASSEMBLER_PROG_LIST; do \
	cat High_level_prototypes/defs "$$prog".s > "$$prog"_TEMP.s; \
	./prototypes/prototype_M0-compact "$$prog"_TEMP.s > \
	"$$prog"_protoM0compact_TEMP.hex2; \
	./bin/vm --memory 256K --rom roms/stage1_assembler-2 \
	    --tape_01 "$$prog"_protoM0compact_TEMP.hex2 \
	    --tape_02 "$$prog"_built_protoM0compact > /dev/null 2>&1; \
	rm "$$prog"_protoM0compact_TEMP.hex2; \
	M0ROMLIST='M0 M0-compact'; \
	for rom in $$M0ROMLIST; do \
	for vm in $$VM_LIST; do \
	    if [ $$rom = M0-compact ] || [ $$vm = vm ]; then \
	        ./bin/$$vm --memory 256K --rom roms/$$rom \
	        --tape_01 "$$prog"_TEMP.s \
	        --tape_02 "$$prog"_"$$vm"_TEMP.hex2 > /dev/null 2>&1; \
	        ./bin/vm --memory 256K --rom roms/stage1_assembler-2 \
	        --tape_01 "$$prog"_"$$vm"_TEMP.hex2 \
	        --tape_02 "$$prog"_built_"$$vm"_"$$rom"> /dev/null 2>&1; \
	        rm "$$prog"_"$$vm"_TEMP.hex2; \
	    fi; \
	done; done; \
	rm "$$prog"_TEMP.s; \
	done; \
	BUILDSUFFIXLIST='protoM0compact'; \
	for vm in $$VM_LIST; do \
	for rom in $$M0ROMLIST; do \
	    if [ $$rom = M0-compact ] || [ $$vm = vm ]; then \
	    BUILDSUFFIXLIST="$$BUILDSUFFIXLIST $$vm"; \
	    BUILDSUFFIXLIST="$$BUILDSUFFIXLIST"_; \
	    BUILDSUFFIXLIST="$$BUILDSUFFIXLIST""$$rom"; \
	fi; \
	done; done; \
	for buildsuffix in $$BUILDSUFFIXLIST; do \
	cmp roms/stage0_monitor stage0/stage0_monitor_built_"$$buildsuffix"; \
	rm stage0/stage0_monitor_built_$$buildsuffix; \
	for stage1prog in $$STAGE_1_UNIFORM_PROG_LIST; do \
	    cmp roms/$$stage1prog stage1/"$$stage1prog"_built_"$$buildsuffix"; \
	    rm stage1/"$$stage1prog"_built_"$$buildsuffix"; \
	done; \
	cmp roms/M0 stage1/M0-macro_built_"$$buildsuffix"; \
	rm stage1/M0-macro_built_"$$buildsuffix"; \
	cmp roms/M0-compact stage1/M0-macro-compact_built_"$$buildsuffix"; \
	rm stage1/M0-macro-compact_built_"$$buildsuffix"; \
	cmp roms/DEHEX stage1/dehex_built_"$$buildsuffix"; \
	rm stage1/dehex_built_"$$buildsuffix"; \
	for stage2prog in $$STAGE_2_UNIFORM_PROG_LIST; do \
	    cmp roms/$$stage2prog stage2/"$$stage2prog"_built_"$$buildsuffix"; \
	    rm stage2/"$$stage2prog"_built_"$$buildsuffix"; \
	done; \
	done; \
	echo done M0 test

.SILENT: testdisasmpy
.PHONY: testdisasmpy
testdisasmpy: ALL-ROMS M0-compact vm
	ROM_LIST="stage0_monitor stage1_assembler-0 \
stage1_assembler-1 stage1_assembler-2 CAT SET M0 M0-compact DEHEX \
cc_x86 forth lisp"; \
	for rom in $$ROM_LIST; do \
	    ./High_level_prototypes/disasm.py --address-mode none \
		roms/"$$rom" > "$$rom".TEMP.dis.s; \
	    cat High_level_prototypes/defs "$$rom".TEMP.dis.s > \
	        "$$rom".TEMP.dis_cat.s; \
	    rm "$$rom".TEMP.dis.s; \
	    ./bin/vm --memory 2M --rom roms/M0 \
	        --tape_01 "$$rom".TEMP.dis_cat.s \
	        --tape_02 "$$rom".TEMP.hex2 > /dev/null 2>&1; \
	    rm "$$rom".TEMP.dis_cat.s ; \
	    ./bin/vm --memory 256K --rom roms/stage1_assembler-2 \
	        --tape_01 "$$rom".TEMP.hex2 \
	        --tape_02 "$$rom".TEMP > /dev/null 2>&1; \
	    rm "$$rom".TEMP.hex2; \
	    cmp roms/"$$rom" "$$rom".TEMP; \
	    rm "$$rom".TEMP; \
	done;

test: ALL-ROMS
	sha256sum -c test/SHA256SUMS

test-all: ALL-ROMS test/SHA256SUMS test_stage0_monitor_asm_match testM0 testdisasmpy
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

prototype_M0-compact: M0-macro-compact.c | prototypes
	gcc stage1/High_level_prototypes/M0-macro-compact.c -o prototypes/prototype_M0-compact

prototype_lisp: stage2/High_level_prototypes/lisp/lisp.c stage2/High_level_prototypes/lisp/lisp.h stage2/High_level_prototypes/lisp/lisp_cell.c stage2/High_level_prototypes/lisp/lisp_eval.c stage2/High_level_prototypes/lisp/lisp_print.c stage2/High_level_prototypes/lisp/lisp_read.c | prototypes
	gcc -O2 stage2/High_level_prototypes/lisp/lisp.h \
	        stage2/High_level_prototypes/lisp/lisp.c \
	        stage2/High_level_prototypes/lisp/lisp_cell.c \
	        stage2/High_level_prototypes/lisp/lisp_eval.c \
	        stage2/High_level_prototypes/lisp/lisp_print.c \
	        stage2/High_level_prototypes/lisp/lisp_read.c \
	        -o prototypes/prototype_lisp


# Clean up after ourselves
.PHONY: clean
clean:
	rm -f libvm.so libvm-production.so bin/vm bin/vm-production
	rm -rf test/stage0_test_scratch prototypes/

.PHONY: clean-hard
clean-hard: clean
	rm -rf bin/ roms/ prototypes/

.PHONY: clean-hardest
clean-hardest:
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
