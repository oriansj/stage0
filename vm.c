#include "vm.h"
#define DEBUG true

FILE* tape_01;
FILE* tape_02;
uint32_t performance_counter;

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

/* Process HALCODE instructions */
bool eval_HALCODE(struct lilith* vm, struct Instruction* c)
{
	char Name[20] = "ILLEGAL_HALCODE";
	switch(c->HAL_CODE)
	{
		case 0x100000: /* fopen */
		{
			strncpy(Name, "FOPEN", 19);

			if(0x00001100 == vm->reg[0])
			{
				tape_01 = fopen("tape_01", "r");
			}

			if (0x00001101 == vm->reg[0])
			{
				tape_02 = fopen("tape_02", "w");
			}
			break;
		}
		case 0x100001: /* fclose */
		{
			strncpy(Name, "FCLOSE", 19);

			if(0x00001100 == vm->reg[0])
			{
				fclose(tape_01);
			}

			if (0x00001101 == vm->reg[0])
			{
				fclose(tape_02);
			}
			break;
		}
		case 0x100002: /* fseek */
		{
			strncpy(Name, "FSEEK", 19);

			if(0x00001100 == vm->reg[0])
			{
				fseek(tape_01, vm->reg[1], SEEK_CUR);
			}

			if (0x00001101 == vm->reg[0])
			{
				fseek(tape_02, vm->reg[1], SEEK_CUR);
			}
			break;
		}
		case 0x100003: /* rewind */
		{
			strncpy(Name, "REWIND", 19);

			if(0x00001100 == vm->reg[0])
			{
				rewind(tape_01);
			}

			if (0x00001101 == vm->reg[0])
			{
				rewind(tape_02);
			}
			break;
		}
		case 0x100100: /* fgetc */
		{
			strncpy(Name, "FGETC", 19);
			int32_t byte = -1;

			if (0x00000000 == vm->reg[1])
			{
				byte = fgetc(stdin);
			}

			if(0x00001100 == vm->reg[1])
			{
				byte = fgetc(tape_01);
			}

			if (0x00001101 == vm->reg[1])
			{
				byte = fgetc(tape_02);
			}

			vm->reg[0] = byte;

			break;
		}
		case 0x100200: /* fputc */
		{
			strncpy(Name, "FPUTC", 19);
			int32_t byte = vm->reg[0];

			if (0x00000000 == vm->reg[1])
			{
				fputc(byte, stdout);
			}

			if(0x00001100 == vm->reg[1])
			{
				fputc(byte, tape_01);
			}

			if (0x00001101 == vm->reg[1])
			{
				fputc(byte, tape_02);
			}

			break;
		}
		default: return true;
	}

	if(DEBUG) {fprintf(stdout, "# %s\n", Name);}
	return false;
}

/* Process 4OP Integer instructions */
bool eval_4OP_Int(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;
	uint32_t utmp1, utmp2;
	int64_t btmp1;
	uint64_t ubtmp1;
	bool C, B;
	char Name[20] = "ILLEGAL_4OP";

	utmp1 = vm->reg[c->reg3];

	C = utmp1 & Carry;
	B = utmp1 & Borrow;

	switch(c->raw_XOP)
	{
		case 0x00: /* ADD.CI */
		{
			strncpy(Name, "ADD.CI", 19);
			tmp1 = vm->reg[c->reg1];
			tmp2 = vm->reg[c->reg2];

			/* If carry bit set add in the carry */
			if(1 == C)
			{
				vm->reg[c->reg0] = tmp1 + tmp2 + 1;
			}
			else
			{
				vm->reg[c->reg0] = tmp1 + tmp2;
			}
			break;
		}
		case 0x01: /* ADD.CO */
		{
			strncpy(Name, "ADD.CO", 19);
			tmp1 = (int32_t)(vm->reg[c->reg1]);
			tmp2 = (int32_t)(vm->reg[c->reg2]);
			btmp1 = ((int64_t)tmp1) + ((int64_t)tmp2);

			/* If addition exceeds int32_t MAX, set carry bit */
			if(1 == ( btmp1 >> 31 ))
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] | Carry;
			}
			else
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Carry);
			}

			/* Standard addition */
			vm->reg[c->reg0] = (tmp1 + tmp2);
			break;
		}
		case 0x02: /* ADD.CIO */
		{
			strncpy(Name, "ADD.CIO", 19);
			tmp1 = (int32_t)(vm->reg[c->reg1]);
			tmp2 = (int32_t)(vm->reg[c->reg2]);
			btmp1 = ((int64_t)tmp1) + ((int64_t)tmp2);

			/* If addition exceeds int32_t MAX, set carry bit */
			if(1 == ( btmp1 >> 31 ))
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] | Carry;
			}
			else
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Carry);
			}

			/* If carry bit set before operation add in the carry */
			if(1 == C)
			{
				vm->reg[c->reg0] = tmp1 + tmp2 + 1;
			}
			else
			{
				vm->reg[c->reg0] = tmp1 + tmp2;
			}
			break;
		}
		case 0x03: /* ADDU.CI */
		{
			strncpy(Name, "ADDU.CI", 19);
			utmp1 = vm->reg[c->reg1];
			utmp2 = vm->reg[c->reg2];

			/* If carry bit set add in the carry */
			if(1 == C)
			{
				vm->reg[c->reg0] = utmp1 + utmp2 + 1;
			}
			else
			{
				vm->reg[c->reg0] = utmp1 + utmp2;
			}
			break;
		}
		case 0x04: /* ADDU.CO */
		{
			strncpy(Name, "ADDU.CO", 19);
			utmp1 = vm->reg[c->reg1];
			utmp2 = vm->reg[c->reg2];
			ubtmp1 = ((uint64_t)utmp1) + ((uint64_t)utmp2);

			/* If addition exceeds uint32_t MAX, set carry bit */
			if(0 != ( ubtmp1 >> 32 ))
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] | Carry;
			}
			else
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Carry);
			}

			/* Standard addition */
			vm->reg[c->reg0] = (utmp1 + utmp2);
			break;
		}
		case 0x05: /* ADDU.CIO */
		{
			strncpy(Name, "ADDU.CIO", 19);
			utmp1 = vm->reg[c->reg1];
			utmp2 = vm->reg[c->reg2];
			ubtmp1 = ((uint64_t)utmp1) + ((uint64_t)utmp2);

			/* If addition exceeds uint32_t MAX, set carry bit */
			if(0 != ( ubtmp1 >> 32 ))
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] | Carry;
			}
			else
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Carry);
			}

			/* If carry bit was set before operation add in the carry */
			if(1 == C)
			{
				vm->reg[c->reg0] = utmp1 + utmp2 + 1;
			}
			else
			{
				vm->reg[c->reg0] = utmp1 + utmp2;
			}
			break;
		}
		case 0x06: /* SUB.BI */
		{
			strncpy(Name, "SUB.BI", 19);
			tmp1 = (int32_t)(vm->reg[c->reg1]);
			tmp2 = (int32_t)(vm->reg[c->reg2]);

			/* If borrow bit set subtract out the borrow */
			if(1 == B)
			{
				vm->reg[c->reg0] = tmp1 - tmp2 - 1;
			}
			else
			{
				vm->reg[c->reg0] = tmp1 - tmp2;
			}
			break;
		}
		case 0x07: /* SUB.BO */
		{
			strncpy(Name, "SUB.BO", 19);
			btmp1 = (int64_t)(vm->reg[c->reg1]);
			tmp1 = (int32_t)(vm->reg[c->reg2]);
			tmp2 = (int32_t)(btmp1 - tmp1);

			/* If subtraction goes below int32_t MIN set borrow */
			if(btmp1 != (tmp2 + tmp1))
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] | Borrow;
			}
			else
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Borrow);
			}

			/* Standard subtraction */
			vm->reg[c->reg0] = tmp2;
			break;
		}
		case 0x08: /* SUB.BIO */
		{
			strncpy(Name, "SUB.BIO", 19);
			btmp1 = (int64_t)(vm->reg[c->reg1]);
			tmp1 = (int32_t)(vm->reg[c->reg2]);
			tmp2 = (int32_t)(btmp1 - tmp1);

			/* If subtraction goes below int32_t MIN set borrow */
			if(btmp1 != (tmp2 + tmp1))
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] | Borrow;
			}
			else
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Borrow);
			}

			/* If borrow bit was set prior to operation subtract out the borrow */
			if(1 == B)
			{
				vm->reg[c->reg0] = tmp2 - 1;
			}
			else
			{
				vm->reg[c->reg0] = tmp2;
			}
			break;
		}
		case 0x09: /* SUBU.BI */
		{
			strncpy(Name, "SUBU.BI", 19);
			utmp1 = vm->reg[c->reg1];
			utmp2 = vm->reg[c->reg2];

			/* If borrow bit set subtract out the borrow */
			if(1 == B)
			{
				vm->reg[c->reg0] = utmp1 - utmp2 - 1;
			}
			else
			{
				vm->reg[c->reg0] = utmp1 - utmp2;
			}
			break;
		}
		case 0x0A: /* SUBU.BO */
		{
			strncpy(Name, "SUBU.BO", 19);
			utmp1 = vm->reg[c->reg1];
			utmp2 = vm->reg[c->reg2];
			ubtmp1 = (uint64_t)(utmp1 - utmp2);

			/* If subtraction goes below uint32_t MIN set borrow */
			if(utmp1 != (ubtmp1 + utmp2))
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] | Borrow;
			}
			else
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Borrow);
			}

			/* Standard subtraction */
			vm->reg[c->reg0] = (utmp1 - utmp2);
			break;
		}
		case 0x0B: /* SUBU.BIO */
		{
			strncpy(Name, "SUBU.BIO", 19);
			utmp1 = vm->reg[c->reg1];
			utmp2 = vm->reg[c->reg2];
			ubtmp1 = (uint64_t)(utmp1 - utmp2);

			/* If subtraction goes below uint32_t MIN set borrow */
			if(utmp1 != (ubtmp1 + utmp2))
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] | Borrow;
			}
			else
			{
				vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Borrow);
			}

			/* If borrow bit was set prior to operation subtract out the borrow */
			if(1 == B)
			{
				vm->reg[c->reg0] = utmp1 - utmp2 - 1;
			}
			else
			{
				vm->reg[c->reg0] = utmp1 - utmp2;
			}
			break;
		}
		case 0x0C: /* MULTIPLY */
		{
			strncpy(Name, "MULTIPLY", 19);
			tmp1 = (int32_t)(vm->reg[c->reg2]);
			tmp2 = (int32_t)( vm->reg[c->reg3]);
			btmp1 = ((int64_t)tmp1) * ((int64_t)tmp2);
			vm->reg[c->reg0] = (int32_t)(btmp1 % 0x100000000);
			vm->reg[c->reg1] = (int32_t)(btmp1 / 0x100000000);
			break;
		}
		case 0x0D: /* MULTIPLYU */
		{
			strncpy(Name, "MULTIPLYU", 19);
			ubtmp1 = (uint64_t)(vm->reg[c->reg2]) * (uint64_t)(vm->reg[c->reg3]);
			vm->reg[c->reg0] = ubtmp1 % 0x100000000;
			vm->reg[c->reg1] = ubtmp1 / 0x100000000;
			break;
		}
		case 0x0E: /* DIVIDE */
		{
			strncpy(Name, "DIVIDE", 19);
			tmp1 = (int32_t)(vm->reg[c->reg2]);
			tmp2 = (int32_t)(vm->reg[c->reg3]);
			vm->reg[c->reg0] = tmp1 / tmp2;
			vm->reg[c->reg1] = tmp1 % tmp2;
			break;
		}
		case 0x0F: /* DIVIDEU */
		{
			strncpy(Name, "DIVIDEU", 19);
			utmp1 = vm->reg[c->reg2];
			utmp2 = vm->reg[c->reg3];
			vm->reg[c->reg0] = utmp1 / utmp2;
			vm->reg[c->reg1] = utmp1 % utmp2;
			break;
		}
		case 0x10: /* MUX */
		{
			strncpy(Name, "MUX", 19);
			vm->reg[c->reg0] = ((vm->reg[c->reg2] & ~(vm->reg[c->reg1])) |
								(vm->reg[c->reg3] & vm->reg[c->reg1]));
			break;
		}
		case 0x11: /* NMUX */
		{
			strncpy(Name, "NMUX", 19);
			vm->reg[c->reg0] = ((vm->reg[c->reg2] & vm->reg[c->reg1]) |
								(vm->reg[c->reg3] & ~(vm->reg[c->reg1])));
			break;
		}
		case 0x12: /* SORT */
		{
			strncpy(Name, "SORT", 19);
			tmp1 = (int32_t)(vm->reg[c->reg2]);
			tmp2 = (int32_t)(vm->reg[c->reg3]);

			if(tmp1 > tmp2)
			{
				vm->reg[c->reg0] = tmp1;
				vm->reg[c->reg1] = tmp2;
			}
			else
			{
				vm->reg[c->reg1] = tmp1;
				vm->reg[c->reg0] = tmp2;
			}
			break;
		}
		case 0x13: /* SORTU */
		{
			strncpy(Name, "SORTU", 19);
			utmp1 = vm->reg[c->reg2];
			utmp2 = vm->reg[c->reg3];

			if(utmp1 > utmp2)
			{
				vm->reg[c->reg0] = utmp1;
				vm->reg[c->reg1] = utmp2;
			}
			else
			{
				vm->reg[c->reg1] = utmp1;
				vm->reg[c->reg0] = utmp2;
			}
			break;
		}
		default: return true;
	}
	if(DEBUG) {fprintf(stdout, "# %s reg%u reg%u reg%u reg%u\n", Name, c->reg0, c->reg1, c->reg2, c->reg3);}
	return false;
}

/* Process 3OP Integer instructions */
bool eval_3OP_Int(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;
	uint32_t utmp1, utmp2;
	char Name[20] = "ILLEGAL_3OP";

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);
	utmp1 = vm->reg[c->reg1];
	utmp2 = vm->reg[c->reg2];

	switch(c->raw_XOP)
	{
		case 0x000: /* ADD */
		{
			strncpy(Name, "ADD", 19);
			vm->reg[c->reg0] = (int32_t)(tmp1 + tmp2);
			break;
		}
		case 0x001: /* ADDU */
		{
			strncpy(Name, "ADDU", 19);
			vm->reg[c->reg0] = utmp1 + utmp2;
			break;
		}
		case 0x002: /* SUB */
		{
			strncpy(Name, "SUB", 19);
			vm->reg[c->reg0] = (int32_t)(tmp1 - tmp2);
			break;
		}
		case 0x003: /* SUBU */
		{
			strncpy(Name, "SUBU", 19);
			vm->reg[c->reg0] = utmp1 - utmp2;
			break;
		}
		case 0x004: /* CMP */
		{
			strncpy(Name, "CMP", 19);
			/* Clear bottom 3 bits of condition register */
			vm->reg[c->reg0] = vm->reg[c->reg0] & 0xFFFFFFF8;
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
			strncpy(Name, "CMPU", 19);
			/* Clear bottom 3 bits of condition register */
			vm->reg[c->reg0] = vm->reg[c->reg0] & 0xFFFFFFF8;
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
			strncpy(Name, "MUL", 19);
			int64_t sum = tmp1 * tmp2;
			/* We only want the bottom 32bits */
			vm->reg[c->reg0] = sum % 0x100000000;
			break;
		}
		case 0x007: /* MULH */
		{
			strncpy(Name, "MULH", 19);
			int64_t sum = tmp1 * tmp2;
			/* We only want the top 32bits */
			vm->reg[c->reg0] = sum / 0x100000000;
			break;
		}
		case 0x008: /* MULU */
		{
			strncpy(Name, "MULU", 19);
			uint64_t sum = tmp1 * tmp2;
			/* We only want the bottom 32bits */
			vm->reg[c->reg0] = sum % 0x100000000;
			break;
		}
		case 0x009: /* MULUH */
		{
			strncpy(Name, "MULUH", 19);
			uint64_t sum = tmp1 * tmp2;
			/* We only want the top 32bits */
			vm->reg[c->reg0] = sum / 0x100000000;
			break;
		}
		case 0x00A: /* DIV */
		{
			strncpy(Name, "DIV", 19);
			vm->reg[c->reg0] = tmp1 / tmp2;
			break;
		}
		case 0x00B: /* MOD */
		{
			strncpy(Name, "MOD", 19);
			vm->reg[c->reg0] = tmp1 % tmp2;
			break;
		}
		case 0x00C: /* DIVU */
		{
			strncpy(Name, "DIVU", 19);
			vm->reg[c->reg0] = utmp1 / utmp2;
			break;
		}
		case 0x00D: /* MODU */
		{
			strncpy(Name, "MODU", 19);
			vm->reg[c->reg0] = utmp1 % utmp2;
			break;
		}
		case 0x010: /* MAX */
		{
			strncpy(Name, "MAX", 19);
			if(tmp1 > tmp2)
			{
				vm->reg[c->reg0] = tmp1;
			}
			else
			{
				vm->reg[c->reg0] = tmp2;
			}
			break;
		}
		case 0x011: /* MAXU */
		{
			strncpy(Name, "MAXU", 19);
			if(utmp1 > utmp2)
			{
				vm->reg[c->reg0] = utmp1;
			}
			else
			{
				vm->reg[c->reg0] = utmp2;
			}
			break;
		}
		case 0x012: /* MIN */
		{
			strncpy(Name, "MIN", 19);
			if(tmp1 < tmp2)
			{
				vm->reg[c->reg0] = tmp1;
			}
			else
			{
				vm->reg[c->reg0] = tmp2;
			}
			break;
		}
		case 0x013: /* MINU */
		{
			strncpy(Name, "MINU", 19);
			if(utmp1 < utmp2)
			{
				vm->reg[c->reg0] = utmp1;
			}
			else
			{
				vm->reg[c->reg0] = utmp2;
			}
			break;
		}
		case 0x014: /* PACK */
		{
			strncpy(Name, "PACK", 19);
			break;
		}
		case 0x015: /* UNPACK */
		{
			strncpy(Name, "UNPACK", 19);
			break;
		}
		case 0x016: /* PACK8.CO */
		{
			strncpy(Name, "PACK8.CO", 19);
			break;
		}
		case 0x017: /* PACK8U.CO */
		{
			strncpy(Name, "PACK8U.CO", 19);
			break;
		}
		case 0x018: /* PACK16.CO */
		{
			strncpy(Name, "PACK16.CO", 19);
			break;
		}
		case 0x019: /* PACK16U.CO */
		{
			strncpy(Name, "PACK16U.CO", 19);
			break;
		}
		case 0x01A: /* PACK32.CO */
		{
			strncpy(Name, "PACK32.CO", 19);
			break;
		}
		case 0x01B: /* PACK32U.CO */
		{
			strncpy(Name, "PACK32U.CO", 19);
			break;
		}
		case 0x020: /* AND */
		{
			strncpy(Name, "AND", 19);
			vm->reg[c->reg0] = utmp1 & utmp2;
			break;
		}
		case 0x021: /* OR */
		{
			strncpy(Name, "OR", 19);
			vm->reg[c->reg0] = utmp1 | utmp2;
			break;
		}
		case 0x022: /* XOR */
		{
			strncpy(Name, "XOR", 19);
			vm->reg[c->reg0] = utmp1 ^ utmp2;
			break;
		}
		case 0x023: /* NAND */
		{
			strncpy(Name, "NAND", 19);
			vm->reg[c->reg0] = ~(utmp1 & utmp2);
			break;
		}
		case 0x024: /* NOR */
		{
			strncpy(Name, "NOR", 19);
			vm->reg[c->reg0] = ~(utmp1 | utmp2);
			break;
		}
		case 0x025: /* XNOR */
		{
			strncpy(Name, "XNOR", 19);
			vm->reg[c->reg0] = ~(utmp1 ^ utmp2);
			break;
		}
		case 0x026: /* MPQ */
		{
			strncpy(Name, "MPQ", 19);
			vm->reg[c->reg0] = (~utmp1) & utmp2;
			break;
		}
		case 0x027: /* LPQ */
		{
			strncpy(Name, "LPQ", 19);
			vm->reg[c->reg0] = utmp1 & (~utmp2);
			break;
		}
		case 0x028: /* CPQ */
		{
			strncpy(Name, "CPQ", 19);
			vm->reg[c->reg0] = (~utmp1) | utmp2;
			break;
		}
		case 0x029: /* BPQ */
		{
			strncpy(Name, "BPQ", 19);
			vm->reg[c->reg0] = utmp1 | (~utmp2);
			break;
		}
		case 0x030: /* SAL */
		{
			strncpy(Name, "SAL", 19);
			vm->reg[c->reg0] = vm->reg[c->reg1] << vm->reg[c->reg2];
			break;
		}
		case 0x031: /* SAR */
		{
			strncpy(Name, "SAR", 19);
			vm->reg[c->reg0] = vm->reg[c->reg1] >> vm->reg[c->reg2];
			break;
		}
		case 0x032: /* SL0 */
		{
			strncpy(Name, "SL0", 19);
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], true, true);
			break;
		}
		case 0x033: /* SR0 */
		{
			strncpy(Name, "SR0", 19);
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], false, true);
			break;
		}
		case 0x034: /* SL1 */
		{
			strncpy(Name, "SL1", 19);
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], true, false);
			break;
		}
		case 0x035: /* SR1 */
		{
			strncpy(Name, "SR1", 19);
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], false, false);
			break;
		}
		case 0x036: /* ROL */
		{
			strncpy(Name, "ROL", 19);
			break;
		}
		case 0x037: /* ROR */
		{
			strncpy(Name, "ROR", 19);
			break;
		}
		case 0x038: /* LOADX */
		{
			strncpy(Name, "LOADX", 19);
			vm->reg[c->reg0] = readin_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2]);
			break;
		}
		case 0x039: /* LOADX8 */
		{
			strncpy(Name, "LOADX8", 19);
			vm->reg[c->reg0] = readin_byte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], true);
			break;
		}
		case 0x03A: /* LOADXU8 */
		{
			strncpy(Name, "LOADXU8", 19);
			vm->reg[c->reg0] = readin_byte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], false);
			break;
		}
		case 0x03B: /* LOADX16 */
		{
			strncpy(Name, "LOADX16", 19);
			vm->reg[c->reg0] = readin_doublebyte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], true);
			break;
		}
		case 0x03C: /* LOADXU16 */
		{
			strncpy(Name, "LOADXU16", 19);
			vm->reg[c->reg0] = readin_doublebyte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], false);
			break;
		}
		case 0x03D: /* LOADX32 */
		{
			strncpy(Name, "LOADX32", 19);
			vm->reg[c->reg0] = readin_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2]);
			break;
		}
		case 0x03E: /* LOADXU32 */
		{
			strncpy(Name, "LOADXU32", 19);
			vm->reg[c->reg0] = readin_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2]);
			break;
		}
		case 0x048: /* STOREX */
		{
			strncpy(Name, "STOREX", 19);
			writeout_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
			break;
		}
		case 0x049: /* STOREX8 */
		{
			strncpy(Name, "STOREX8", 19);
			writeout_byte(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
			break;
		}
		case 0x04A: /* STOREX16 */
		{
			strncpy(Name, "STOREX16", 19);
			writeout_doublebyte(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
			break;
		}
		case 0x04B: /* STOREX32 */
		{
			strncpy(Name, "STOREX32", 19);
			writeout_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
			break;
		}
		default: return true;
	}
	if(DEBUG) {fprintf(stdout, "# %s reg%u reg%u reg%u\n", Name, c->reg0, c->reg1, c->reg2);}
	return false;
}

/* Process 2OP Integer instructions */
bool eval_2OP_Int(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1 = (int32_t)(vm->reg[c->reg1]);
	uint32_t utmp1 = vm->reg[c->reg1];
	char Name[20] = "ILLEGAL_2OP";

	switch(c->raw_XOP)
	{
		case 0x0000: /* NEG */
		{
			strncpy(Name, "NEG", 19);
			vm->reg[c->reg0] = tmp1*-1;
			break;
		}
		case 0x0001: /* ABS */
		{
			strncpy(Name, "ABS", 19);
			if(0 <= tmp1)
			{
				vm->reg[c->reg0] = tmp1;
			}
			else
			{
				vm->reg[c->reg0] = tmp1*-1;
			}
			break;
		}
		case 0x0002: /* NABS */
		{
			strncpy(Name, "NABS", 19);
			if(0 > tmp1)
			{
				vm->reg[c->reg0] = tmp1;
			}
			else
			{
				vm->reg[c->reg0] = tmp1*-1;
			}
			break;
		}
		case 0x0003: /* SWAP */
		{
			strncpy(Name, "SWAP", 19);
			vm->reg[c->reg1] = vm->reg[c->reg0];
			vm->reg[c->reg0] = utmp1;
			break;
		}
		case 0x0004: /* COPY */
		{
			strncpy(Name, "COPY", 19);
			vm->reg[c->reg0] = utmp1;
			break;
		}
		case 0x0005: /* MOVE */
		{
			strncpy(Name, "MOVE", 19);
			vm->reg[c->reg0] = utmp1;
			vm->reg[c->reg1] = 0;
			break;
		}
		case 0x0100: /* BRANCH */
		{
			strncpy(Name, "BRANCH", 19);
			/* Write out the PC */
			writeout_Reg(vm, vm->reg[c->reg1], vm->ip);

			/* Update PC */
			vm->ip = vm->reg[c->reg0];
			break;
		}
		case 0x0101: /* CALL */
		{
			strncpy(Name, "CALL", 19);
			/* Write out the PC */
			writeout_Reg(vm, vm->reg[c->reg1], vm->ip);

			/* Update our index */
			vm->reg[c->reg1] = vm->reg[c->reg1] + 4;

			/* Update PC */
			vm->ip = vm->reg[c->reg0];
			break;
		}
		default: return true;
	}
	if(DEBUG) {fprintf(stdout, "# %s reg%u reg%u\n", Name, c->reg0, c->reg1);}
	return false;
}

/* Process 1OP Integer instructions */
bool eval_1OP_Int(struct lilith* vm, struct Instruction* c)
{
	char Name[20] = "ILLEGAL_1OP";
	switch(c->raw_XOP)
	{
		case 0x00000: /* READPC */
		{
			strncpy(Name, "READPC", 19);
			vm->reg[c->reg0] = vm->ip;
			break;
		}
		case 0x00001: /* READSCID */
		{
			strncpy(Name, "READSCID", 19);
			/* We only support Base 8,16 and 32*/
			vm->reg[c->reg0] = 0x00000007;
			break;
		}
		case 0x00002: /* FALSE */
		{
			strncpy(Name, "FALSE", 19);
			vm->reg[c->reg0] = 0;
			break;
		}
		case 0x00003: /* TRUE */
		{
			strncpy(Name, "TRUE", 19);
			vm->reg[c->reg0] = 0xFFFFFFFF;
			break;
		}
		case 0x01000: /* JSR_COROUTINE */
		{
			strncpy(Name, "JSR_COROUTINE", 19);
			vm->ip = vm->reg[c->reg0];
			break;
		}
		case 0x01001: /* RET */
		{
			strncpy(Name, "RET", 19);
			/* Update our index */
			vm->reg[c->reg0] = vm->reg[c->reg0] - 4;

			/* Read in the new PC */
			vm->ip = readin_Reg(vm, vm->reg[c->reg0]);

			/* Clear Stack Values */
			writeout_Reg(vm, vm->reg[c->reg0], 0);
			break;
		}
		case 0x02000: /* PUSHPC */
		{
			strncpy(Name, "PUSHPC", 19);
			/* Write out the PC */
			writeout_Reg(vm, vm->reg[c->reg0], vm->ip);

			/* Update our index */
			vm->reg[c->reg0] = vm->reg[c->reg0] + 4;
			break;
		}
		case 0x02001: /* POPPC */
		{
			strncpy(Name, "POPPC", 19);
			/* Read in the new PC */
			vm->ip = readin_Reg(vm, vm->reg[c->reg0]);

			/* Update our index */
			vm->reg[c->reg0] = vm->reg[c->reg0] - 4;
			break;
		}
		default: return true;
	}
	if(DEBUG) {fprintf(stdout, "# %s reg%u\n", Name, c->reg0);}
	return false;
}

/* Process 2OPI Integer instructions */
bool eval_2OPI_Int(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1;
	uint32_t utmp1;
	uint8_t raw0, raw1;
	char Name[20] = "ILLEGAL_2OPI";

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	utmp1 = vm->reg[c->reg1];

	/* 0x0E ... 0x2B */
	switch(c->raw0)
	{
		case 0x0E: /* ADDI */
		{
			strncpy(Name, "ADDI", 19);
			vm->reg[c->reg0] = (int32_t)(tmp1 + c->raw_Immediate);
			break;
		}
		case 0x0F: /* ADDUI */
		{
			strncpy(Name, "ADDUI", 19);
			vm->reg[c->reg0] = utmp1 + c->raw_Immediate;
			break;
		}
		case 0x10: /* SUBI */
		{
			strncpy(Name, "SUBI", 19);
			vm->reg[c->reg0] = (int32_t)(tmp1 - c->raw_Immediate);
			break;
		}
		case 0x11: /* SUBUI */
		{
			strncpy(Name, "SUBUI", 19);
			vm->reg[c->reg0] = utmp1 + c->raw_Immediate;
			break;
		}
		case 0x12: /* CMPI */
		{
			strncpy(Name, "CMPI", 19);
			/* Clear bottom 3 bits of condition register */
			vm->reg[c->reg0] = vm->reg[c->reg0] & 0xFFFFFFF8;
			if(tmp1 > c->raw_Immediate)
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | GreaterThan;
			}
			else if(tmp1 == c->raw_Immediate)
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | EQual;
			}
			else
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | LessThan;
			}
			break;
		}
		case 0x13: /* LOAD */
		{
			strncpy(Name, "LOAD", 19);
			vm->reg[c->reg0] = readin_Reg(vm, (utmp1 + c->raw_Immediate));
			break;
		}
		case 0x14: /* LOAD8 */
		{
			strncpy(Name, "LOAD8", 19);
			vm->reg[c->reg0] = readin_byte(vm, utmp1 + c->raw_Immediate, true);
			break;
		}
		case 0x15: /* LOADU8 */
		{
			strncpy(Name, "LOADU8", 19);
			vm->reg[c->reg0] = readin_byte(vm, utmp1 + c->raw_Immediate, false);
			break;
		}
		case 0x16: /* LOAD16 */
		{
			strncpy(Name, "LOAD16", 19);
			vm->reg[c->reg0] = readin_doublebyte(vm, utmp1 + c->raw_Immediate, true);
			break;
		}
		case 0x17: /* LOADU16 */
		{
			strncpy(Name, "LOADU16", 19);
			vm->reg[c->reg0] = readin_doublebyte(vm, utmp1 + c->raw_Immediate, false);
			break;
		}
		case 0x18: /* LOAD32 */
		{
			strncpy(Name, "LOAD32", 19);
			vm->reg[c->reg0] = readin_Reg(vm, (utmp1 + c->raw_Immediate));
			break;
		}
		case 0x19: /* LOADU32 */
		{
			strncpy(Name, "LOADU32", 19);
			vm->reg[c->reg0] = readin_Reg(vm, (utmp1 + c->raw_Immediate));
			break;
		}
		case 0x1F: /* CMPUI */
		{
			strncpy(Name, "CMPUI", 19);
			/* Clear bottom 3 bits of condition register */
			vm->reg[c->reg0] = vm->reg[c->reg0] & 0xFFFFFFF8;
			if(utmp1 > (uint32_t)c->raw_Immediate)
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | GreaterThan;
			}
			else if(utmp1 == (uint32_t)c->raw_Immediate)
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | EQual;
			}
			else
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | LessThan;
			}
			break;
		}
		case 0x20: /* STORE */
		{
			strncpy(Name, "STORE", 19);
			writeout_Reg(vm, (utmp1 + c->raw_Immediate), vm->reg[c->reg0]);
			break;
		}
		case 0x21: /* STORE8 */
		{
			strncpy(Name, "STORE8", 19);
			writeout_byte(vm, utmp1 + c->raw_Immediate, vm->reg[c->reg0]);
			break;
		}
		case 0x22: /* STORE16 */
		{
			strncpy(Name, "STORE16", 19);
			writeout_doublebyte(vm, utmp1 + c->raw_Immediate, vm->reg[c->reg0]);
			break;
		}
		case 0x23: /* STORE32 */
		{
			strncpy(Name, "STORE32", 19);
			writeout_Reg(vm, (utmp1 + c->raw_Immediate), vm->reg[c->reg0]);
			break;
		}
		default: return true;
	}
	if(DEBUG) {fprintf(stdout, "# %s reg%u reg%u %i\n", Name, c->reg0, c->reg1, c->raw_Immediate);}
	return false;
}

/* Process 1OPI Integer instructions */
bool eval_Integer_1OPI(struct lilith* vm, struct Instruction* c)
{
	bool C, B, O, GT, EQ, LT;
	uint32_t tmp;
	char Name[20] = "ILLEGAL_1OPI";

	tmp = vm->reg[c->reg0];

	C = tmp & Carry;
	B = tmp & Borrow;
	O = tmp & Overflow;
	GT = tmp & GreaterThan;
	EQ = tmp & EQual;
	LT = tmp & LessThan;

	/* 0x2C */
	switch(c->raw_XOP)
	{
		case 0x0: /* JUMP.C */
		{
			strncpy(Name, "JUMP.C", 19);
			if(1 == C)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x1: /* JUMP.B */
		{
			strncpy(Name, "JUMP.B", 19);
			if(1 == B)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x2: /* JUMP.O */
		{
			strncpy(Name, "JUMP.O", 19);
			if(1 == O)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x3: /* JUMP.G */
		{
			strncpy(Name, "JUMP.G", 19);
			if(1 == GT)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x4: /* JUMP.GE */
		{
			strncpy(Name, "JUMP.GE", 19);
			if((1 == GT) || (1 == EQ))
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x5: /* JUMP.E */
		{
			strncpy(Name, "JUMP.E", 19);
			if(1 == EQ)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x6: /* JUMP.NE */
		{
			strncpy(Name, "JUMP.NE", 19);
			if(1 != EQ)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x7: /* JUMP.LE */
		{
			strncpy(Name, "JUMP.LE", 19);
			if((1 == EQ) || (1 == LT))
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x8: /* JUMP.L */
		{
			strncpy(Name, "JUMP.L", 19);
			if(1 == LT)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x9: /* JUMP.Z */
		{
			strncpy(Name, "JUMP.Z", 19);
			if(0 == tmp)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0xA: /* JUMP.NZ */
		{
			strncpy(Name, "JUMP.NZ", 19);
			if(0 != tmp)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		default: return true;
	}
	if(DEBUG) {fprintf(stdout, "# %s reg%u %d\n", Name, c->reg0, c->raw_Immediate);}
	return false;
}

bool eval_branch_1OPI(struct lilith* vm, struct Instruction* c)
{
	char Name[20] = "ILLEGAL_1OPI";
	switch(c->raw_XOP)
	{
		case 0x0: /* CALLI */
		{
			strncpy(Name, "CALLI", 19);
			/* Write out the PC */
			writeout_Reg(vm, vm->reg[c->reg0], vm->ip);

			/* Update our index */
			vm->reg[c->reg0] = vm->reg[c->reg0] + 4;

			/* Update PC */
			vm->ip = vm->ip + c->raw_Immediate - 4;

			break;
		}
		case 0x1: /* LOADI */
		{
			strncpy(Name, "LOADI", 19);
			vm->reg[c->reg0] = (int16_t)c->raw_Immediate;
			break;
		}
		case 0x2: /* LOADUI*/
		{
			strncpy(Name, "LOADU", 19);
			vm->reg[c->reg0] = c->raw_Immediate;
			break;
		}
		case 0x3: /* SALI */
		{
			strncpy(Name, "SALI", 19);
			vm->reg[c->reg0] = vm->reg[c->reg0] << c->raw_Immediate;
			break;
		}
		case 0x4: /* SARI */
		{
			strncpy(Name, "SARI", 19);
			vm->reg[c->reg0] = vm->reg[c->reg0] >> c->raw_Immediate;
			break;
		}
		case 0x5: /* SL0I */
		{
			strncpy(Name, "SL0I", 19);
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, true, true);
			break;
		}
		case 0x6: /* SR0I */
		{
			strncpy(Name, "SR0I", 19);
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, false, true);
			break;
		}
		case 0x7: /* SL1I */
		{
			strncpy(Name, "SL1I", 19);
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, true, false);
			break;
		}
		case 0x8: /* SR1I */
		{
			strncpy(Name, "SR1I", 19);
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, false, false);
			break;
		}
		default: return true;
	}
	if(DEBUG) {fprintf(stdout, "# %s reg%u %d\n", Name, c->reg0, c->raw_Immediate);}
	return false;
}

/* Process 0OPI Integer instructions */
bool eval_Integer_0OPI(struct lilith* vm, struct Instruction* c)
{
	char Name[20] = "ILLEGAL_0OPI";
	switch(c->raw_XOP)
	{
		case 0x00: /* JUMP */
		{
			strncpy(Name, "JUMP", 19);
			vm->ip = vm->ip + c->raw_Immediate - 4;
			break;
		}
		default: return true;
	}
	if(DEBUG) {fprintf(stdout, "# %s %d\n", Name, c->raw_Immediate);}
	return false;
}

/* Use Opcode to decide what to do and then have it done */
void eval_instruction(struct lilith* vm, struct Instruction* current)
{
	bool invalid = false;
	fprintf(stdout, "Executing: %s\n", current->operation);
	//usleep(1000);
	performance_counter = performance_counter + 1;

	if(1000000 == performance_counter)
	{
		current->raw0 = 0xFF;
	}

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
		case 0x2C:
		{
			decode_1OPI(current);
			invalid = eval_Integer_1OPI(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x2D:
		{
			decode_1OPI(current);
			invalid = eval_branch_1OPI(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x3C: /* JUMP */
		{
			decode_0OPI(current);
			invalid = eval_Integer_0OPI(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x42: /* HALCODE */
		{
			decode_HALCODE(current);
			invalid = eval_HALCODE(vm, current);
			if ( invalid )
			{
				vm->halted = true;
				fprintf(stderr, "Invalid HALCODE\nComputer Program has Halted\n");
			}
			break;
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
	performance_counter = 0;
	execute_vm(vm);
	destroy_vm(vm);

	return EXIT_SUCCESS;
}
