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
	uint64_t ip;
	uint8_t opcode;
	uint32_t XOP;
	uint32_t Immediate;
	uint32_t HAL_CODE;
	uint8_t reg0;
	uint8_t reg1;
	uint8_t reg2;
	uint8_t reg3;
	bool invalid;
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

	/* Store IP for debugging */
	current->ip = vm->ip;

	/* Read the actual bytes and increment the IP */
	opcode = vm->memory[vm->ip];
	vm->ip = vm->ip + 1;
	segment1 = vm->memory[vm->ip];
	vm->ip = vm->ip + 1;
	segment2 = vm->memory[vm->ip];
	vm->ip = vm->ip + 1;
	segment3 = vm->memory[vm->ip];
	vm->ip = vm->ip + 1;

	/* The first byte is always the master opcode */
	current->opcode = opcode;
	current->invalid = false;
	current->XOP = 0xFFFF;
	current->Immediate = 0xFFFF;
	current->HAL_CODE = 0xFFFF;
	current->reg0 = 0xFF;
	current->reg1 = 0xFF;
	current->reg2 = 0xFF;
	current->reg3 = 0xFF;

	/* Extract the fields from the instruction for easier evaluation */
	switch(opcode)
	{
		case 0x00: /* Deal with NOPs */
		{
			break;
		}
		case 0x01 ... 0x04: /* Deal with 4OP */
		{
			current->XOP = segment1;
			current->Immediate = 0;
			current->reg0 = segment2/16;
			current->reg1 = segment2%16;
			current->reg2 = segment3/16;
			current->reg3 = segment3%16;
			break;
		}
		case 0x05 ... 0x08:  /* Deal with 3OP */
		{
			current->XOP = segment1*16 + segment2/16;
			current->Immediate = 0;
			current->reg0 = segment2%16;
			current->reg1 = segment3/16;
			current->reg2 = segment3%16;
			break;
		}
		case 0x09 ... 0x0C: /* Deal with 2OP */
		{
			current->XOP = segment1*256 + segment2;
			current->Immediate = 0;
			current->reg0 = segment3/16;
			current->reg1 = segment3%16;
			break;
		}
		case 0x0D: /* Deal with 1OP */
		{
			current->XOP = segment1*4096 + segment2*16 + segment3/16;
			current->Immediate = 0;
			current->reg0 = segment3%16;
			break;
		}
		case 0x0E ... 0x2B: /* Deal with 2OPI */
		{
			current->XOP = 0;
			current->Immediate = segment2*256 + segment3;
			current->reg0 = segment1/16;
			current->reg1 = segment1%16;
			break;
		}
		case 0x2C ... 0x3B: /* Deal with 1OPI */
		{
			current->XOP = 0;
			current->Immediate = (segment1%16)*4096 + segment2*256 + segment3;
			current->HAL_CODE = 0;
			current->reg0 = segment1/16;
			break;
		}
		case 0x3C:  /* Deal with 0OPI */
		{
			current->XOP = 0;
			current->Immediate = segment1*4096 + segment2*256 + segment3;
			break;
		}
		case 0x42: /* Deal with Halcode */
		{
			current->XOP = 0;
			current->HAL_CODE = segment1*4096 + segment2*256 + segment3;
			break;
		}
		case 0xFF: /* Deal with illegal instruction */
		default:
		{
			current->invalid = true;
			break;
		}
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
