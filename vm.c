#include "vm.h"
#define DEBUG true
uint32_t performance_counter;

/* Prototypes for functions in vm_instructions.c*/
void vm_FOPEN_READ(struct lilith* vm);
void vm_FOPEN_WRITE(struct lilith* vm);
void vm_FCLOSE(struct lilith* vm);
void vm_FSEEK(struct lilith* vm);
void vm_REWIND(struct lilith* vm);
void vm_FGETC(struct lilith* vm);
void vm_FPUTC(struct lilith* vm);
void ADD_CI(struct lilith* vm, struct Instruction* c);
void ADD_CO(struct lilith* vm, struct Instruction* c);
void ADD_CIO(struct lilith* vm, struct Instruction* c);
void ADDU_CI(struct lilith* vm, struct Instruction* c);
void ADDU_CO(struct lilith* vm, struct Instruction* c);
void ADDU_CIO(struct lilith* vm, struct Instruction* c);
void SUB_BI(struct lilith* vm, struct Instruction* c);
void SUB_BO(struct lilith* vm, struct Instruction* c);
void SUB_BIO(struct lilith* vm, struct Instruction* c);
void SUBU_BI(struct lilith* vm, struct Instruction* c);
void SUBU_BO(struct lilith* vm, struct Instruction* c);
void SUBU_BIO(struct lilith* vm, struct Instruction* c);
void MULTIPLY(struct lilith* vm, struct Instruction* c);
void MULTIPLYU(struct lilith* vm, struct Instruction* c);
void DIVIDE(struct lilith* vm, struct Instruction* c);
void DIVIDEU(struct lilith* vm, struct Instruction* c);
void MUX(struct lilith* vm, struct Instruction* c);
void NMUX(struct lilith* vm, struct Instruction* c);
void SORT(struct lilith* vm, struct Instruction* c);
void SORTU(struct lilith* vm, struct Instruction* c);
void ADD(struct lilith* vm, struct Instruction* c);
void ADDU(struct lilith* vm, struct Instruction* c);
void SUB(struct lilith* vm, struct Instruction* c);
void SUBU(struct lilith* vm, struct Instruction* c);
void CMP(struct lilith* vm, struct Instruction* c);
void CMPU(struct lilith* vm, struct Instruction* c);
void MUL(struct lilith* vm, struct Instruction* c);
void MULH(struct lilith* vm, struct Instruction* c);
void MULU(struct lilith* vm, struct Instruction* c);
void MULUH(struct lilith* vm, struct Instruction* c);
void DIV(struct lilith* vm, struct Instruction* c);
void MOD(struct lilith* vm, struct Instruction* c);
void DIVU(struct lilith* vm, struct Instruction* c);
void MODU(struct lilith* vm, struct Instruction* c);
void MAX(struct lilith* vm, struct Instruction* c);
void MAXU(struct lilith* vm, struct Instruction* c);
void MIN(struct lilith* vm, struct Instruction* c);
void MINU(struct lilith* vm, struct Instruction* c);
void PACK(struct lilith* vm, struct Instruction* c);
void UNPACK(struct lilith* vm, struct Instruction* c);
void PACK8_CO(struct lilith* vm, struct Instruction* c);
void PACK8U_CO(struct lilith* vm, struct Instruction* c);
void PACK16_CO(struct lilith* vm, struct Instruction* c);
void PACK16U_CO(struct lilith* vm, struct Instruction* c);
void PACK32_CO(struct lilith* vm, struct Instruction* c);
void PACK32U_CO(struct lilith* vm, struct Instruction* c);
void AND(struct lilith* vm, struct Instruction* c);
void OR(struct lilith* vm, struct Instruction* c);
void XOR(struct lilith* vm, struct Instruction* c);
void NAND(struct lilith* vm, struct Instruction* c);
void NOR(struct lilith* vm, struct Instruction* c);
void XNOR(struct lilith* vm, struct Instruction* c);
void MPQ(struct lilith* vm, struct Instruction* c);
void LPQ(struct lilith* vm, struct Instruction* c);
void CPQ(struct lilith* vm, struct Instruction* c);
void BPQ(struct lilith* vm, struct Instruction* c);
void SAL(struct lilith* vm, struct Instruction* c);
void SAR(struct lilith* vm, struct Instruction* c);
void SL0(struct lilith* vm, struct Instruction* c);
void SR0(struct lilith* vm, struct Instruction* c);
void SL1(struct lilith* vm, struct Instruction* c);
void SR1(struct lilith* vm, struct Instruction* c);
void ROL(struct lilith* vm, struct Instruction* c);
void ROR(struct lilith* vm, struct Instruction* c);
void LOADX(struct lilith* vm, struct Instruction* c);
void LOADX8(struct lilith* vm, struct Instruction* c);
void LOADXU8(struct lilith* vm, struct Instruction* c);
void LOADX16(struct lilith* vm, struct Instruction* c);
void LOADXU16(struct lilith* vm, struct Instruction* c);
void LOADX32(struct lilith* vm, struct Instruction* c);
void LOADXU32(struct lilith* vm, struct Instruction* c);
void STOREX(struct lilith* vm, struct Instruction* c);
void STOREX8(struct lilith* vm, struct Instruction* c);
void STOREX16(struct lilith* vm, struct Instruction* c);
void STOREX32(struct lilith* vm, struct Instruction* c);
void NEG(struct lilith* vm, struct Instruction* c);
void ABS(struct lilith* vm, struct Instruction* c);
void NABS(struct lilith* vm, struct Instruction* c);
void SWAP(struct lilith* vm, struct Instruction* c);
void COPY(struct lilith* vm, struct Instruction* c);
void MOVE(struct lilith* vm, struct Instruction* c);
void BRANCH(struct lilith* vm, struct Instruction* c);
void CALL(struct lilith* vm, struct Instruction* c);
void READPC(struct lilith* vm, struct Instruction* c);
void READSCID(struct lilith* vm, struct Instruction* c);
void FALSE(struct lilith* vm, struct Instruction* c);
void TRUE(struct lilith* vm, struct Instruction* c);
void JSR_COROUTINE(struct lilith* vm, struct Instruction* c);
void RET(struct lilith* vm, struct Instruction* c);
void PUSHPC(struct lilith* vm, struct Instruction* c);
void POPPC(struct lilith* vm, struct Instruction* c);
void ADDI(struct lilith* vm, struct Instruction* c);
void ADDUI(struct lilith* vm, struct Instruction* c);
void SUBI(struct lilith* vm, struct Instruction* c);
void SUBUI(struct lilith* vm, struct Instruction* c);
void CMPI(struct lilith* vm, struct Instruction* c);
void LOAD(struct lilith* vm, struct Instruction* c);
void LOAD8(struct lilith* vm, struct Instruction* c);
void LOADU8(struct lilith* vm, struct Instruction* c);
void LOAD16(struct lilith* vm, struct Instruction* c);
void LOADU16(struct lilith* vm, struct Instruction* c);
void LOAD32(struct lilith* vm, struct Instruction* c);
void LOADU32(struct lilith* vm, struct Instruction* c);
void CMPUI(struct lilith* vm, struct Instruction* c);
void STORE(struct lilith* vm, struct Instruction* c);
void STORE8(struct lilith* vm, struct Instruction* c);
void STORE16(struct lilith* vm, struct Instruction* c);
void STORE32(struct lilith* vm, struct Instruction* c);
void JUMP_C(struct lilith* vm, struct Instruction* c);
void JUMP_B(struct lilith* vm, struct Instruction* c);
void JUMP_O(struct lilith* vm, struct Instruction* c);
void JUMP_G(struct lilith* vm, struct Instruction* c);
void JUMP_GE(struct lilith* vm, struct Instruction* c);
void JUMP_E(struct lilith* vm, struct Instruction* c);
void JUMP_NE(struct lilith* vm, struct Instruction* c);
void JUMP_LE(struct lilith* vm, struct Instruction* c);
void JUMP_L(struct lilith* vm, struct Instruction* c);
void JUMP_Z(struct lilith* vm, struct Instruction* c);
void JUMP_NZ(struct lilith* vm, struct Instruction* c);
void CALLI(struct lilith* vm, struct Instruction* c);
void LOADI(struct lilith* vm, struct Instruction* c);
void LOADUI(struct lilith* vm, struct Instruction* c);
void SALI(struct lilith* vm, struct Instruction* c);
void SARI(struct lilith* vm, struct Instruction* c);
void SL0I(struct lilith* vm, struct Instruction* c);
void SR0I(struct lilith* vm, struct Instruction* c);
void SL1I(struct lilith* vm, struct Instruction* c);
void SR1I(struct lilith* vm, struct Instruction* c);
void JUMP(struct lilith* vm, struct Instruction* c);

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

/* Deal with 4OP */
void decode_4OP(struct Instruction* c)
{
	c->raw_XOP = c->raw1;
	c->XOP[0] = c->operation[2];
	c->XOP[1] = c->operation[3];
	c->raw_Immediate = 0;
	c->reg0 = c->raw2/16;
	c->reg1 = c->raw2%16;
	c->reg2 = c->raw3/16;
	c->reg3 = c->raw3%16;
}

/* Deal with 3OP */
void decode_3OP(struct Instruction* c)
{
	c->raw_XOP = c->raw1*0x10 + c->raw2/16;
	c->XOP[0] = c->operation[2];
	c->XOP[1] = c->operation[3];
	c->XOP[2] = c->operation[4];
	c->raw_Immediate = 0;
	c->reg0 = c->raw2%16;
	c->reg1 = c->raw3/16;
	c->reg2 = c->raw3%16;
}

/* Deal with 2OP */
void decode_2OP(struct Instruction* c)
{
	c->raw_XOP = c->raw1*0x100 + c->raw2;
	c->XOP[0] = c->operation[2];
	c->XOP[1] = c->operation[3];
	c->XOP[2] = c->operation[4];
	c->XOP[3] = c->operation[5];
	c->raw_Immediate = 0;
	c->reg0 = c->raw3/16;
	c->reg1 = c->raw3%16;
}

/* Deal with 1OP */
void decode_1OP(struct Instruction* c)
{
	c->raw_XOP = c->raw1*0x1000 + c->raw2*0x10 + c->raw3/16;
	c->XOP[0] = c->operation[2];
	c->XOP[1] = c->operation[3];
	c->XOP[2] = c->operation[4];
	c->XOP[3] = c->operation[5];
	c->XOP[4] = c->operation[6];
	c->raw_Immediate = 0;
	c->reg0 = c->raw3%16;
}

/* Deal with 2OPI */
void decode_2OPI(struct Instruction* c)
{
	c->raw_Immediate = c->raw2*0x100 + c->raw3;
	c->Immediate[0] = c->operation[4];
	c->Immediate[1] = c->operation[5];
	c->Immediate[2] = c->operation[6];
	c->Immediate[3] = c->operation[7];
	c->reg0 = c->raw1/16;
	c->reg1 = c->raw1%16;
}

/* Deal with 1OPI */
void decode_1OPI(struct Instruction* c)
{
	c->raw_Immediate = c->raw2*0x100 + c->raw3;
	c->Immediate[0] = c->operation[4];
	c->Immediate[1] = c->operation[5];
	c->Immediate[2] = c->operation[6];
	c->Immediate[3] = c->operation[7];
	c->HAL_CODE = 0;
	c->raw_XOP = c->raw1/16;
	c->XOP[0] = c->operation[2];
	c->reg0 = c->raw1%16;
}
/* Deal with 0OPI */
void decode_0OPI(struct Instruction* c)
{
	c->raw_Immediate = c->raw2*0x100 + c->raw3;
	c->Immediate[0] = c->operation[4];
	c->Immediate[1] = c->operation[5];
	c->Immediate[2] = c->operation[6];
	c->Immediate[3] = c->operation[7];
	c->HAL_CODE = 0;
	c->raw_XOP = c->raw1;
	c->XOP[0] = c->operation[2];
	c->XOP[1] = c->operation[3];
}

/* Deal with Halcode */
void decode_HALCODE(struct Instruction* c)
{
	c->HAL_CODE = c->raw1*0x10000 + c->raw2*0x100 + c->raw3;
}

/* Useful unpacking functions */
void unpack_byte(uint8_t a, char* c)
{
	char table[16] = {0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46};
	c[0] = table[a / 16];
	c[1] = table[a % 16];
}

/* Unpack the full instruction */
void unpack_instruction(struct Instruction* c)
{
	unpack_byte(c->raw0, &(c->operation[0]));
	unpack_byte(c->raw1, &(c->operation[2]));
	unpack_byte(c->raw2, &(c->operation[4]));
	unpack_byte(c->raw3, &(c->operation[6]));
	c->opcode[0] = c->operation[0];
	c->opcode[1] = c->operation[1];
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
		case 0x100000: /* fopen_read */
		{
			#ifdef DEBUG
			strncpy(Name, "FOPEN_READ", 19);
			#endif

			vm_FOPEN_READ(vm);
			break;
		}
		case 0x100001: /* fopen_write */
		{
			#ifdef DEBUG
			strncpy(Name, "FOPEN_WRITE", 19);
			#endif

			vm_FOPEN_WRITE(vm);
			break;
		}
		case 0x100002: /* fclose */
		{
			#ifdef DEBUG
			strncpy(Name, "FCLOSE", 19);
			#endif

			vm_FCLOSE(vm);
			break;
		}
		case 0x100003: /* rewind */
		{
			#ifdef DEBUG
			strncpy(Name, "REWIND", 19);
			#endif

			vm_REWIND(vm);
			break;
		}
		case 0x100004: /* fseek */
		{
			#ifdef DEBUG
			strncpy(Name, "FSEEK", 19);
			#endif

			vm_FSEEK(vm);
			break;
		}
		case 0x100100: /* fgetc */
		{
			#ifdef DEBUG
			strncpy(Name, "FGETC", 19);
			#endif

			vm_FGETC(vm);
			break;
		}
		case 0x100200: /* fputc */
		{
			#ifdef DEBUG
			strncpy(Name, "FPUTC", 19);
			#endif

			vm_FPUTC(vm);
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
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_4OP";
	#endif

	switch(c->raw_XOP)
	{
		case 0x00: /* ADD.CI */
		{
			#ifdef DEBUG
			strncpy(Name, "ADD.CI", 19);
			#endif

			ADD_CI(vm, c);
			break;
		}
		case 0x01: /* ADD.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "ADD.CO", 19);
			#endif

			ADD_CO(vm, c);
			break;
		}
		case 0x02: /* ADD.CIO */
		{
			#ifdef DEBUG
			strncpy(Name, "ADD.CIO", 19);
			#endif

			ADD_CIO(vm, c);
			break;
		}
		case 0x03: /* ADDU.CI */
		{
			#ifdef DEBUG
			strncpy(Name, "ADDU.CI", 19);
			#endif

			ADDU_CI(vm, c);
			break;
		}
		case 0x04: /* ADDU.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "ADDU.CO", 19);
			#endif

			ADDU_CO(vm, c);
			break;
		}
		case 0x05: /* ADDU.CIO */
		{
			#ifdef DEBUG
			strncpy(Name, "ADDU.CIO", 19);
			#endif

			ADDU_CIO(vm, c);
			break;
		}
		case 0x06: /* SUB.BI */
		{
			#ifdef DEBUG
			strncpy(Name, "SUB.BI", 19);
			#endif

			SUB_BI(vm, c);
			break;
		}
		case 0x07: /* SUB.BO */
		{
			#ifdef DEBUG
			strncpy(Name, "SUB.BO", 19);
			#endif

			SUB_BO(vm, c);
			break;
		}
		case 0x08: /* SUB.BIO */
		{
			#ifdef DEBUG
			strncpy(Name, "SUB.BIO", 19);
			#endif

			SUB_BIO(vm, c);
			break;
		}
		case 0x09: /* SUBU.BI */
		{
			#ifdef DEBUG
			strncpy(Name, "SUBU.BI", 19);
			#endif

			SUBU_BI(vm, c);
			break;
		}
		case 0x0A: /* SUBU.BO */
		{
			#ifdef DEBUG
			strncpy(Name, "SUBU.BO", 19);
			#endif

			SUBU_BO(vm, c);
			break;
		}
		case 0x0B: /* SUBU.BIO */
		{
			#ifdef DEBUG
			strncpy(Name, "SUBU.BIO", 19);
			#endif

			SUBU_BIO(vm, c);
			break;
		}
		case 0x0C: /* MULTIPLY */
		{
			#ifdef DEBUG
			strncpy(Name, "MULTIPLY", 19);
			#endif

			MULTIPLY(vm, c);
			break;
		}
		case 0x0D: /* MULTIPLYU */
		{
			#ifdef DEBUG
			strncpy(Name, "MULTIPLYU", 19);
			#endif

			MULTIPLYU(vm, c);
			break;
		}
		case 0x0E: /* DIVIDE */
		{
			#ifdef DEBUG
			strncpy(Name, "DIVIDE", 19);
			#endif

			DIVIDE(vm, c);
			break;
		}
		case 0x0F: /* DIVIDEU */
		{
			#ifdef DEBUG
			strncpy(Name, "DIVIDEU", 19);
			#endif

			DIVIDEU(vm, c);
			break;
		}
		case 0x10: /* MUX */
		{
			#ifdef DEBUG
			strncpy(Name, "MUX", 19);
			#endif

			MUX(vm, c);
			break;
		}
		case 0x11: /* NMUX */
		{
			#ifdef DEBUG
			strncpy(Name, "NMUX", 19);
			#endif

			NMUX(vm, c);
			break;
		}
		case 0x12: /* SORT */
		{
			#ifdef DEBUG
			strncpy(Name, "SORT", 19);
			#endif

			SORT(vm, c);
			break;
		}
		case 0x13: /* SORTU */
		{
			#ifdef DEBUG
			strncpy(Name, "SORTU", 19);
			#endif

			SORTU(vm, c);
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
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_3OP";
	#endif

	switch(c->raw_XOP)
	{
		case 0x000: /* ADD */
		{
			#ifdef DEBUG
			strncpy(Name, "ADD", 19);
			#endif

			ADD(vm, c);
			break;
		}
		case 0x001: /* ADDU */
		{
			#ifdef DEBUG
			strncpy(Name, "ADDU", 19);
			#endif

			ADDU(vm, c);
			break;
		}
		case 0x002: /* SUB */
		{
			#ifdef DEBUG
			strncpy(Name, "SUB", 19);
			#endif

			SUB(vm, c);
			break;
		}
		case 0x003: /* SUBU */
		{
			#ifdef DEBUG
			strncpy(Name, "SUBU", 19);
			#endif

			SUBU(vm, c);
			break;
		}
		case 0x004: /* CMP */
		{
			#ifdef DEBUG
			strncpy(Name, "CMP", 19);
			#endif

			CMP(vm, c);
			break;
		}
		case 0x005: /* CMPU */
		{
			#ifdef DEBUG
			strncpy(Name, "CMPU", 19);
			#endif

			CMPU(vm, c);
			break;
		}
		case 0x006: /* MUL */
		{
			#ifdef DEBUG
			strncpy(Name, "MUL", 19);
			#endif

			MUL(vm, c);
			break;
		}
		case 0x007: /* MULH */
		{
			#ifdef DEBUG
			strncpy(Name, "MULH", 19);
			#endif

			MULH(vm, c);
			break;
		}
		case 0x008: /* MULU */
		{
			#ifdef DEBUG
			strncpy(Name, "MULU", 19);
			#endif

			MULU(vm, c);
			break;
		}
		case 0x009: /* MULUH */
		{
			#ifdef DEBUG
			strncpy(Name, "MULUH", 19);
			#endif

			MULUH(vm, c);
			break;
		}
		case 0x00A: /* DIV */
		{
			#ifdef DEBUG
			strncpy(Name, "DIV", 19);
			#endif

			DIV(vm, c);
			break;
		}
		case 0x00B: /* MOD */
		{
			#ifdef DEBUG
			strncpy(Name, "MOD", 19);
			#endif

			MOD(vm, c);
			break;
		}
		case 0x00C: /* DIVU */
		{
			#ifdef DEBUG
			strncpy(Name, "DIVU", 19);
			#endif

			DIVU(vm, c);
			break;
		}
		case 0x00D: /* MODU */
		{
			#ifdef DEBUG
			strncpy(Name, "MODU", 19);
			#endif

			MODU(vm, c);
			break;
		}
		case 0x010: /* MAX */
		{
			#ifdef DEBUG
			strncpy(Name, "MAX", 19);
			#endif

			MAX(vm, c);
			break;
		}
		case 0x011: /* MAXU */
		{
			#ifdef DEBUG
			strncpy(Name, "MAXU", 19);
			#endif

			MAXU(vm, c);
			break;
		}
		case 0x012: /* MIN */
		{
			#ifdef DEBUG
			strncpy(Name, "MIN", 19);
			#endif

			MIN(vm, c);
			break;
		}
		case 0x013: /* MINU */
		{
			#ifdef DEBUG
			strncpy(Name, "MINU", 19);
			#endif

			MINU(vm, c);
			break;
		}
		case 0x014: /* PACK */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK", 19);
			#endif

			PACK(vm, c);
			break;
		}
		case 0x015: /* UNPACK */
		{
			#ifdef DEBUG
			strncpy(Name, "UNPACK", 19);
			#endif

			UNPACK(vm, c);
			break;
		}
		case 0x016: /* PACK8.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK8.CO", 19);
			#endif

			PACK8_CO(vm, c);
			break;
		}
		case 0x017: /* PACK8U.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK8U.CO", 19);
			#endif

			PACK8U_CO(vm, c);
			break;
		}
		case 0x018: /* PACK16.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK16.CO", 19);
			#endif

			PACK16_CO(vm, c);
			break;
		}
		case 0x019: /* PACK16U.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK16U.CO", 19);
			#endif

			PACK16U_CO(vm, c);
			break;
		}
		case 0x01A: /* PACK32.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK32.CO", 19);
			#endif

			PACK32_CO(vm, c);
			break;
		}
		case 0x01B: /* PACK32U.CO */
		{
			#ifdef DEBUG
			strncpy(Name, "PACK32U.CO", 19);
			#endif

			PACK32U_CO(vm, c);
			break;
		}
		case 0x020: /* AND */
		{
			#ifdef DEBUG
			strncpy(Name, "AND", 19);
			#endif

			AND(vm, c);
			break;
		}
		case 0x021: /* OR */
		{
			#ifdef DEBUG
			strncpy(Name, "OR", 19);
			#endif

			OR(vm, c);
			break;
		}
		case 0x022: /* XOR */
		{
			#ifdef DEBUG
			strncpy(Name, "XOR", 19);
			#endif

			XOR(vm, c);
			break;
		}
		case 0x023: /* NAND */
		{
			#ifdef DEBUG
			strncpy(Name, "NAND", 19);
			#endif

			NAND(vm, c);
			break;
		}
		case 0x024: /* NOR */
		{
			#ifdef DEBUG
			strncpy(Name, "NOR", 19);
			#endif

			NOR(vm, c);
			break;
		}
		case 0x025: /* XNOR */
		{
			#ifdef DEBUG
			strncpy(Name, "XNOR", 19);
			#endif

			XNOR(vm, c);
			break;
		}
		case 0x026: /* MPQ */
		{
			#ifdef DEBUG
			strncpy(Name, "MPQ", 19);
			#endif

			MPQ(vm, c);
			break;
		}
		case 0x027: /* LPQ */
		{
			#ifdef DEBUG
			strncpy(Name, "LPQ", 19);
			#endif

			LPQ(vm, c);
			break;
		}
		case 0x028: /* CPQ */
		{
			#ifdef DEBUG
			strncpy(Name, "CPQ", 19);
			#endif

			CPQ(vm, c);
			break;
		}
		case 0x029: /* BPQ */
		{
			#ifdef DEBUG
			strncpy(Name, "BPQ", 19);
			#endif

			BPQ(vm, c);
			break;
		}
		case 0x030: /* SAL */
		{
			#ifdef DEBUG
			strncpy(Name, "SAL", 19);
			#endif

			SAL(vm, c);
			break;
		}
		case 0x031: /* SAR */
		{
			#ifdef DEBUG
			strncpy(Name, "SAR", 19);
			#endif

			SAR(vm, c);
			break;
		}
		case 0x032: /* SL0 */
		{
			#ifdef DEBUG
			strncpy(Name, "SL0", 19);
			#endif

			SL0(vm, c);
			break;
		}
		case 0x033: /* SR0 */
		{
			#ifdef DEBUG
			strncpy(Name, "SR0", 19);
			#endif

			SR0(vm, c);
			break;
		}
		case 0x034: /* SL1 */
		{
			#ifdef DEBUG
			strncpy(Name, "SL1", 19);
			#endif

			SL1(vm, c);
			break;
		}
		case 0x035: /* SR1 */
		{
			#ifdef DEBUG
			strncpy(Name, "SR1", 19);
			#endif

			SR1(vm, c);
			break;
		}
		case 0x036: /* ROL */
		{
			#ifdef DEBUG
			strncpy(Name, "ROL", 19);
			#endif

			ROL(vm, c);
			break;
		}
		case 0x037: /* ROR */
		{
			#ifdef DEBUG
			strncpy(Name, "ROR", 19);
			#endif

			ROR(vm, c);
			break;
		}
		case 0x038: /* LOADX */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADX", 19);
			#endif

			LOADX(vm, c);
			break;
		}
		case 0x039: /* LOADX8 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADX8", 19);
			#endif

			LOADX8(vm, c);
			break;
		}
		case 0x03A: /* LOADXU8 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADXU8", 19);
			#endif

			LOADXU8(vm, c);
			break;
		}
		case 0x03B: /* LOADX16 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADX16", 19);
			#endif

			LOADX16(vm, c);
			break;
		}
		case 0x03C: /* LOADXU16 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADXU16", 19);
			#endif

			LOADXU16(vm, c);
			break;
		}
		case 0x03D: /* LOADX32 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADX32", 19);
			#endif

			LOADX32(vm, c);
			break;
		}
		case 0x03E: /* LOADXU32 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADXU32", 19);
			#endif

			LOADXU32(vm, c);
			break;
		}
		case 0x048: /* STOREX */
		{
			#ifdef DEBUG
			strncpy(Name, "STOREX", 19);
			#endif

			STOREX(vm, c);
			break;
		}
		case 0x049: /* STOREX8 */
		{
			#ifdef DEBUG
			strncpy(Name, "STOREX8", 19);
			#endif

			STOREX8(vm, c);
			break;
		}
		case 0x04A: /* STOREX16 */
		{
			#ifdef DEBUG
			strncpy(Name, "STOREX16", 19);
			#endif

			STOREX16(vm, c);
			break;
		}
		case 0x04B: /* STOREX32 */
		{
			#ifdef DEBUG
			strncpy(Name, "STOREX32", 19);
			#endif

			STOREX32(vm, c);
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

			NEG(vm, c);
			break;
		}
		case 0x0001: /* ABS */
		{
			#ifdef DEBUG
			strncpy(Name, "ABS", 19);
			#endif

			ABS(vm, c);
			break;
		}
		case 0x0002: /* NABS */
		{
			#ifdef DEBUG
			strncpy(Name, "NABS", 19);
			#endif

			NABS(vm, c);
			break;
		}
		case 0x0003: /* SWAP */
		{
			#ifdef DEBUG
			strncpy(Name, "SWAP", 19);
			#endif

			SWAP(vm, c);
			break;
		}
		case 0x0004: /* COPY */
		{
			#ifdef DEBUG
			strncpy(Name, "COPY", 19);
			#endif

			COPY(vm, c);
			break;
		}
		case 0x0005: /* MOVE */
		{
			#ifdef DEBUG
			strncpy(Name, "MOVE", 19);
			#endif

			MOVE(vm, c);
			break;
		}
		case 0x0100: /* BRANCH */
		{
			#ifdef DEBUG
			strncpy(Name, "BRANCH", 19);
			#endif

			BRANCH(vm, c);
			break;
		}
		case 0x0101: /* CALL */
		{
			#ifdef DEBUG
			strncpy(Name, "CALL", 19);
			#endif

			CALL(vm, c);
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

			READPC(vm, c);
			break;
		}
		case 0x00001: /* READSCID */
		{
			#ifdef DEBUG
			strncpy(Name, "READSCID", 19);
			#endif

			READSCID(vm, c);
			break;
		}
		case 0x00002: /* FALSE */
		{
			#ifdef DEBUG
			strncpy(Name, "FALSE", 19);
			#endif

			FALSE(vm, c);
			break;
		}
		case 0x00003: /* TRUE */
		{
			#ifdef DEBUG
			strncpy(Name, "TRUE", 19);
			#endif

			TRUE(vm, c);
			break;
		}
		case 0x01000: /* JSR_COROUTINE */
		{
			#ifdef DEBUG
			strncpy(Name, "JSR_COROUTINE", 19);
			#endif

			JSR_COROUTINE(vm, c);
			break;
		}
		case 0x01001: /* RET */
		{
			#ifdef DEBUG
			strncpy(Name, "RET", 19);
			#endif

			RET(vm, c);
			break;
		}
		case 0x02000: /* PUSHPC */
		{
			#ifdef DEBUG
			strncpy(Name, "PUSHPC", 19);
			#endif

			PUSHPC(vm, c);
			break;
		}
		case 0x02001: /* POPPC */
		{
			#ifdef DEBUG
			strncpy(Name, "POPPC", 19);
			#endif

			POPPC(vm, c);
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
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_2OPI";
	#endif

	/* 0x0E ... 0x2B */
	switch(c->raw0)
	{
		case 0x0E: /* ADDI */
		{
			#ifdef DEBUG
			strncpy(Name, "ADDI", 19);
			#endif

			ADDI(vm, c);
			break;
		}
		case 0x0F: /* ADDUI */
		{
			#ifdef DEBUG
			strncpy(Name, "ADDUI", 19);
			#endif

			ADDUI(vm, c);
			break;
		}
		case 0x10: /* SUBI */
		{
			#ifdef DEBUG
			strncpy(Name, "SUBI", 19);
			#endif

			SUBI(vm, c);
			break;
		}
		case 0x11: /* SUBUI */
		{
			#ifdef DEBUG
			strncpy(Name, "SUBUI", 19);
			#endif

			SUBUI(vm, c);
			break;
		}
		case 0x12: /* CMPI */
		{
			#ifdef DEBUG
			strncpy(Name, "CMPI", 19);
			#endif

			CMPI(vm, c);
			break;
		}
		case 0x13: /* LOAD */
		{
			#ifdef DEBUG
			strncpy(Name, "LOAD", 19);
			#endif

			LOAD(vm, c);
			break;
		}
		case 0x14: /* LOAD8 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOAD8", 19);
			#endif

			LOAD8(vm, c);
			break;
		}
		case 0x15: /* LOADU8 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADU8", 19);
			#endif

			LOADU8(vm, c);
			break;
		}
		case 0x16: /* LOAD16 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOAD16", 19);
			#endif

			LOAD16(vm, c);
			break;
		}
		case 0x17: /* LOADU16 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADU16", 19);
			#endif

			LOADU16(vm, c);
			break;
		}
		case 0x18: /* LOAD32 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOAD32", 19);
			#endif

			LOAD32(vm, c);
			break;
		}
		case 0x19: /* LOADU32 */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADU32", 19);
			#endif

			LOADU32(vm, c);
			break;
		}
		case 0x1F: /* CMPUI */
		{
			#ifdef DEBUG
			strncpy(Name, "CMPUI", 19);
			#endif

			CMPUI(vm, c);
			break;
		}
		case 0x20: /* STORE */
		{
			#ifdef DEBUG
			strncpy(Name, "STORE", 19);
			#endif

			STORE(vm, c);
			break;
		}
		case 0x21: /* STORE8 */
		{
			#ifdef DEBUG
			strncpy(Name, "STORE8", 19);
			#endif

			STORE8(vm, c);
			break;
		}
		case 0x22: /* STORE16 */
		{
			#ifdef DEBUG
			strncpy(Name, "STORE16", 19);
			#endif

			STORE16(vm, c);
			break;
		}
		case 0x23: /* STORE32 */
		{
			#ifdef DEBUG
			strncpy(Name, "STORE32", 19);
			#endif

			STORE32(vm, c);
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
	#ifdef DEBUG
	char Name[20] = "ILLEGAL_1OPI";
	#endif

	/* 0x2C */
	switch(c->raw_XOP)
	{
		case 0x0: /* JUMP.C */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.C", 19);
			#endif

			JUMP_C(vm, c);
			break;
		}
		case 0x1: /* JUMP.B */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.B", 19);
			#endif

			JUMP_B(vm, c);
			break;
		}
		case 0x2: /* JUMP.O */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.O", 19);
			#endif

			JUMP_O(vm, c);
			break;
		}
		case 0x3: /* JUMP.G */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.G", 19);
			#endif

			JUMP_G(vm, c);
			break;
		}
		case 0x4: /* JUMP.GE */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.GE", 19);
			#endif

			JUMP_GE(vm, c);
			break;
		}
		case 0x5: /* JUMP.E */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.E", 19);
			#endif

			JUMP_E(vm, c);
			break;
		}
		case 0x6: /* JUMP.NE */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.NE", 19);
			#endif

			JUMP_NE(vm, c);
			break;
		}
		case 0x7: /* JUMP.LE */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.LE", 19);
			#endif

			JUMP_LE(vm, c);
			break;
		}
		case 0x8: /* JUMP.L */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.L", 19);
			#endif

			JUMP_L(vm, c);
			break;
		}
		case 0x9: /* JUMP.Z */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.Z", 19);
			#endif

			JUMP_Z(vm, c);
			break;
		}
		case 0xA: /* JUMP.NZ */
		{
			#ifdef DEBUG
			strncpy(Name, "JUMP.NZ", 19);
			#endif

			JUMP_NZ(vm, c);
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

			CALLI(vm, c);
			break;
		}
		case 0x1: /* LOADI */
		{
			#ifdef DEBUG
			strncpy(Name, "LOADI", 19);
			#endif

			LOADI(vm, c);
			break;
		}
		case 0x2: /* LOADUI*/
		{
			#ifdef DEBUG
			strncpy(Name, "LOADUI", 19);
			#endif

			LOADUI(vm, c);
			break;
		}
		case 0x3: /* SALI */
		{
			#ifdef DEBUG
			strncpy(Name, "SALI", 19);
			#endif

			SALI(vm, c);
			break;
		}
		case 0x4: /* SARI */
		{
			#ifdef DEBUG
			strncpy(Name, "SARI", 19);
			#endif

			SARI(vm, c);
			break;
		}
		case 0x5: /* SL0I */
		{
			#ifdef DEBUG
			strncpy(Name, "SL0I", 19);
			#endif

			SL0I(vm, c);
			break;
		}
		case 0x6: /* SR0I */
		{
			#ifdef DEBUG
			strncpy(Name, "SR0I", 19);
			#endif

			SR0I(vm, c);
			break;
		}
		case 0x7: /* SL1I */
		{
			#ifdef DEBUG
			strncpy(Name, "SL1I", 19);
			#endif

			SL1I(vm, c);
			break;
		}
		case 0x8: /* SR1I */
		{
			#ifdef DEBUG
			strncpy(Name, "SR1I", 19);
			#endif

			SR1I(vm, c);
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

			JUMP(vm, c);
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
		case 0x01: /* Integer 4OP */
		{
			decode_4OP(current);
			invalid = eval_4OP_Int(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x05: /* Integer 3OP */
		{
			decode_3OP(current);
			invalid = eval_3OP_Int(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x09: /* Integer 2OP */
		{
			decode_2OP(current);
			invalid = eval_2OP_Int(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x0D: /* Integer 1OP */
		{
			decode_1OP(current);
			invalid = eval_1OP_Int(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x0E ... 0x2B: /* Integer 2OPI */
		{
			decode_2OPI(current);
			invalid = eval_2OPI_Int(vm, current);
			if ( invalid) goto fail;
			break;
		}
		case 0x2C: /* Integer 1OPI */
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
		case 0x3C: /* Integer 0OPI */
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
