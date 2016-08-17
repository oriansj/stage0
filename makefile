all: libvm vm

libvm: wrapper.c vm_instructions.c vm_decode.c vm.h
	gcc -ggdb -shared -Wl,-soname,libvm.so -o libvm.so -fPIC wrapper.c vm_instructions.c vm_decode.c vm.h

vm: vm.h vm.c vm_instructions.c vm_decode.c
	gcc -ggdb vm.h vm.c vm_instructions.c vm_decode.c -o bin/vm

clean:
	rm libvm.so bin/vm

production: libvm-production vm-production

libvm-production: wrapper.c vm_instructions.c vm_decode.c vm.h
	gcc -shared -Wl,-soname,libvm.so -o libvm.so -fPIC wrapper.c vm_instructions.c vm_decode.c vm.h

vm-production: vm.h vm.c vm_instructions.c vm_decode.c
	gcc vm.h vm.c vm_instructions.c vm_decode.c -o vm
