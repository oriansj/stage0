#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

FILE* binary_file;

/* Unpacked instruction */
struct Instruction
{
	uint32_t raw0, raw1, raw2, raw3;
	char opcode[3];
	uint32_t raw_XOP;
	char XOP[6];
	char operation[9];
	int16_t raw_Immediate;
	char Immediate[7];
	uint32_t HAL_CODE;
	uint8_t reg0;
	uint8_t reg1;
	uint8_t reg2;
	uint8_t reg3;
	bool invalid;
};

/* Useful unpacking functions */
void unpack_byte(uint8_t a, char* c)
{
	char table[16] = {0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46};
	c[0] = table[a / 16];
	c[1] = table[a % 16];
}

void unpack_instruction(struct Instruction* c)
{
	unpack_byte(c->raw0, &(c->operation[0]));
	unpack_byte(c->raw1, &(c->operation[2]));
	unpack_byte(c->raw2, &(c->operation[4]));
	unpack_byte(c->raw3, &(c->operation[6]));
	c->opcode[0] = c->operation[0];
	c->opcode[1] = c->operation[1];
}

/* Load instruction addressed at IP */
void read_instruction(struct Instruction *current)
{
	memset(current, 0, sizeof(struct Instruction));

	/* Read the actual bytes and increment the IP */

	current->raw0 = fgetc(binary_file);
	if(-1 == (int32_t)(current->raw0)) goto Broken;
	current->raw1 = fgetc(binary_file);
	if(-1 == (int32_t)(current->raw1)) goto Broken;
	current->raw2 = fgetc(binary_file);
	if(-1 == (int32_t)(current->raw2)) goto Broken;
	current->raw3 = fgetc(binary_file);
	if(-1 == (int32_t)(current->raw3)) goto Broken;
	unpack_instruction(current);

	return;

	/* This disassembler doesn't support non-instructions */
Broken:
	fclose(binary_file);
	exit(EXIT_FAILURE);
}

void decode_Integer_4OP(struct Instruction* c)
{
	/* Parse Raw Data */
	c->raw_XOP = c->raw1;
	c->XOP[0] = c->operation[2];
	c->XOP[1] = c->operation[3];
	c->raw_Immediate = 0;
	c->reg0 = c->raw2/16;
	c->reg1 = c->raw2%16;
	c->reg2 = c->raw3/16;
	c->reg3 = c->raw3%16;

	char Name[20] = "ILLEGAL_4OP";

	/* Convert to Human readable form */
	switch(c->raw_XOP)
	{
		case 0x00: /* ADD.CI */
		{
			strncpy(Name, "ADD.CI", 19);
			break;
		}
		case 0x01: /* ADD.CO */
		{
			strncpy(Name, "ADD.CO", 19);
			break;
		}
		case 0x02: /* ADD.CIO */
		{
			strncpy(Name, "ADD.CIO", 19);
			break;
		}
		case 0x03: /* ADDU.CI */
		{
			strncpy(Name, "ADDU.CI", 19);
			break;
		}
		case 0x04: /* ADDU.CO */
		{
			strncpy(Name, "ADDU.CO", 19);
			break;
		}
		case 0x05: /* ADDU.CIO */
		{
			strncpy(Name, "ADDU.CIO", 19);
			break;
		}
		case 0x06: /* SUB.BI */
		{
			strncpy(Name, "SUB.BI", 19);
			break;
		}
		case 0x07: /* SUB.BO */
		{
			strncpy(Name, "SUB.BO", 19);
			break;
		}
		case 0x08: /* SUB.BIO */
		{
			strncpy(Name, "SUB.BIO", 19);
			break;
		}
		case 0x09: /* SUBU.BI */
		{
			strncpy(Name, "SUBU.BI", 19);
			break;
		}
		case 0x0A: /* SUBU.BO */
		{
			strncpy(Name, "SUBU.BO", 19);
			break;
		}
		case 0x0B: /* SUBU.BIO */
		{
			strncpy(Name, "SUBU.BIO", 19);
			break;
		}
		case 0x0C: /* MULTIPLY */
		{
			strncpy(Name, "MULTIPLY", 19);
			break;
		}
		case 0x0D: /* MULTIPLYU */
		{
			strncpy(Name, "MULTIPLYU", 19);
			break;
		}
		case 0x0E: /* DIVIDE */
		{
			strncpy(Name, "DIVIDE", 19);
			break;
		}
		case 0x0F: /* DIVIDEU */
		{
			strncpy(Name, "DIVIDEU", 19);
			break;
		}
		case 0x10: /* MUX */
		{
			strncpy(Name, "MUX", 19);
			break;
		}
		case 0x11: /* NMUX */
		{
			strncpy(Name, "NMUX", 19);
			break;
		}
		case 0x12: /* SORT */
		{
			strncpy(Name, "SORT", 19);
			break;
		}
		case 0x13: /* SORTU */
		{
			strncpy(Name, "SORTU", 19);
			break;
		}
		default: /* Unknown 4OP */
		{
			break;
		}
	}
	fprintf(stdout, "%s reg%u reg%u reg%u reg%u\t", Name, c->reg0, c->reg1, c->reg2, c->reg3);
	fprintf(stdout, "# %s\n", c->operation);
}

void decode_Integer_3OP(struct Instruction* c)
{
	/* Parse raw data */
	c->raw_XOP = c->raw1*0x10 + c->raw2/16;
	c->XOP[0] = c->operation[2];
	c->XOP[1] = c->operation[3];
	c->XOP[2] = c->operation[4];
	c->raw_Immediate = 0;
	c->reg0 = c->raw2%16;
	c->reg1 = c->raw3/16;
	c->reg2 = c->raw3%16;

	char Name[20] = "ILLEGAL_3OP";

	/* Convert to Human readable form */
	switch(c->raw_XOP)
	{
		case 0x000: /* ADD */
		{
			strncpy(Name, "ADD", 19);
			break;
		}
		case 0x001: /* ADDU */
		{
			strncpy(Name, "ADDU", 19);
			break;
		}
		case 0x002: /* SUB */
		{
			strncpy(Name, "SUB", 19);
			break;
		}
		case 0x003: /* SUBU */
		{
			strncpy(Name, "SUBU", 19);
			break;
		}
		case 0x004: /* CMP */
		{
			strncpy(Name, "CMP", 19);
			break;
		}
		case 0x005: /* CMPU */
		{
			strncpy(Name, "CMPU", 19);
			break;
		}
		case 0x006: /* MUL */
		{
			strncpy(Name, "MUL", 19);
			break;
		}
		case 0x007: /* MULH */
		{
			strncpy(Name, "MULH", 19);
			break;
		}
		case 0x008: /* MULU */
		{
			strncpy(Name, "MULU", 19);
			break;
		}
		case 0x009: /* MULUH */
		{
			strncpy(Name, "MULUH", 19);
			break;
		}
		case 0x00A: /* DIV */
		{
			strncpy(Name, "DIV", 19);
			break;
		}
		case 0x00B: /* MOD */
		{
			strncpy(Name, "MOD", 19);
			break;
		}
		case 0x00C: /* DIVU */
		{
			strncpy(Name, "DIVU", 19);
			break;
		}
		case 0x00D: /* MODU */
		{
			strncpy(Name, "MODU", 19);
			break;
		}
		case 0x010: /* MAX */
		{
			strncpy(Name, "MAX", 19);
			break;
		}
		case 0x011: /* MAXU */
		{
			strncpy(Name, "MAXU", 19);
			break;
		}
		case 0x012: /* MIN */
		{
			strncpy(Name, "MIN", 19);
			break;
		}
		case 0x013: /* MINU */
		{
			strncpy(Name, "MINU", 19);
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
			strncpy(Name, "PACK16.CO", 19);
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
			break;
		}
		case 0x021: /* OR */
		{
			strncpy(Name, "OR", 19);
			break;
		}
		case 0x022: /* XOR */
		{
			strncpy(Name, "XOR", 19);
			break;
		}
		case 0x023: /* NAND */
		{
			strncpy(Name, "NAND", 19);
			break;
		}
		case 0x024: /* NOR */
		{
			strncpy(Name, "NOR", 19);
			break;
		}
		case 0x025: /* XNOR */
		{
			strncpy(Name, "XNOR", 19);
			break;
		}
		case 0x026: /* MPQ */
		{
			strncpy(Name, "MPQ", 19);
			break;
		}
		case 0x027: /* LPQ */
		{
			strncpy(Name, "LPQ", 19);
			break;
		}
		case 0x028: /* CPQ */
		{
			strncpy(Name, "CPQ", 19);
			break;
		}
		case 0x029: /* BPQ */
		{
			strncpy(Name, "BPQ", 19);
			break;
		}
		case 0x030: /* SAL */
		{
			strncpy(Name, "SAL", 19);
			break;
		}
		case 0x031: /* SAR */
		{
			strncpy(Name, "SAR", 19);
			break;
		}
		case 0x032: /* SL0 */
		{
			strncpy(Name, "SL0", 19);
			break;
		}
		case 0x033: /* SR0 */
		{
			strncpy(Name, "SR0", 19);
			break;
		}
		case 0x034: /* SL1 */
		{
			strncpy(Name, "SL1", 19);
			break;
		}
		case 0x035: /* SR1 */
		{
			strncpy(Name, "SR1", 19);
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
			break;
		}
		case 0x039: /* LOADX8 */
		{
			strncpy(Name, "LOADX8", 19);
			break;
		}
		case 0x03A: /* LOADXU8 */
		{
			strncpy(Name, "LOADXU8", 19);
			break;
		}
		case 0x03B: /* LOADX16 */
		{
			strncpy(Name, "LOADX16", 19);
			break;
		}
		case 0x03C: /* LOADXU16 */
		{
			strncpy(Name, "LOADXU16", 19);
			break;
		}
		case 0x03D: /* LOADX32 */
		{
			strncpy(Name, "LOADX32", 19);
			break;
		}
		case 0x03E: /* LOADXU32 */
		{
			strncpy(Name, "LOADXU32", 19);
			break;
		}
		case 0x048: /* STOREX */
		{
			strncpy(Name, "STOREX", 19);
			break;
		}
		case 0x049: /* STOREX8 */
		{
			strncpy(Name, "STOREX8", 19);
			break;
		}
		case 0x04A: /* STOREX16 */
		{
			strncpy(Name, "STOREX16", 19);
			break;
		}
		case 0x04B: /* STOREX32 */
		{
			strncpy(Name, "STOREX32", 19);
			break;
		}
		default: /* Unknown 3OP*/
		{
			break;
		}
	}

	fprintf(stdout, "%s reg%u reg%u reg%u\t", Name, c->reg0, c->reg1, c->reg2);
	fprintf(stdout, "# %s\n", c->operation);
}

void decode_Integer_2OP(struct Instruction* c)
{
	/* Parse Raw Data */
	c->raw_XOP = c->raw1*0x100 + c->raw2;
	c->XOP[0] = c->operation[2];
	c->XOP[1] = c->operation[3];
	c->XOP[2] = c->operation[4];
	c->XOP[3] = c->operation[5];
	c->raw_Immediate = 0;
	c->reg0 = c->raw3/16;
	c->reg1 = c->raw3%16;

	char Name[20] = "ILLEGAL_2OP";

	/* Convert to Human readable form */
	switch(c->raw_XOP)
	{
		case 0x0000: /* NEG */
		{
			strncpy(Name, "NEG", 19);
			break;
		}
		case 0x0001: /* ABS */
		{
			strncpy(Name, "ABS", 19);
			break;
		}
		case 0x0002: /* NABS */
		{
			strncpy(Name, "NABS", 19);
			break;
		}
		case 0x0003: /* SWAP */
		{
			strncpy(Name, "SWAP", 19);
			break;
		}
		case 0x0004: /* COPY */
		{
			strncpy(Name, "COPY", 19);
			break;
		}
		case 0x0005: /* MOVE */
		{
			strncpy(Name, "MOVE", 19);
			break;
		}
		case 0x0006: /* NOT */
		{
			strncpy(Name, "NOT", 19);
			break;
		}
		case 0x0100: /* BRANCH */
		{
			strncpy(Name, "BRANCH", 19);
			break;
		}
		case 0x0101: /* CALL */
		{
			strncpy(Name, "CALL", 19);
			break;
		}
		case 0x0200: /* PUSHR */
		{
			strncpy(Name, "PUSHR", 19);
			break;
		}
		case 0x0201: /* PUSH8 */
		{
			strncpy(Name, "PUSH8", 19);
			break;
		}
		case 0x0202: /* PUSH16 */
		{
			strncpy(Name, "PUSH16", 19);
			break;
		}
		case 0x0203: /* PUSH32 */
		{
			strncpy(Name, "PUSH32", 19);
			break;
		}
		case 0x0280: /* POPR */
		{
			strncpy(Name, "POPR", 19);
			break;
		}
		case 0x0281: /* POP8 */
		{
			strncpy(Name, "POP8", 19);
			break;
		}
		case 0x0282: /* POPU8 */
		{
			strncpy(Name, "POPU8", 19);
			break;
		}
		case 0x0283: /* POP16 */
		{
			strncpy(Name, "POP16", 19);
			break;
		}
		case 0x0284: /* POPU16 */
		{
			strncpy(Name, "POPU16", 19);
			break;
		}
		case 0x0285: /* POP32 */
		{
			strncpy(Name, "POP32", 19);
			break;
		}
		case 0x0286: /* POPU32 */
		{
			strncpy(Name, "POPU32", 19);
			break;
		}
		default: /* Unknown 2OP*/
		{
			break;
		}
	}

	fprintf(stdout, "%s reg%u reg%u\t", Name, c->reg0, c->reg1);
	fprintf(stdout, "# %s\n", c->operation);
}

void decode_1OP(struct Instruction* c)
{
	/* Parse Raw Data */
	c->raw_XOP = c->raw1*0x1000 + c->raw2*0x10 + c->raw3/16;
	c->XOP[0] = c->operation[2];
	c->XOP[1] = c->operation[3];
	c->XOP[2] = c->operation[4];
	c->XOP[3] = c->operation[5];
	c->XOP[4] = c->operation[6];
	c->raw_Immediate = 0;
	c->reg0 = c->raw3%16;

	char Name[20] = "ILLEGAL_1OP";

	/* Convert to Human readable form */
	switch(c->raw_XOP)
	{
		case 0x00000: /* READPC */
		{
			strncpy(Name, "READPC", 19);
			break;
		}
		case 0x00001: /* READSCID */
		{
			strncpy(Name, "READSCID", 19);
			break;
		}
		case 0x00002: /* FALSE */
		{
			strncpy(Name, "FALSE", 19);
			break;
		}
		case 0x00003: /* TRUE */
		{
			strncpy(Name, "TRUE", 19);
			break;
		}
		case 0x01000: /* JSR_COROUTINE */
		{
			strncpy(Name, "JSR_COROUTINE", 19);
			break;
		}
		case 0x01001: /* RET */
		{
			strncpy(Name, "RET", 19);
			break;
		}
		case 0x02000: /* PUSHPC */
		{
			strncpy(Name, "PUSHPC", 19);
			break;
		}
		case 0x02001: /* POPPC */
		{
			strncpy(Name, "POPPC", 19);
			break;
		}
		default: /* Unknown 1OP*/
		{
			break;
		}
	}

	fprintf(stdout, "%s reg%u\t", Name, c->reg0);
	fprintf(stdout, "# %s\n", c->operation);
}

void decode_0OP(struct Instruction* c)
{
	/* Parse Raw Data*/
	uint32_t FULL_OP;
	FULL_OP = c->raw0*0x1000000 + c->raw1*0x10000 + c->raw2*0x100 + c->raw3;

	char Name[20] = "ILLEGAL_0OP";

	/* Convert to Human readable form */
	switch(FULL_OP)
	{
		case 0x00000000: /* NOP */
		{
			strncpy(Name, "NOP", 19);
			break;
		}
		case 0x00000001 ... 0x00FFFFFF: /* IMPROPER_NOP */
		{
			strncpy(Name, "IMPROPER_NOP", 19);
			break;
		}
		case 0xFF000000 ... 0xFFFFFFFE: /* IMPROPER_HALT */
		{
			strncpy(Name, "IMPROPER_HALT", 19);
			break;
		}
		case 0xFFFFFFFF: /* HALT */
		{
			strncpy(Name, "HALT", 19);
			break;
		}
		default: /* Unknown 1OP*/
		{
			break;
		}
	}

	fprintf(stdout, "%s\t", Name);
	fprintf(stdout, "# %s\n", c->operation);
}

void decode_Integer_2OPI(struct Instruction* c)
{
	/* Parse Raw Data */
	c->raw_Immediate = c->raw2*0x100 + c->raw3;
	c->Immediate[0] = c->operation[4];
	c->Immediate[1] = c->operation[5];
	c->Immediate[2] = c->operation[6];
	c->Immediate[3] = c->operation[7];
	c->reg0 = c->raw1/16;
	c->reg1 = c->raw1%16;

	char Name[20] = "ILLEGAL_2OPI";

	/* Convert to Human readable form */
	switch(c->raw0)
	{
		case 0x0E: /* ADDI */
		{
			strncpy(Name, "ADDI", 19);
			break;
		}
		case 0x0F: /* ADDUI */
		{
			strncpy(Name, "ADDUI", 19);
			break;
		}
		case 0x10: /* SUBI */
		{
			strncpy(Name, "SUBI", 19);
			break;
		}
		case 0x11: /* SUBUI */
		{
			strncpy(Name, "SUBUI", 19);
			break;
		}
		case 0x12: /* CMPI */
		{
			strncpy(Name, "CMPI", 19);
			break;
		}
		case 0x13: /* LOAD */
		{
			strncpy(Name, "LOAD", 19);
			break;
		}
		case 0x14: /* LOAD8 */
		{
			strncpy(Name, "LOAD8", 19);
			break;
		}
		case 0x15: /* LOADU8 */
		{
			strncpy(Name, "LOADU8", 19);
			break;
		}
		case 0x16: /* LOAD16 */
		{
			strncpy(Name, "LOAD16", 19);
			break;
		}
		case 0x17: /* LOADU16 */
		{
			strncpy(Name, "LOADU16", 19);
			break;
		}
		case 0x18: /* LOAD32 */
		{
			strncpy(Name, "LOAD32", 19);
			break;
		}
		case 0x19: /* LOADU32 */
		{
			strncpy(Name, "LOADU32", 19);
			break;
		}
		case 0x1F: /* CMPUI */
		{
			strncpy(Name, "CMPUI", 19);
			break;
		}
		case 0x20: /* STORE */
		{
			strncpy(Name, "STORE", 19);
			break;
		}
		case 0x21: /* STORE8 */
		{
			strncpy(Name, "STORE8", 19);
			break;
		}
		case 0x22: /* STORE16 */
		{
			strncpy(Name, "STORE16", 19);
			break;
		}
		case 0x23: /* STORE32 */
		{
			strncpy(Name, "STORE32", 19);
			break;
		}
		case 0xB0: /* ANDI */
		{
			strncpy(Name, "ANDI", 19);
			break;
		}
		case 0xB1: /* ORI */
		{
			strncpy(Name, "ORI", 19);
			break;
		}
		case 0xB2: /* XORI */
		{
			strncpy(Name, "XORI", 19);
			break;
		}
		case 0xB3: /* NANDI */
		{
			strncpy(Name, "NANDI", 19);
			break;
		}
		case 0xB4: /* NORI */
		{
			strncpy(Name, "NORI", 19);
			break;
		}
		case 0xB5: /* XNORI */
		{
			strncpy(Name, "XNORI", 19);
			break;
		}
		case 0xC0: /* CMPJUMP.G */
		{
			strncpy(Name, "CMPJUMP.G", 19);
			break;
		}
		case 0xC1: /* CMPJUMP.GE */
		{
			strncpy(Name, "CMPJUMP.GE", 19);
			break;
		}
		case 0xC2: /* CMPJUMP.E */
		{
			strncpy(Name, "CMPJUMP.E", 19);
			break;
		}
		case 0xC3: /* CMPJUMP.NE */
		{
			strncpy(Name, "CMPJUMP.NE", 19);
			break;
		}
		case 0xC4: /* CMPJUMP.LE */
		{
			strncpy(Name, "CMPJUMP.LE", 19);
			break;
		}
		case 0xC5: /* CMPJUMP.L */
		{
			strncpy(Name, "CMPJUMP.L", 19);
			break;
		}
		case 0xD0: /* CMPJUMPU.G */
		{
			strncpy(Name, "CMPJUMPU.G", 19);
			break;
		}
		case 0xD1: /* CMPJUMPU.GE */
		{
			strncpy(Name, "CMPJUMPU.GE", 19);
			break;
		}
		case 0xD4: /* CMPJUMPU.LE */
		{
			strncpy(Name, "CMPJUMPU.LE", 19);
			break;
		}
		case 0xD5: /* CMPJUMPU.L */
		{
			strncpy(Name, "CMPJUMPU.L", 19);
			break;
		}
		default: /* Unknown 2OPI*/
		{
			break;
		}
	}

	fprintf(stdout, "%s reg%u reg%u 0x%x\t", Name, c->reg0, c->reg1, c->raw_Immediate);
	fprintf(stdout, "# %s\n", c->operation);
}

void decode_1OPI(struct Instruction* c)
{
	/* Parse Raw Data */
	c->raw_Immediate = c->raw2*0x100 + c->raw3;
	c->Immediate[0] = c->operation[3];
	c->Immediate[1] = c->operation[4];
	c->Immediate[2] = c->operation[5];
	c->Immediate[3] = c->operation[6];
	c->Immediate[4] = c->operation[7];
	c->HAL_CODE = 0;
	c->raw_XOP = c->raw1/16;
	c->reg0 = c->raw1%16;

	char Name[20] = "ILLEGAL_1OPI";
	uint32_t Opcode = (c->raw0 * 16) + c->raw_XOP;

	/* Convert to Human readable form */
	switch(Opcode)
	{
		case 0x2C0: /* JUMP.C */
		{
			strncpy(Name, "JUMP.C", 19);
			break;
		}
		case 0x2C1: /* JUMP.B */
		{
			strncpy(Name, "JUMP.B", 19);
			break;
		}
		case 0x2C2: /* JUMP.O */
		{
			strncpy(Name, "JUMP.O", 19);
			break;
		}
		case 0x2C3: /* JUMP.G */
		{
			strncpy(Name, "JUMP.G", 19);
			break;
		}
		case 0x2C4: /* JUMP.GE */
		{
			strncpy(Name, "JUMP.GE", 19);
			break;
		}
		case 0x2C5: /* JUMP.E */
		{
			strncpy(Name, "JUMP.E", 19);
			break;
		}
		case 0x2C6: /* JUMP.NE */
		{
			strncpy(Name, "JUMP.NE", 19);
			break;
		}
		case 0x2C7: /* JUMP.LE */
		{
			strncpy(Name, "JUMP.LE", 19);
			break;
		}
		case 0x2C8: /* JUMP.L */
		{
			strncpy(Name, "JUMP.L", 19);
			break;
		}
		case 0x2C9: /* JUMP.Z */
		{
			strncpy(Name, "JUMP.Z", 19);
			break;
		}
		case 0x2CA: /* JUMP.NZ */
		{
			strncpy(Name, "JUMP.NZ", 19);
			break;
		}
		case 0x2CB: /* JUMP.P */
		{
			strncpy(Name, "JUMP.P", 19);
			break;
		}
		case 0x2CC: /* JUMP.NP */
		{
			strncpy(Name, "JUMP.NP", 19);
			break;
		}
		case 0x2D0: /* CALLI */
		{
			strncpy(Name, "CALLI", 19);
			break;
		}
		case 0x2D1: /* LOADI */
		{
			strncpy(Name, "LOADI", 19);
			break;
		}
		case 0x2D2: /* LOADUI*/
		{
			strncpy(Name, "LOADUI", 19);
			break;
		}
		case 0x2D3: /* SALI */
		{
			strncpy(Name, "SALI", 19);
			break;
		}
		case 0x2D4: /* SARI */
		{
			strncpy(Name, "SARI", 19);
			break;
		}
		case 0x2D5: /* SL0I */
		{
			strncpy(Name, "SL0I", 19);
			break;
		}
		case 0x2D6: /* SR0I */
		{
			strncpy(Name, "SR0I", 19);
			break;
		}
		case 0x2D7: /* SL1I */
		{
			strncpy(Name, "SL1I", 19);
			break;
		}
		case 0x2D8: /* SR1I */
		{
			strncpy(Name, "SR1I", 19);
			break;
		}
		case 0x2E0: /* LOADR */
		{
			strncpy(Name, "LOADR", 19);
			break;
		}
		case 0x2E1: /* LOADR8 */
		{
			strncpy(Name, "LOADR8", 19);
			break;
		}
		case 0x2E2: /* LOADRU8 */
		{
			strncpy(Name, "LOADRU8", 19);
			break;
		}
		case 0x2E3: /* LOADR16 */
		{
			strncpy(Name, "LOADR16", 19);
			break;
		}
		case 0x2E4: /* LOADRU16 */
		{
			strncpy(Name, "LOADRU16", 19);
			break;
		}
		case 0x2E5: /* LOADR32 */
		{
			strncpy(Name, "LOADR32", 19);
			break;
		}
		case 0x2E6: /* LOADRU32 */
		{
			strncpy(Name, "LOADRU32", 19);
			break;
		}
		case 0x2F0: /* STORER */
		{
			strncpy(Name, "STORER", 19);
			break;
		}
		case 0x2F1: /* STORER8 */
		{
			strncpy(Name, "STORER8", 19);
			break;
		}
		case 0x2F2: /* STORER16 */
		{
			strncpy(Name, "STORER16", 19);
			break;
		}
		case 0x2F3: /* STORER32 */
		{
			strncpy(Name, "STORER32", 19);
			break;
		}
		case 0xA00: /* CMPSKIPI.G */
		{
			strncpy(Name, "CMPSKIPI.G", 19);
			break;
		}
		case 0xA01: /* CMPSKIPI.GE */
		{
			strncpy(Name, "CMPSKIPI.GE", 19);
			break;
		}
		case 0xA02: /* CMPSKIPI.E */
		{
			strncpy(Name, "CMPSKIPI.E", 19);
			break;
		}
		case 0xA03: /* CMPSKIPI.NE */
		{
			strncpy(Name, "CMPSKIPI.NE", 19);
			break;
		}
		case 0xA04: /* CMPSKIPI.LE */
		{
			strncpy(Name, "CMPSKIPI.LE", 19);
			break;
		}
		case 0xA05: /* CMPSKIPI.L */
		{
			strncpy(Name, "CMPSKIPI.L", 19);
			break;
		}
		case 0xA10: /* CMPSKIPUI.G */
		{
			strncpy(Name, "CMPSKIPUI.G", 19);
			break;
		}
		case 0xA11: /* CMPSKIPUI.GE */
		{
			strncpy(Name, "CMPSKIPUI.GE", 19);
			break;
		}
		case 0xA14: /* CMPSKIPUI.LE */
		{
			strncpy(Name, "CMPSKIPUI.LE", 19);
			break;
		}
		case 0xA15: /* CMPSKIPUI.L */
		{
			strncpy(Name, "CMPSKIPUI.L", 19);
			break;
		}
		default: /* Unknown 1OPI*/
		{
			break;
		}
	}

	fprintf(stdout, "%s reg%u %d\t", Name, c->reg0, c->raw_Immediate);
	fprintf(stdout, "# %s\n", c->operation);
}

void decode_0OPI(struct Instruction* c)
{
	/* Parse Raw Data */
	c->raw_Immediate = c->raw2*0x100 + c->raw3;
	c->Immediate[0] = c->operation[4];
	c->Immediate[1] = c->operation[5];
	c->Immediate[2] = c->operation[6];
	c->Immediate[3] = c->operation[7];
	c->HAL_CODE = 0;
	c->raw_XOP = c->raw1;
	c->XOP[0] = c->operation[2];
	c->XOP[1] = c->operation[3];

	char Name[20] = "ILLEGAL_0OPI";

	/* Convert to Human readable form */
	switch(c->raw_XOP)
	{
		case 0x00: /* JUMP */
		{
			strncpy(Name, "JUMP", 19);
			break;
		}
		default: /* Unknown 1OPI*/
		{
			break;
		}
	}

	fprintf(stdout, "%s %d\t", Name, c->raw_Immediate);
	fprintf(stdout, "# %s\n", c->operation);
}

void decode_HALCODE(struct Instruction* c)
{
	/* Parse Raw Data */
	c->HAL_CODE = c->raw1*0x10000 + c->raw2*0x100 + c->raw3;

	char Name[20] = "ILLEGAL_HALCODE";

	/* Convert to Human readable form */
	switch(c->HAL_CODE)
	{
		case 0x100000: /* FOPEN_READ */
		{
			strncpy(Name, "FOPEN_READ", 19);
			break;
		}
		case 0x100001: /* FOPEN_WRITE */
		{
			strncpy(Name, "FOPEN_WRITE", 19);
			break;
		}
		case 0x100002: /* FCLOSE */
		{
			strncpy(Name, "FCLOSE", 19);
			break;
		}
		case 0x100003: /* REWIND */
		{
			strncpy(Name, "REWIND", 19);
			break;
		}
		case 0x100004: /* FSEEK */
		{
			strncpy(Name, "FSEEK", 19);
			break;
		}
		case 0x100100: /* FGETC */
		{
			strncpy(Name, "FGETC", 19);
			break;
		}
		case 0x100200: /* FPUTC */
		{
			strncpy(Name, "FPUTC", 19);
			break;
		}
		default: /* Unknown HALCODE*/
		{
			break;
		}
	}

	fprintf(stdout, "%s\t", Name);
	fprintf(stdout, "# %s\n", c->operation);
}

void eval_instruction(struct Instruction* c)
{
	switch(c->raw0)
	{
		case 0x01: /* Integer 4OP */
		{
			decode_Integer_4OP(c);
			break;
		}
		case 0x05: /* Integer 3OP */
		{
			decode_Integer_3OP(c);
			break;
		}
		case 0x09: /* Integer 2OP */
		{
			decode_Integer_2OP(c);
			break;
		}
		case 0x0D: /* 1OP */
		{
			decode_1OP(c);
			break;
		}
		case 0x0E ... 0x2B: /* 2OPI */
		case 0xB0 ... 0xDF:
		{
			decode_Integer_2OPI(c);
			break;
		}
		case 0x2C ... 0x2F: /* 1OPI */
		case 0xA0 ... 0xA1:
		{
			decode_1OPI(c);
			break;
		}
		case 0x3C: /* Core 0OPI */
		{
			decode_0OPI(c);
			break;
		}
		case 0x42: /* HALCODE */
		{
			decode_HALCODE(c);
			break;
		}
		case 0x00: /* NOP */
		case 0xFF: /* HALT */
		{
			decode_0OP(c);
			break;
		}
		default: /* Not supported by this disassembler */
		{
			fprintf(stdout, "ILLEGAL INSTRUCTION\t# %s\n", c->operation);
		}
	}
}

/* Standard C main program */
int main(int argc, char **argv)
{
	/* Make sure we have a program tape to run */
	if (argc < 2)
	{
		fprintf(stderr, "Usage: %s $FileName\nWhere $FileName is the name of program being disassembled\n", argv[0]);
		return EXIT_FAILURE;
	}

	binary_file = fopen(argv[1], "r");
	struct Instruction* current;
	current = calloc(1, sizeof(struct Instruction));

	int32_t byte;
	byte = fgetc(binary_file);
	ungetc(byte, binary_file);

	while(EOF != byte)
	{
		read_instruction(current);
		eval_instruction(current);
		byte = fgetc(binary_file);
		ungetc(byte, binary_file);
	}

	fclose(binary_file);

	return EXIT_SUCCESS;
}
