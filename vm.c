#include "vm.h"
#define DEBUG true;

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

/* Load instruction addressed at IP */
void read_instruction(struct lilith* vm, struct Instruction *current)
{
	memset(current, 0, sizeof(struct Instruction));
	/* Store IP for debugging */
	current->ip = vm->ip;

	/* Read the actual bytes and increment the IP */
	current->raw0 = (uint8_t)vm->memory[vm->ip];
	vm->ip = vm->ip + 1;
	current->raw1 = (uint8_t)vm->memory[vm->ip];
	vm->ip = vm->ip + 1;
	current->raw2 = (uint8_t)vm->memory[vm->ip];
	vm->ip = vm->ip + 1;
	current->raw3 = (uint8_t)vm->memory[vm->ip];
	vm->ip = vm->ip + 1;
	unpack_instruction(current);
}

/* Process 4OP Integer instructions */
bool eval_4OP_Int(struct lilith* vm, struct Instruction* c)
{
	return true;
}

/* Process 3OP Integer instructions */
bool eval_3OP_Int(struct lilith* vm, struct Instruction* c)
{
	switch(c->raw_XOP)
	{
		case 0x000: /* ADD */
		{
			vm->reg[c->reg0] = vm->reg[c->reg1] + vm->reg[c->reg2];
			break;
		}
		default: return true;
	}
	return false;
}

/* Process 2OP Integer instructions */
bool eval_2OP_Int(struct lilith* vm, struct Instruction* c)
{
	return true;
}

/* Process 1OP Integer instructions */
bool eval_1OP_Int(struct lilith* vm, struct Instruction* c)
{
	return true;
}

/* Process 2OPI Integer instructions */
bool eval_2OPI_Int(struct lilith* vm, struct Instruction* c)
{
	/* 0x0E ... 0x2B */
	switch(c->raw0)
	{
		case 0x0E: /* ADDI */
		{
			vm->reg[c->reg0] = (int8_t)(vm->reg[c->reg1] + c->raw_Immediate);
			break;
		}
		case 0x0F: /* ADDUI */
		{
			vm->reg[c->reg0] = vm->reg[c->reg1] + c->raw_Immediate;			break;
		}
		default: return true;
	}
	return false;
}

/* Use Opcode to decide what to do and then have it done */
void eval_instruction(struct lilith* vm, struct Instruction* current)
{
	bool invalid = false;

	switch(current->raw0)
	{
		case 0x00: /* Deal with NOPs */
		{
			vm->halted = true;
			return;
		}
		case 0x01:
		{
			decode_4OP(current);
			invalid = eval_4OP_Int(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x05:
		{
			decode_3OP(current);
			invalid = eval_3OP_Int(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x09:
		{
			decode_2OP(current);
			invalid = eval_2OP_Int(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x0D:
		{
			decode_1OP(current);
			invalid = eval_1OP_Int(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x0E ... 0x2B:
		{
			decode_2OPI(current);
			invalid = eval_2OPI_Int(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x2C:
		{
		}
		case 0x3C:
		{
		}
		case 0x42:
		{
		}
		case 0xFF: /* Deal with illegal instruction */
		default:
		{
fail:
			fprintf(stderr, "Unable to execute the following instruction:\n%c %c %c %c\n", current->raw0, current->raw1, current->raw2, current->raw3);
			fprintf(stderr, "%s\n", current->operation);
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
		eval_instruction(vm, current);
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
