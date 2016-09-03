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
