import ctypes

vm = ctypes.CDLL('./libvm.so')

vm.initialize_lilith()
c_s = ctypes.create_string_buffer("foo".encode('ascii'))
vm.load_lilith(c_s)

vm.get_register.argtype = ctypes.c_uint
vm.get_register.restype = ctypes.c_uint

R0 = vm.get_register(3)
print( R0)

vm.get_byte.argtype = ctypes.c_uint
vm.get_byte.restype = ctypes.c_ubyte

for i in range(0, 20):
	print(vm.get_byte(i))

vm.get_memory.restype = ctypes.c_char_p
print( (vm.get_memory()).decode('utf-8'))
