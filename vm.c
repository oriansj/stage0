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
	int64_t tmp1, tmp2;
	uint64_t utmp1, utmp2;

	tmp1 = (int64_t)(vm->reg[c->reg1]);
	tmp2 = (int64_t)(vm->reg[c->reg2]);
	utmp1 = vm->reg[c->reg1];
	utmp2 = vm->reg[c->reg2];

	switch(c->raw_XOP)
	{
		case 0x000: /* ADD */
		{
			vm->reg[c->reg0] = (int64_t)(tmp1 + tmp2);
			break;
		}
		case 0x001: /* ADDU */
		{
			vm->reg[c->reg0] = utmp1 + utmp2;
			break;
		}
		case 0x002: /* SUB */
		{
			vm->reg[c->reg0] = (int64_t)(tmp1 - tmp2);
			break;
		}
		case 0x003: /* SUBU */
		{
			vm->reg[c->reg0] = utmp1 - utmp2;
			break;
		}
		case 0x004: /* CMP */
		{
			/* Clear bottom 3 bits of condition register */
			vm->reg[c->reg0] = vm->reg[c->reg0] & 0xFFFFFFFFFFFFFFF8;
			if(tmp1 > tmp2)
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | GreaterThan;
			}
			else if(tmp1 == tmp2)
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | EQual;
			}
			else
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | LessThan;
			}
			break;
		}
		case 0x005: /* CMPU */
		{
			/* Clear bottom 3 bits of condition register */
			vm->reg[c->reg0] = vm->reg[c->reg0] & 0xFFFFFFFFFFFFFFF8;
			if(utmp1 > utmp2)
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | GreaterThan;
			}
			else if(utmp1 == utmp2)
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | EQual;
			}
			else
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | LessThan;
			}
			break;
		}
		case 0x006: /* MUL */
		{
			break;
		}
		case 0x007: /* MULH */
		{
			break;
		}
		case 0x008: /* MULU */
		{
			break;
		}
		case 0x009: /* MULUH */
		{
			break;
		}
		case 0x00A: /* DIV */
		{
			break;
		}
		case 0x00B: /* MOD */
		{
			break;
		}
		case 0x00C: /* DIVU */
		{
			break;
		}
		case 0x00D: /* MODU */
		{
			break;
		}
		case 0x010: /* MAX */
		{
			break;
		}
		case 0x011: /* MAXU */
		{
			break;
		}
		case 0x012: /* MIN */
		{
			break;
		}
		case 0x013: /* MINU */
		{
			break;
		}
		case 0x014: /* PACK */
		{
			break;
		}
		case 0x015: /* UNPACK */
		{
			break;
		}
		case 0x016: /* PACK8.CO */
		{
			break;
		}
		case 0x017: /* PACK8U.CO */
		{
			break;
		}
		case 0x018: /* PACK16.CO */
		{
			break;
		}
		case 0x019: /* PACK16U.CO */
		{
			break;
		}
		case 0x01A: /* PACK32.CO */
		{
			break;
		}
		case 0x01B: /* PACK32U.CO */
		{
			break;
		}
		case 0x01C: /* PACK64.CO */
		{
			break;
		}
		case 0x01D: /* PACK64U.CO */
		{
			break;
		}
		case 0x020: /* AND */
		{
			break;
		}
		case 0x021: /* OR */
		{
			break;
		}
		case 0x022: /* XOR */
		{
			break;
		}
		case 0x023: /* NAND */
		{
			break;
		}
		case 0x024: /* NOR */
		{
			break;
		}
		case 0x025: /* XNOR */
		{
			break;
		}
		case 0x026: /* MPQ */
		{
			break;
		}
		case 0x027: /* LPQ */
		{
			break;
		}
		case 0x028: /* CPQ */
		{
			break;
		}
		case 0x029: /* BPQ */
		{
			break;
		}
		case 0x030: /* SAL */
		{
			break;
		}
		case 0x031: /* SAR */
		{
			break;
		}
		case 0x032: /* SL0 */
		{
			break;
		}
		case 0x033: /* SR0 */
		{
			break;
		}
		case 0x034: /* SL1 */
		{
			break;
		}
		case 0x035: /* SR1 */
		{
			break;
		}
		case 0x036: /* ROL */
		{
			break;
		}
		case 0x037: /* ROR */
		{
			break;
		}
		default: return true;
	}
	return false;
}

/* Process 2OP Integer instructions */
bool eval_2OP_Int(struct lilith* vm, struct Instruction* c)
{
	switch(c->raw_XOP)
	{
		case 0x0000: /* NEG */
		{
			break;
		}
		case 0x0001: /* ABS */
		{
			break;
		}
		case 0x0002: /* NABS */
		{
			break;
		}
		case 0x0003: /* SWAP */
		{
			break;
		}
		case 0x0004: /* COPY */
		{
			break;
		}
		case 0x0005: /* MOVE */
		{
			break;
		}
		case 0x0100: /* BRANCH */
		{
			break;
		}
		default: return true;
	}
	return false;
}

/* Process 1OP Integer instructions */
bool eval_1OP_Int(struct lilith* vm, struct Instruction* c)
{
	switch(c->raw_XOP)
	{
		case 0x00000: /* READPC */
		{
			break;
		}
		case 0x00001: /* READSCID */
		{
			break;
		}
		case 0x00002: /* FALSE */
		{
			break;
		}
		case 0x00003: /* TRUE */
		{
			break;
		}
		case 0x01000: /* JSR_COROUTINE */
		{
			break;
		}
		default: return true;
	}
	return false;
}

/* Process 2OPI Integer instructions */
bool eval_2OPI_Int(struct lilith* vm, struct Instruction* c)
{
	int64_t tmp1;
	uint64_t utmp1;

	tmp1 = (int64_t)(vm->reg[c->reg1]);
	utmp1 = vm->reg[c->reg1];

	/* 0x0E ... 0x2B */
	switch(c->raw0)
	{
		case 0x0E: /* ADDI */
		{
			vm->reg[c->reg0] = (int64_t)(tmp1 + c->raw_Immediate);
			break;
		}
		case 0x0F: /* ADDUI */
		{
			vm->reg[c->reg0] = utmp1 + c->raw_Immediate;
			break;
		}
		case 0x10: /* SUB */
		{
			vm->reg[c->reg0] = (int64_t)(tmp1 - c->raw_Immediate);
			break;
		}
		case 0x11: /* SUBU */
		{
			vm->reg[c->reg0] = utmp1 + c->raw_Immediate;
			break;
		}
		default: return true;
	}
	return false;
}

/* Process 1OPI instructions */
bool eval_1OPI(struct lilith* vm, struct Instruction* c)
{
	bool C, B, O, GT, EQ, LT;
	uint64_t tmp;

	tmp = vm->reg[c->reg0];

	C = tmp & Carry;
	B = tmp & Borrow;
	O = tmp & Overflow;
	GT = tmp & GreaterThan;
	EQ = tmp & EQual;
	LT = tmp & LessThan;

	/* 0x2C ... 0x3B */
	switch(c->raw0)
	{
		case 0x2C: /*JMP.C*/
		{
			if(1 == C)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x2D: /*JMP.B*/
		{
			if(1 == B)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x2E: /*JMP.O*/
		{
			if(1 == O)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x2F: /*JMP.G*/
		{
			if(1 == GT)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x30: /*JMP.GE*/
		{
			if((1 == GT) || (1 == EQ))
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x31: /*JMP.E*/
		{
			if(1 == EQ)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x32: /*JMP.NE*/
		{
			if(1 != EQ)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x33: /*JMP.LE*/
		{
			if((1 == EQ) || (1 == LT))
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x34: /*JMP.L*/
		{
			if(1 == LT)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
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
		case 0x2C ... 0x3B:
		{
			decode_1OPI(current);
			invalid = eval_1OPI(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x3C: /* JUMP */
		{
			decode_0OPI(current);
			/* Adust the IP relative the the start of this instruction*/
			vm->ip = vm->ip + current->raw_Immediate - 4;
			break;
		}
		case 0x42:
		{
		}
		case 0xFF: /* Deal with HALT */
		{
			vm->halted = true;
			fprintf(stderr, "Computer Program has Halted\n");
			break;
		}
		default: /* Deal with illegal instruction */
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
