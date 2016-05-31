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
	int32_t tmp1, tmp2;
	uint32_t utmp1, utmp2;
	int64_t btmp1;
	uint64_t ubtmp1;

	bool C, B;

	utmp1 = vm->reg[c->reg3];

	C = utmp1 & Carry;
	B = utmp1 & Borrow;

	switch(c->raw_XOP)
	{
		case 0x00: /* ADD.CI */
		{
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
			tmp1 = (int32_t)(vm->reg[c->reg2]);
			tmp2 = (int32_t)( vm->reg[c->reg3]);
			btmp1 = ((int64_t)tmp1) * ((int64_t)tmp2);
			vm->reg[c->reg0] = (int32_t)(btmp1 % 0x100000000);
			vm->reg[c->reg1] = (int32_t)(btmp1 / 0x100000000);
			break;
		}
		case 0x0D: /* MULTIPLYU */
		{
			ubtmp1 = (uint64_t)(vm->reg[c->reg2]) * (uint64_t)(vm->reg[c->reg3]);
			vm->reg[c->reg0] = ubtmp1 % 0x100000000;
			vm->reg[c->reg1] = ubtmp1 / 0x100000000;
			break;
		}
		case 0x0E: /* DIVIDE */
		{
			tmp1 = (int32_t)(vm->reg[c->reg2]);
			tmp2 = (int32_t)(vm->reg[c->reg3]);
			vm->reg[c->reg0] = tmp1 / tmp2;
			vm->reg[c->reg1] = tmp1 % tmp2;
			break;
		}
		case 0x0F: /* DIVIDEU */
		{
			utmp1 = vm->reg[c->reg2];
			utmp2 = vm->reg[c->reg3];
			vm->reg[c->reg0] = utmp1 / utmp2;
			vm->reg[c->reg1] = utmp1 % utmp2;
			break;
		}
		case 0x10: /* MUX */
		{
			vm->reg[c->reg0] = ((vm->reg[c->reg2] & ~(vm->reg[c->reg1])) |
								(vm->reg[c->reg3] & vm->reg[c->reg1]));
			break;
		}
		case 0x11: /* NMUX */
		{
			vm->reg[c->reg0] = ((vm->reg[c->reg2] & vm->reg[c->reg1]) |
								(vm->reg[c->reg3] & ~(vm->reg[c->reg1])));
			break;
		}
		case 0x12: /* SORT */
		{
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
	return false;
}

/* Process 3OP Integer instructions */
bool eval_3OP_Int(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;
	uint32_t utmp1, utmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);
	utmp1 = vm->reg[c->reg1];
	utmp2 = vm->reg[c->reg2];

	switch(c->raw_XOP)
	{
		case 0x000: /* ADD */
		{
			vm->reg[c->reg0] = (int32_t)(tmp1 + tmp2);
			break;
		}
		case 0x001: /* ADDU */
		{
			vm->reg[c->reg0] = utmp1 + utmp2;
			break;
		}
		case 0x002: /* SUB */
		{
			vm->reg[c->reg0] = (int32_t)(tmp1 - tmp2);
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
			int64_t sum = tmp1 * tmp2;
			/* We only want the bottom 32bits */
			vm->reg[c->reg0] = sum % 0x100000000;
			break;
		}
		case 0x007: /* MULH */
		{
			int64_t sum = tmp1 * tmp2;
			/* We only want the top 32bits */
			vm->reg[c->reg0] = sum / 0x100000000;
			break;
		}
		case 0x008: /* MULU */
		{
			uint64_t sum = tmp1 * tmp2;
			/* We only want the bottom 32bits */
			vm->reg[c->reg0] = sum % 0x100000000;
			break;
		}
		case 0x009: /* MULUH */
		{
			uint64_t sum = tmp1 * tmp2;
			/* We only want the top 32bits */
			vm->reg[c->reg0] = sum / 0x100000000;
			break;
		}
		case 0x00A: /* DIV */
		{
			vm->reg[c->reg0] = tmp1 / tmp2;
			break;
		}
		case 0x00B: /* MOD */
		{
			vm->reg[c->reg0] = tmp1 % tmp2;
			break;
		}
		case 0x00C: /* DIVU */
		{
			vm->reg[c->reg0] = utmp1 / utmp2;
			break;
		}
		case 0x00D: /* MODU */
		{
			vm->reg[c->reg0] = utmp1 % utmp2;
			break;
		}
		case 0x010: /* MAX */
		{
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
		case 0x020: /* AND */
		{
			vm->reg[c->reg0] = utmp1 & utmp2;
			break;
		}
		case 0x021: /* OR */
		{
			vm->reg[c->reg0] = utmp1 | utmp2;
			break;
		}
		case 0x022: /* XOR */
		{
			vm->reg[c->reg0] = utmp1 ^ utmp2;
			break;
		}
		case 0x023: /* NAND */
		{
			vm->reg[c->reg0] = ~(utmp1 & utmp2);
			break;
		}
		case 0x024: /* NOR */
		{
			vm->reg[c->reg0] = ~(utmp1 | utmp2);
			break;
		}
		case 0x025: /* XNOR */
		{
			vm->reg[c->reg0] = ~(utmp1 ^ utmp2);
			break;
		}
		case 0x026: /* MPQ */
		{
			vm->reg[c->reg0] = (~utmp1) & utmp2;
			break;
		}
		case 0x027: /* LPQ */
		{
			vm->reg[c->reg0] = utmp1 & (~utmp2);
			break;
		}
		case 0x028: /* CPQ */
		{
			vm->reg[c->reg0] = (~utmp1) | utmp2;
			break;
		}
		case 0x029: /* BPQ */
		{
			vm->reg[c->reg0] = utmp1 | (~utmp2);
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
	int32_t tmp1 = (int32_t)(vm->reg[c->reg1]);
	uint32_t utmp1 = vm->reg[c->reg1];

	switch(c->raw_XOP)
	{
		case 0x0000: /* NEG */
		{
			vm->reg[c->reg0] = tmp1*-1;
			break;
		}
		case 0x0001: /* ABS */
		{
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
			vm->reg[c->reg1] = vm->reg[c->reg0];
			vm->reg[c->reg0] = utmp1;
			break;
		}
		case 0x0004: /* COPY */
		{
			vm->reg[c->reg0] = utmp1;
			break;
		}
		case 0x0005: /* MOVE */
		{
			vm->reg[c->reg0] = utmp1;
			vm->reg[c->reg1] = 0;
			break;
		}
		case 0x0100: /* BRANCH */
		{
			/* Preserve index */
			uint32_t utmp1 = vm->reg[c->reg1];

			/* Use the index register to store the PC for upload to MEM */
			vm->reg[c->reg1] = vm->ip;

			/* Write out the PC */
			writeout_Reg(vm, utmp1, c->reg1);

			/* Restore our index */
			vm->reg[c->reg1] = utmp1;

			/* Update PC */
			vm->ip = vm->reg[c->reg0];
			break;
		}
		case 0x0101: /* CALL */
		{
		/* Preserve index */
			uint32_t utmp1 = vm->reg[c->reg1];

			/* Use the index register to store the PC for upload to MEM */
			vm->reg[c->reg1] = vm->ip;

			/* Write out the PC */
			writeout_Reg(vm, utmp1, c->reg1);

			/* Update our index */
			vm->reg[c->reg1] = utmp1 + 4;

			/* Update PC */
			vm->ip = vm->reg[c->reg0];
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
			vm->reg[c->reg0] = vm->ip;
			break;
		}
		case 0x00001: /* READSCID */
		{
			/* We only support Base 8,16 and 32*/
			vm->reg[c->reg0] = 0x00000007;
			break;
		}
		case 0x00002: /* FALSE */
		{
			vm->reg[c->reg0] = 0;
			break;
		}
		case 0x00003: /* TRUE */
		{
			vm->reg[c->reg0] = 0xFFFFFFFF;
			break;
		}
		case 0x01000: /* JSR_COROUTINE */
		{
			vm->ip = vm->reg[c->reg0];
			break;
		}
		case 0x01001: /* RET */
		{
			/* Preserve index */
			uint32_t utmp1 = vm->reg[c->reg0];

			/* Read in the new PC */
			readin_Reg(vm, utmp1, c->reg0);
			vm->ip = vm->reg[c->reg0];

			/* Update our index */
			vm->reg[c->reg0] = utmp1 - 4;
			break;
		}
		case 0x02000: /* PUSHPC */
		{
			/* Preserve index */
			uint32_t utmp1 = vm->reg[c->reg0];

			/* Use the index register to store the PC for upload to MEM */
			vm->reg[c->reg0] = vm->ip;

			/* Write out the PC */
			writeout_Reg(vm, utmp1, c->reg0);

			/* Update our index */
			vm->reg[c->reg0] = utmp1 + 4;
			break;
		}
		case 0x02001: /* POPPC */
		{
			/* Preserve index */
			uint32_t utmp1 = vm->reg[c->reg0];

			/* Read in the new PC */
			readin_Reg(vm, utmp1, c->reg0);
			vm->ip = vm->reg[c->reg0];

			/* Update our index */
			vm->reg[c->reg0] = utmp1 - 4;
			break;
		}
		default: return true;
	}
	return false;
}

/* Process 2OPI Integer instructions */
bool eval_2OPI_Int(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1;
	uint32_t utmp1;
	uint8_t raw0, raw1;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	utmp1 = vm->reg[c->reg1];

	/* 0x0E ... 0x2B */
	switch(c->raw0)
	{
		case 0x0E: /* ADDI */
		{
			vm->reg[c->reg0] = (int32_t)(tmp1 + c->raw_Immediate);
			break;
		}
		case 0x0F: /* ADDUI */
		{
			vm->reg[c->reg0] = utmp1 + c->raw_Immediate;
			break;
		}
		case 0x10: /* SUBI */
		{
			vm->reg[c->reg0] = (int32_t)(tmp1 - c->raw_Immediate);
			break;
		}
		case 0x11: /* SUBUI */
		{
			vm->reg[c->reg0] = utmp1 + c->raw_Immediate;
			break;
		}
		case 0x12: /* CMPI */
		{
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
			readin_Reg(vm, (utmp1 + c->raw_Immediate) , c->reg0);
			break;
		}
		case 0x14: /* LOAD8 */
		{
			raw0 = vm->memory[utmp1 + c->raw_Immediate];
			int32_t tmp = raw0;

			/* Sign extend Register */
			tmp = tmp << 24;
			tmp = tmp >> 24;

			vm->reg[c->reg0] = tmp;
			break;
		}
		case 0x15: /* LOADU8 */
		{
			vm->reg[c->reg0] = (uint8_t)(vm->memory[utmp1 + c->raw_Immediate]);
			break;
		}
		case 0x16: /* LOAD16 */
		{
			raw0 = vm->memory[utmp1 + c->raw_Immediate];
			raw1 = vm->memory[utmp1 + c->raw_Immediate + 1];

			int32_t tmp = raw0*0x100 + raw1;

			/* Sign extend Register */
			tmp = tmp << 16;
			tmp = tmp >> 16;
			vm->reg[c->reg0] = tmp;
			break;
		}
		case 0x17: /* LOADU16 */
		{
			raw0 = vm->memory[utmp1 + c->raw_Immediate];
			raw1 = vm->memory[utmp1 + c->raw_Immediate + 1];

			vm->reg[c->reg0] = raw0*0x1000000 + raw1;
			break;
		}
		case 0x18: /* LOAD32 */
		case 0x19: /* LOADU32 */
		{
			readin_Reg(vm, (utmp1 + c->raw_Immediate) , c->reg0);
			break;
		}
		case 0x1F: /* CMPUI */
		{
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
			writeout_Reg(vm, (utmp1 + c->raw_Immediate), c->reg0);
			break;
		}
		case 0x21: /* STORE8 */
		{
			int32_t tmp = (int8_t)(vm->reg[c->reg0]);
			raw0 = tmp%0x100;

			vm->memory[utmp1 + c->raw_Immediate] = raw0;
			break;
		}
		case 0x22: /* STOREU8 */
		{
			uint32_t tmp = vm->reg[c->reg0];
			raw0 = tmp%0x100;

			vm->memory[utmp1 + c->raw_Immediate] = raw0;
			break;
		}
		case 0x23: /* STORE16 */
		{
			int32_t tmp = (int16_t)(vm->reg[c->reg0]);
			raw1 = tmp%0x100;
			tmp = tmp/0x100;
			raw0 = tmp%0x100;

			vm->memory[utmp1 + c->raw_Immediate] = raw0;
			vm->memory[utmp1 + c->raw_Immediate + 1] = raw1;
			break;
		}
		case 0x24: /* STOREU16 */
		{
			uint32_t tmp = vm->reg[c->reg0];
			raw1 = tmp%0x100;
			tmp = tmp/0x100;
			raw0 = tmp%0x100;

			vm->memory[utmp1 + c->raw_Immediate] = raw0;
			vm->memory[utmp1 + c->raw_Immediate + 1] = raw1;
			break;
		}
		case 0x25: /* STORE32 */
		case 0x26: /* STOREU32 */
		{
			writeout_Reg(vm, (utmp1 + c->raw_Immediate), c->reg0);
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
	uint32_t tmp;

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
		case 0x2C: /* JUMP.C */
		{
			if(1 == C)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x2D: /* JUMP.B */
		{
			if(1 == B)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x2E: /* JUMP.O */
		{
			if(1 == O)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x2F: /* JUMP.G */
		{
			if(1 == GT)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x30: /* JUMP.GE */
		{
			if((1 == GT) || (1 == EQ))
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x31: /* JUMP.E */
		{
			if(1 == EQ)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x32: /* JUMP.NE */
		{
			if(1 != EQ)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x33: /* JUMP.LE */
		{
			if((1 == EQ) || (1 == LT))
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x34: /* JUMP.L */
		{
			if(1 == LT)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x35: /* JUMP.Z */
		{
			if(0 == tmp)
			{
				/* Adust the IP relative the the start of this instruction*/
				vm->ip = vm->ip + c->raw_Immediate - 4;
			}
			break;
		}
		case 0x36: /* JUMP.NZ */
		{
			if(0 != tmp)
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
		case 0x42: /* HALCODE */
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
