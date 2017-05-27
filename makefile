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
all: libvm vm

production: libvm-production.so vm-production asm dis

development: vm libvm.so asm dis

# VM Builds
vm-minimal: vm.h vm_minimal.c vm_instructions.c vm_decode.c | bin
	gcc vm.h vm_minimal.c vm_instructions.c vm_decode.c -o bin/vm-minimal

vm: vm.h vm.c vm_instructions.c vm_decode.c tty.c | bin
	gcc -ggdb -Dtty_lib=true vm.h vm.c vm_instructions.c vm_decode.c tty.c -o bin/vm

vm-production: vm.h vm.c vm_instructions.c vm_decode.c | bin
	gcc vm.h vm.c vm_instructions.c vm_decode.c -o bin/vm-production

vm-trace: vm.h vm.c vm_instructions.c vm_decode.c tty.c dynamic_execution_trace.c | bin
	gcc -ggdb -Dtty_lib=true -DTRACE=true vm.h vm.c vm_instructions.c vm_decode.c tty.c dynamic_execution_trace.c -o bin/vm

# libVM Builds for Development tools
libvm.so: wrapper.c vm_instructions.c vm_decode.c vm.h tty.c
	gcc -ggdb -Dtty_lib=true -shared -Wl,-soname,libvm.so -o libvm.so -fPIC wrapper.c vm_instructions.c vm_decode.c vm.h tty.c

libvm-production.so: wrapper.c vm_instructions.c vm_decode.c vm.h
	gcc -shared -Wl,-soname,libvm.so -o libvm-production.so -fPIC wrapper.c vm_instructions.c vm_decode.c vm.h

# Primitive development tools, not required but it was handy
asm: High_level_prototypes/asm.c | bin
	gcc -ggdb High_level_prototypes/asm.c -o bin/asm

dis: High_level_prototypes/disasm.c | bin
	gcc -ggdb High_level_prototypes/disasm.c -o bin/dis

# Clean up after ourselves
.PHONY: clean
clean:
	rm -f libvm.so libvm-production.so bin/vm bin/vm-production

.PHONY: clean-hard
clean-hard: clean
	rm -rf bin/ roms/

.PHONY: clean-hardest
clean-hardest-You-probably-do-NOT-want-this-option:
	git reset --hard
	git clean -xdf

# Our essential folders
bin:
	mkdir -p bin

roms:
	mkdir -p roms
