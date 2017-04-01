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


all: libvm vm

libvm: wrapper.c vm_instructions.c vm_decode.c vm.h tty.c
	gcc -ggdb -Dtty_lib=true -shared -Wl,-soname,libvm.so -o libvm.so -fPIC wrapper.c vm_instructions.c vm_decode.c vm.h tty.c

vm: vm.h vm.c vm_instructions.c vm_decode.c tty.c
	gcc -ggdb -Dtty_lib=true vm.h vm.c vm_instructions.c vm_decode.c tty.c -o bin/vm

vm-trace: vm.h vm.c vm_instructions.c vm_decode.c tty.c dynamic_execution_trace.c
	gcc -ggdb -Dtty_lib=true -DTRACE=true vm.h vm.c vm_instructions.c vm_decode.c tty.c dynamic_execution_trace.c -o bin/vm

production: libvm-production vm-production asm dis

libvm-production: wrapper.c vm_instructions.c vm_decode.c vm.h
	gcc -shared -Wl,-soname,libvm.so -o libvm.so -fPIC wrapper.c vm_instructions.c vm_decode.c vm.h

vm-production: vm.h vm.c vm_instructions.c vm_decode.c
	gcc vm.h vm.c vm_instructions.c vm_decode.c -o bin/vm

development: vm libvm asm dis

asm: High_level_prototypes/asm.c
	gcc -ggdb High_level_prototypes/asm.c -o bin/asm

dis: High_level_prototypes/disasm.c
	gcc -ggdb High_level_prototypes/disasm.c -o bin/dis

clean:
	rm libvm.so bin/vm

clean-production:
	rm libvm.so bin/vm

clean-development:
	rm libvm.so bin/vm bin/asm bin/dis
