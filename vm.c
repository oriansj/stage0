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
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_HALCODE";
	#endif

	switch(c->HAL_CODE)
	{
		case 0x100000: /* fopen */
		{
			#ifdef DEBUG
			strncpy(Name, "FOPEN", 19);
			#endif

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
			#ifdef DEBUG
			strncpy(Name, "FCLOSE", 19);
			#endif

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
			#ifdef DEBUG
			strncpy(Name, "FSEEK", 19);
			#endif

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
			#ifdef DEBUG
			strncpy(Name, "REWIND", 19);
			#endif

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
			#ifdef DEBUG
			strncpy(Name, "FGETC", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "FPUTC", 19);
			#endif
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

	#ifdef DEBUG
	fprintf(stdout, "# %s\n", Name);
	#endif
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
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_4OP";
	#endif

	utmp1 = vm->reg[c->reg3];

	C = utmp1 & Carry;
	B = utmp1 & Borrow;

	switch(c->raw_XOP)
	{
		case 0x00: /* ADD.CI */
		{
			#ifdef DEBUG
			strncpy(Name, "ADD.CI", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "ADD.CO", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "ADD.CIO", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "ADDU.CI", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "ADDU.CO", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "ADDU.CIO", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "SUB.BI", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "SUB.BO", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "SUB.BIO", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "SUBU.BI", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "SUBU.BO", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "SUBU.BIO", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "MULTIPLY", 19);
			#endif
			tmp1 = (int32_t)(vm->reg[c->reg2]);
			tmp2 = (int32_t)( vm->reg[c->reg3]);
			btmp1 = ((int64_t)tmp1) * ((int64_t)tmp2);
			vm->reg[c->reg0] = (int32_t)(btmp1 % 0x100000000);
			vm->reg[c->reg1] = (int32_t)(btmp1 / 0x100000000);
			break;
		}
		case 0x0D: /* MULTIPLYU */
		{
			#ifdef DEBUG
			strncpy(Name, "MULTIPLYU", 19);
			#endif
			ubtmp1 = (uint64_t)(vm->reg[c->reg2]) * (uint64_t)(vm->reg[c->reg3]);
			vm->reg[c->reg0] = ubtmp1 % 0x100000000;
			vm->reg[c->reg1] = ubtmp1 / 0x100000000;
			break;
		}
		case 0x0E: /* DIVIDE */
		{
			#ifdef DEBUG
			strncpy(Name, "DIVIDE", 19);
			#endif
			tmp1 = (int32_t)(vm->reg[c->reg2]);
			tmp2 = (int32_t)(vm->reg[c->reg3]);
			vm->reg[c->reg0] = tmp1 / tmp2;
			vm->reg[c->reg1] = tmp1 % tmp2;
			break;
		}
		case 0x0F: /* DIVIDEU */
		{
			#ifdef DEBUG
			strncpy(Name, "DIVIDEU", 19);
			#endif
			utmp1 = vm->reg[c->reg2];
			utmp2 = vm->reg[c->reg3];
			vm->reg[c->reg0] = utmp1 / utmp2;
			vm->reg[c->reg1] = utmp1 % utmp2;
			break;
		}
		case 0x10: /* MUX */
		{
			#ifdef DEBUG
			strncpy(Name, "MUX", 19);
			#endif
			vm->reg[c->reg0] = ((vm->reg[c->reg2] & ~(vm->reg[c->reg1])) |
								(vm->reg[c->reg3] & vm->reg[c->reg1]));
			break;
		}
		case 0x11: /* NMUX */
		{
			#ifdef DEBUG
			strncpy(Name, "NMUX", 19);
			#endif
			vm->reg[c->reg0] = ((vm->reg[c->reg2] & vm->reg[c->reg1]) |
								(vm->reg[c->reg3] & ~(vm->reg[c->reg1])));
			break;
		}
		case 0x12: /* SORT */
		{
			#ifdef DEBUG
			strncpy(Name, "SORT", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "SORTU", 19);
			#endif
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
	#ifdef DEBUG
	fprintf(stdout, "# %s reg%u reg%u reg%u reg%u\n", Name, c->reg0, c->reg1, c->reg2, c->reg3);
	#endif
	return false;
}

/* Process 3OP Integer instructions */
bool eval_3OP_Int(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;
	uint32_t utmp1, utmp2;
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_3OP";
	#endif

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);
	utmp1 = vm->reg[c->reg1];
	utmp2 = vm->reg[c->reg2];

	switch(c->raw_XOP)
	{
		case 0x000: /* ADD */
		{
			#ifdef DEBUG
			strncpy(Name, "ADD", 19);
			#endif
			vm->reg[c->reg0] = (int32_t)(tmp1 + tmp2);
			break;
		}
		case 0x001: /* ADDU */
		{
			#ifdef DEBUG
			strncpy(Name, "ADDU", 19);
			#endif
			vm->reg[c->reg0] = utmp1 + utmp2;
			break;
		}
		case 0x002: /* SUB */
		{
			#ifdef DEBUG
			strncpy(Name, "SUB", 19);
			#endif
			vm->reg[c->reg0] = (int32_t)(tmp1 - tmp2);
			break;
		}
		case 0x003: /* SUBU */
		{
			#ifdef DEBUG
			strncpy(Name, "SUBU", 19);
			#endif
			vm->reg[c->reg0] = utmp1 - utmp2;
			break;
		}
		case 0x004: /* CMP */
		{
			#ifdef DEBUG
			strncpy(Name, "CMP", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "CMPU", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "MUL", 19);
			#endif
			int64_t sum = tmp1 * tmp2;
			/* We only want the bottom 32bits */
			vm->reg[c->reg0] = sum % 0x100000000;
			break;
		}
		case 0x007: /* MULH */
		{
			#ifdef DEBUG
			strncpy(Name, "MULH", 19);
			#endif
			int64_t sum = tmp1 * tmp2;
			/* We only want the top 32bits */
			vm->reg[c->reg0] = sum / 0x100000000;
			break;
		}
		case 0x008: /* MULU */
		{
			#ifdef DEBUG
			strncpy(Name, "MULU", 19);
			#endif
			uint64_t sum = tmp1 * tmp2;
			/* We only want the bottom 32bits */
			vm->reg[c->reg0] = sum % 0x100000000;
			break;
		}
		case 0x009: /* MULUH */
		{
			#ifdef DEBUG
			strncpy(Name, "MULUH", 19);
			#endif
			uint64_t sum = tmp1 * tmp2;
			/* We only want the top 32bits */
			vm->reg[c->reg0] = sum / 0x100000000;
			break;
		}
		case 0x00A: /* DIV */
		{
			#ifdef DEBUG
			strncpy(Name, "DIV", 19);
			#endif
			vm->reg[c->reg0] = tmp1 / tmp2;
			break;
		}
		case 0x00B: /* MOD */
		{
			#ifdef DEBUG
			strncpy(Name, "MOD", 19);
			#endif
			vm->reg[c->reg0] = tmp1 % tmp2;
			break;
		}
		case 0x00C: /* DIVU */
		{
			#ifdef DEBUG
			strncpy(Name, "DIVU", 19);
			#endif
			vm->reg[c->reg0] = utmp1 / utmp2;
			break;
		}
		case 0x00D: /* MODU */
		{
			#ifdef DEBUG
			strncpy(Name, "MODU", 19);
			#endif
			vm->reg[c->reg0] = utmp1 % utmp2;
			break;
		}
		case 0x010: /* MAX */
		{
			#ifdef DEBUG
			strncpy(Name, "MAX", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "MAXU", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "MIN", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "MINU", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "PACK", 19);
			#endif
			break;
		}
		case 0x015: /* UNPACK */
		{
			#ifdef DEBUG
			strncpy(Name, "UNPACK", 19);
			#endif
			break;
		}
		case 0x016: /* PACK8.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK8.CO", 19);
			#endif
			break;
		}
		case 0x017: /* PACK8U.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK8U.CO", 19);
			#endif
			break;
		}
		case 0x018: /* PACK16.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK16.CO", 19);
			#endif
			break;
		}
		case 0x019: /* PACK16U.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK16U.CO", 19);
			#endif
			break;
		}
		case 0x01A: /* PACK32.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK32.CO", 19);
			#endif
			break;
		}
		case 0x01B: /* PACK32U.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK32U.CO", 19);
			#endif
			break;
		}
		case 0x020: /* AND */
		{
			#ifdef DEBUG
			strncpy(Name, "AND", 19);
			#endif
			vm->reg[c->reg0] = utmp1 & utmp2;
			break;
		}
		case 0x021: /* OR */
		{
			#ifdef DEBUG
			strncpy(Name, "OR", 19);
			#endif
			vm->reg[c->reg0] = utmp1 | utmp2;
			break;
		}
		case 0x022: /* XOR */
		{
			#ifdef DEBUG
			strncpy(Name, "XOR", 19);
			#endif
			vm->reg[c->reg0] = utmp1 ^ utmp2;
			break;
		}
		case 0x023: /* NAND */
		{
			#ifdef DEBUG
			strncpy(Name, "NAND", 19);
			#endif
			vm->reg[c->reg0] = ~(utmp1 & utmp2);
			break;
		}
		case 0x024: /* NOR */
		{
			#ifdef DEBUG
			strncpy(Name, "NOR", 19);
			#endif
			vm->reg[c->reg0] = ~(utmp1 | utmp2);
			break;
		}
		case 0x025: /* XNOR */
		{
			#ifdef DEBUG
			strncpy(Name, "XNOR", 19);
			#endif
			vm->reg[c->reg0] = ~(utmp1 ^ utmp2);
			break;
		}
		case 0x026: /* MPQ */
		{
			#ifdef DEBUG
			strncpy(Name, "MPQ", 19);
			#endif
			vm->reg[c->reg0] = (~utmp1) & utmp2;
			break;
		}
		case 0x027: /* LPQ */
		{
			#ifdef DEBUG
			strncpy(Name, "LPQ", 19);
			#endif
			vm->reg[c->reg0] = utmp1 & (~utmp2);
			break;
		}
		case 0x028: /* CPQ */
		{
			#ifdef DEBUG
			strncpy(Name, "CPQ", 19);
			#endif
			vm->reg[c->reg0] = (~utmp1) | utmp2;
			break;
		}
		case 0x029: /* BPQ */
		{
			#ifdef DEBUG
			strncpy(Name, "BPQ", 19);
			#endif
			vm->reg[c->reg0] = utmp1 | (~utmp2);
			break;
		}
		case 0x030: /* SAL */
		{
			#ifdef DEBUG
			strncpy(Name, "SAL", 19);
			#endif
			vm->reg[c->reg0] = vm->reg[c->reg1] << vm->reg[c->reg2];
			break;
		}
		case 0x031: /* SAR */
		{
			#ifdef DEBUG
			strncpy(Name, "SAR", 19);
			#endif
			vm->reg[c->reg0] = vm->reg[c->reg1] >> vm->reg[c->reg2];
			break;
		}
		case 0x032: /* SL0 */
		{
			#ifdef DEBUG
			strncpy(Name, "SL0", 19);
			#endif
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], true, true);
			break;
		}
		case 0x033: /* SR0 */
		{
			#ifdef DEBUG
			strncpy(Name, "SR0", 19);
			#endif
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], false, true);
			break;
		}
		case 0x034: /* SL1 */
		{
			#ifdef DEBUG
			strncpy(Name, "SL1", 19);
			#endif
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], true, false);
			break;
		}
		case 0x035: /* SR1 */
		{
			#ifdef DEBUG
			strncpy(Name, "SR1", 19);
			#endif
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], false, false);
			break;
		}
		case 0x036: /* ROL */
		{
			#ifdef DEBUG
			strncpy(Name, "ROL", 19);
			#endif
			break;
		}
		case 0x037: /* ROR */
		{
			#ifdef DEBUG
			strncpy(Name, "ROR", 19);
			#endif
			break;
		}
		case 0x038: /* LOADX */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADX", 19);
			#endif
			vm->reg[c->reg0] = readin_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2]);
			break;
		}
		case 0x039: /* LOADX8 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADX8", 19);
			#endif
			vm->reg[c->reg0] = readin_byte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], true);
			break;
		}
		case 0x03A: /* LOADXU8 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADXU8", 19);
			#endif
			vm->reg[c->reg0] = readin_byte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], false);
			break;
		}
		case 0x03B: /* LOADX16 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADX16", 19);
			#endif
			vm->reg[c->reg0] = readin_doublebyte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], true);
			break;
		}
		case 0x03C: /* LOADXU16 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADXU16", 19);
			#endif
			vm->reg[c->reg0] = readin_doublebyte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], false);
			break;
		}
		case 0x03D: /* LOADX32 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADX32", 19);
			#endif
			vm->reg[c->reg0] = readin_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2]);
			break;
		}
		case 0x03E: /* LOADXU32 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADXU32", 19);
			#endif
			vm->reg[c->reg0] = readin_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2]);
			break;
		}
		case 0x048: /* STOREX */
		{
			#ifdef DEBUG
			strncpy(Name, "STOREX", 19);
			#endif
			writeout_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
			break;
		}
		case 0x049: /* STOREX8 */
		{
			#ifdef DEBUG
			strncpy(Name, "STOREX8", 19);
			#endif
			writeout_byte(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
			break;
		}
		case 0x04A: /* STOREX16 */
		{
			#ifdef DEBUG
			strncpy(Name, "STOREX16", 19);
			#endif
			writeout_doublebyte(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
			break;
		}
		case 0x04B: /* STOREX32 */
		{
			#ifdef DEBUG
			strncpy(Name, "STOREX32", 19);
			#endif
			writeout_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
			break;
		}
		default: return true;
	}
	#ifdef DEBUG
	fprintf(stdout, "# %s reg%u reg%u reg%u\n", Name, c->reg0, c->reg1, c->reg2);
	#endif
	return false;
}

/* Process 2OP Integer instructions */
bool eval_2OP_Int(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1 = (int32_t)(vm->reg[c->reg1]);
	uint32_t utmp1 = vm->reg[c->reg1];
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_2OP";
	#endif

	switch(c->raw_XOP)
	{
		case 0x0000: /* NEG */
		{
			#ifdef DEBUG
			strncpy(Name, "NEG", 19);
			#endif
			vm->reg[c->reg0] = tmp1*-1;
			break;
		}
		case 0x0001: /* ABS */
		{
			#ifdef DEBUG
			strncpy(Name, "ABS", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "NABS", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "SWAP", 19);
			#endif
			vm->reg[c->reg1] = vm->reg[c->reg0];
			vm->reg[c->reg0] = utmp1;
			break;
		}
		case 0x0004: /* COPY */
		{
			#ifdef DEBUG
			strncpy(Name, "COPY", 19);
			#endif
			vm->reg[c->reg0] = utmp1;
			break;
		}
		case 0x0005: /* MOVE */
		{
			#ifdef DEBUG
			strncpy(Name, "MOVE", 19);
			#endif
			vm->reg[c->reg0] = utmp1;
			vm->reg[c->reg1] = 0;
			break;
		}
		case 0x0100: /* BRANCH */
		{
			#ifdef DEBUG
			strncpy(Name, "BRANCH", 19);
			#endif
			/* Write out the PC */
			writeout_Reg(vm, vm->reg[c->reg1], vm->ip);

			/* Update PC */
			vm->ip = vm->reg[c->reg0];
			break;
		}
		case 0x0101: /* CALL */
		{
			#ifdef DEBUG
			strncpy(Name, "CALL", 19);
			#endif
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
	#ifdef DEBUG
	fprintf(stdout, "# %s reg%u reg%u\n", Name, c->reg0, c->reg1);
	#endif
	return false;
}

/* Process 1OP Integer instructions */
bool eval_1OP_Int(struct lilith* vm, struct Instruction* c)
{
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_1OP";
	#endif
	switch(c->raw_XOP)
	{
		case 0x00000: /* READPC */
		{
			#ifdef DEBUG
			strncpy(Name, "READPC", 19);
			#endif
			vm->reg[c->reg0] = vm->ip;
			break;
		}
		case 0x00001: /* READSCID */
		{
			#ifdef DEBUG
			strncpy(Name, "READSCID", 19);
			#endif
			/* We only support Base 8,16 and 32*/
			vm->reg[c->reg0] = 0x00000007;
			break;
		}
		case 0x00002: /* FALSE */
		{
			#ifdef DEBUG
			strncpy(Name, "FALSE", 19);
			#endif
			vm->reg[c->reg0] = 0;
			break;
		}
		case 0x00003: /* TRUE */
		{
			#ifdef DEBUG
			strncpy(Name, "TRUE", 19);
			#endif
			vm->reg[c->reg0] = 0xFFFFFFFF;
			break;
		}
		case 0x01000: /* JSR_COROUTINE */
		{
			#ifdef DEBUG
			strncpy(Name, "JSR_COROUTINE", 19);
			#endif
			vm->ip = vm->reg[c->reg0];
			break;
		}
		case 0x01001: /* RET */
		{
			#ifdef DEBUG
			strncpy(Name, "RET", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "PUSHPC", 19);
			#endif
			/* Write out the PC */
			writeout_Reg(vm, vm->reg[c->reg0], vm->ip);

			/* Update our index */
			vm->reg[c->reg0] = vm->reg[c->reg0] + 4;
			break;
		}
		case 0x02001: /* POPPC */
		{
			#ifdef DEBUG
			strncpy(Name, "POPPC", 19);
			#endif
			/* Read in the new PC */
			vm->ip = readin_Reg(vm, vm->reg[c->reg0]);

			/* Update our index */
			vm->reg[c->reg0] = vm->reg[c->reg0] - 4;
			break;
		}
		default: return true;
	}
	#ifdef DEBUG
	fprintf(stdout, "# %s reg%u\n", Name, c->reg0);
	#endif
	return false;
}

/* Process 2OPI Integer instructions */
bool eval_2OPI_Int(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1;
	uint32_t utmp1;
	uint8_t raw0, raw1;
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_2OPI";
	#endif

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	utmp1 = vm->reg[c->reg1];

	/* 0x0E ... 0x2B */
	switch(c->raw0)
	{
		case 0x0E: /* ADDI */
		{
			#ifdef DEBUG
			strncpy(Name, "ADDI", 19);
			#endif
			vm->reg[c->reg0] = (int32_t)(tmp1 + c->raw_Immediate);
			break;
		}
		case 0x0F: /* ADDUI */
		{
			#ifdef DEBUG
			strncpy(Name, "ADDUI", 19);
			#endif
			vm->reg[c->reg0] = utmp1 + c->raw_Immediate;
			break;
		}
		case 0x10: /* SUBI */
		{
			#ifdef DEBUG
			strncpy(Name, "SUBI", 19);
			#endif
			vm->reg[c->reg0] = (int32_t)(tmp1 - c->raw_Immediate);
			break;
		}
		case 0x11: /* SUBUI */
		{
			#ifdef DEBUG
			strncpy(Name, "SUBUI", 19);
			#endif
			vm->reg[c->reg0] = utmp1 + c->raw_Immediate;
			break;
		}
		case 0x12: /* CMPI */
		{
			#ifdef DEBUG
			strncpy(Name, "CMPI", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "LOAD", 19);
			#endif
			vm->reg[c->reg0] = readin_Reg(vm, (utmp1 + c->raw_Immediate));
			break;
		}
		case 0x14: /* LOAD8 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOAD8", 19);
			#endif
			vm->reg[c->reg0] = readin_byte(vm, utmp1 + c->raw_Immediate, true);
			break;
		}
		case 0x15: /* LOADU8 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADU8", 19);
			#endif
			vm->reg[c->reg0] = readin_byte(vm, utmp1 + c->raw_Immediate, false);
			break;
		}
		case 0x16: /* LOAD16 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOAD16", 19);
			#endif
			vm->reg[c->reg0] = readin_doublebyte(vm, utmp1 + c->raw_Immediate, true);
			break;
		}
		case 0x17: /* LOADU16 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADU16", 19);
			#endif
			vm->reg[c->reg0] = readin_doublebyte(vm, utmp1 + c->raw_Immediate, false);
			break;
		}
		case 0x18: /* LOAD32 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOAD32", 19);
			#endif
			vm->reg[c->reg0] = readin_Reg(vm, (utmp1 + c->raw_Immediate));
			break;
		}
		case 0x19: /* LOADU32 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADU32", 19);
			#endif
			vm->reg[c->reg0] = readin_Reg(vm, (utmp1 + c->raw_Immediate));
			break;
		}
		case 0x1F: /* CMPUI */
		{
			#ifdef DEBUG
			strncpy(Name, "CMPUI", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "STORE", 19);
			#endif
			writeout_Reg(vm, (utmp1 + c->raw_Immediate), vm->reg[c->reg0]);
			break;
		}
		case 0x21: /* STORE8 */
		{
			#ifdef DEBUG
			strncpy(Name, "STORE8", 19);
			#endif
			writeout_byte(vm, utmp1 + c->raw_Immediate, vm->reg[c->reg0]);
			break;
		}
		case 0x22: /* STORE16 */
		{
			#ifdef DEBUG
			strncpy(Name, "STORE16", 19);
			#endif
			writeout_doublebyte(vm, utmp1 + c->raw_Immediate, vm->reg[c->reg0]);
			break;
		}
		case 0x23: /* STORE32 */
		{
			#ifdef DEBUG
			strncpy(Name, "STORE32", 19);
			#endif
			writeout_Reg(vm, (utmp1 + c->raw_Immediate), vm->reg[c->reg0]);
			break;
		}
		default: return true;
	}
	#ifdef DEBUG
	fprintf(stdout, "# %s reg%u reg%u %i\n", Name, c->reg0, c->reg1, c->raw_Immediate);
	#endif
	return false;
}

/* Process 1OPI Integer instructions */
bool eval_Integer_1OPI(struct lilith* vm, struct Instruction* c)
{
	bool C, B, O, GT, EQ, LT;
	uint32_t tmp;
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_1OPI";
	#endif

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
			#ifdef DEBUG
			strncpy(Name, "JUMP.C", 19);
			#endif
			if(1 == C)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x1: /* JUMP.B */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.B", 19);
			#endif
			if(1 == B)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x2: /* JUMP.O */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.O", 19);
			#endif
			if(1 == O)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x3: /* JUMP.G */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.G", 19);
			#endif
			if(1 == GT)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x4: /* JUMP.GE */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.GE", 19);
			#endif
			if((1 == GT) || (1 == EQ))
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x5: /* JUMP.E */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.E", 19);
			#endif
			if(1 == EQ)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x6: /* JUMP.NE */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.NE", 19);
			#endif
			if(1 != EQ)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x7: /* JUMP.LE */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.LE", 19);
			#endif
			if((1 == EQ) || (1 == LT))
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x8: /* JUMP.L */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.L", 19);
			#endif
			if(1 == LT)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x9: /* JUMP.Z */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.Z", 19);
			#endif
			if(0 == tmp)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0xA: /* JUMP.NZ */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.NZ", 19);
			#endif
			if(0 != tmp)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		default: return true;
	}
	#ifdef DEBUG
	fprintf(stdout, "# %s reg%u %d\n", Name, c->reg0, c->raw_Immediate);
	#endif
	return false;
}

bool eval_branch_1OPI(struct lilith* vm, struct Instruction* c)
{
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_1OPI";
	#endif
	switch(c->raw_XOP)
	{
		case 0x0: /* CALLI */
		{
			#ifdef DEBUG
			strncpy(Name, "CALLI", 19);
			#endif
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
			#ifdef DEBUG
			strncpy(Name, "LOADI", 19);
			#endif
			vm->reg[c->reg0] = (int16_t)c->raw_Immediate;
			break;
		}
		case 0x2: /* LOADUI*/
		{
			#ifdef DEBUG
			strncpy(Name, "LOADU", 19);
			#endif
			vm->reg[c->reg0] = c->raw_Immediate;
			break;
		}
		case 0x3: /* SALI */
		{
			#ifdef DEBUG
			strncpy(Name, "SALI", 19);
			#endif
			vm->reg[c->reg0] = vm->reg[c->reg0] << c->raw_Immediate;
			break;
		}
		case 0x4: /* SARI */
		{
			#ifdef DEBUG
			strncpy(Name, "SARI", 19);
			#endif
			vm->reg[c->reg0] = vm->reg[c->reg0] >> c->raw_Immediate;
			break;
		}
		case 0x5: /* SL0I */
		{
			#ifdef DEBUG
			strncpy(Name, "SL0I", 19);
			#endif
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, true, true);
			break;
		}
		case 0x6: /* SR0I */
		{
			#ifdef DEBUG
			strncpy(Name, "SR0I", 19);
			#endif
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, false, true);
			break;
		}
		case 0x7: /* SL1I */
		{
			#ifdef DEBUG
			strncpy(Name, "SL1I", 19);
			#endif
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, true, false);
			break;
		}
		case 0x8: /* SR1I */
		{
			#ifdef DEBUG
			strncpy(Name, "SR1I", 19);
			#endif
			vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, false, false);
			break;
		}
		default: return true;
	}
	#ifdef DEBUG
	fprintf(stdout, "# %s reg%u %d\n", Name, c->reg0, c->raw_Immediate);
	#endif
	return false;
}

/* Process 0OPI Integer instructions */
bool eval_Integer_0OPI(struct lilith* vm, struct Instruction* c)
{
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_0OPI";
	#endif
	switch(c->raw_XOP)
	{
		case 0x00: /* JUMP */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP", 19);
			#endif
			vm->ip = vm->ip + c->raw_Immediate - 4;
			break;
		}
		default: return true;
	}
	#ifdef DEBUG
	fprintf(stdout, "# %s %d\n", Name, c->raw_Immediate);
	#endif
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
