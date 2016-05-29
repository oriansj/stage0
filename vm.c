#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* Virtual machine state */
struct lilith
{
	uint64_t *memory;
	uint64_t reg[16];
	uint64_t ip;
	bool halted;
	bool exception;
};

struct Instruction
{
	uint8_t opcode;
	uint32_t XOP;
	uint32_t Immediate;
	uint32_t HAL_CODE;
};

/* Allocate and intialize memory/state */
struct lilith* create_vm(size_t size)
{
	struct lilith* vm;
	vm = calloc(1, sizeof(struct lilith));
	vm->memory = calloc(size, sizeof(uint8_t));
	vm->halted = false;
	vm->exception = false;
	return vm;
}

/* Free up the memory we previously allocated */
void destroy_vm(struct lilith* vm)
{
	free(vm->memory);
	free(vm);
}

/* Load program tape into Memory */
void load_program(struct lilith* vm, char **argv)
{
	FILE* program;
	program = fopen(argv[1], "r");

	/* Figure out how much we need to load */
	fseek(program, 0, SEEK_END);
	size_t end = ftell(program);
	rewind(program);

	/* Load the entire tape into memory */
	fread(vm->memory, 1, end, program);

	fclose(program);
}

void read_instruction(struct lilith* vm, struct Instruction *current)
{
	memset(current, 0, sizeof(struct Instruction));
	uint8_t opcode, segment1, segment2, segment3;

	opcode = vm->memory[vm->ip];
	vm->ip = vm->ip + 1;
	segment1 = vm->memory[vm->ip];
	vm->ip = vm->ip + 1;
	segment2 = vm->memory[vm->ip];
	vm->ip = vm->ip + 1;
	segment3 = vm->memory[vm->ip];
	vm->ip = vm->ip + 1;

	/* Deal with NOPs */
	if (0x0 == opcode)
	{
		current->opcode = 0;
	} /* Deal with illegal instruction */
	else if (0xFF == opcode)
	{
		current->opcode = opcode;
		current->XOP = 0xFFFF;
		current->Immediate = 0xFFFF;
		current->HAL_CODE = 0xFFFF;
	} /* Deal with 4OP */
	else if (0x1 == (opcode/32))
	{
	} /* Deal with 3OP */
	else if (0x2 == (opcode/32))
	{
	} /* Deal with 2OP */
	else if (0x3 == (opcode/32))
	{
	} /* Deal with 1OP */
	else if (0x4 == (opcode/32))
	{
	} /* Deal with 2OPI */
	else if (0x5 == (opcode/32))
	{
	} /* Deal with 1OPI */
	else if (0x6 == (opcode/32))
	{
	} /* Deal with 0OPI */
	else if (0x7 == (opcode/32))
	{
	} /* Deal with Halcode */
	else if (0x8 == (opcode/32))
	{
	}

}

void execute_vm(struct lilith* vm)
{
	struct Instruction* current;
	current = calloc(1, sizeof(struct Instruction));

	while(!vm->halted)
	{
		read_instruction(vm, current);
	}

	free(current);
	return;
}

/* Standard C main program */
int main(int argc, char **argv)
{
	/* Make sure we have a program tape to run */
	if (argc < 2)
	{
		fprintf(stderr, "Usage: %s $FileName\nWhere $FileName is the name of the paper tape of the program being run\n", argv[0]);
		return EXIT_FAILURE;
	}

	/* Perform all the essential stages in order */
	struct lilith* vm;
	vm = create_vm(1 << 20);
	load_program(vm, argv);
	execute_vm(vm);
	destroy_vm(vm);

	return EXIT_SUCCESS;
}
