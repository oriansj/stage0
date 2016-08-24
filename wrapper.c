#include "vm.h"
#define DEBUG true
uint32_t performance_counter;
static struct lilith* Globalvm;

void unpack_byte(uint8_t a, char* c);

/* Load program tape into Memory */
void load_program(struct lilith* vm, char* name)
{
	FILE* program;
	program = fopen(name, "r");

	/* Figure out how much we need to load */
	fseek(program, 0, SEEK_END);
	size_t end = ftell(program);
	rewind(program);

	/* Load the entire tape into memory */
	fread(vm->memory, 1, end, program);

	fclose(program);
}

void execute_vm(struct lilith* vm)
{
	struct Instruction* current;
	current = calloc(1, sizeof(struct Instruction));

	read_instruction(vm, current);
	eval_instruction(vm, current);

	free(current);
	return;
}

void initialize_lilith()
{
	struct lilith* vm;
	vm = create_vm(1 << 30);
	Globalvm = vm;
}

void load_lilith(char* name)
{
	load_program(Globalvm, name);
}

unsigned int step_lilith()
{
	if(!Globalvm->halted)
	{
		execute_vm(Globalvm);
	}
	return Globalvm->ip;
}

unsigned int get_register(unsigned int reg)
{
	return Globalvm->reg[reg];
}

void set_register(unsigned int reg, unsigned int value)
{
	Globalvm->reg[reg] = value;
}

void set_memory(unsigned int address, unsigned char value)
{
	Globalvm->memory[address] = value;
}

unsigned char get_byte(unsigned int add)
{
	return Globalvm->memory[add];
}

void insert_address(char* p, uint32_t value)
{
	char* segment;
	segment = p;
	unpack_byte((value >> 24), segment);
	segment = segment + 2;
	unpack_byte((value >> 16)%256, segment);
	segment = segment + 2;
	unpack_byte((value >> 8)%256, segment);
	segment = segment + 2;
	unpack_byte((value%256), segment);
}

void process_Memory_Row(char* p, uint32_t addr)
{
	char* segment = p;
	strncpy(segment, "<tr>\n<td>", 9);
	segment = segment + 9;
	insert_address(segment, addr);
	segment = segment + 8;
	strncpy(segment, "</td>", 5);
	segment = segment + 5;
	int i;
	for(i = 0; i < 16; i = i + 1)
	{
		strncpy(segment, "<td>", 4);
		segment = segment + 4;
		unpack_byte(Globalvm->memory[i + addr], segment);
		segment = segment + 2;
		strncpy(segment, "</td>", 5);
		segment = segment + 5;
	}

	strncpy(segment, "\n</tr>\n", 7);
}

char* get_memory(unsigned int start)
{
	char* result = calloc(4096 * 205 + 1, sizeof(char));
	int i, point;
	point = 0;
	for(i = 0; i < 4096; i = i + 16)
	{
		process_Memory_Row(result + point, start + i);
		point = point + 205;
	}

	return result;
}
