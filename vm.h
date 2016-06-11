#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* Virtual machine state */
struct lilith
{
	uint8_t *memory;
	uint32_t reg[16];
	uint32_t ip;
	bool halted;
	bool exception;
};

/* Unpacked instruction */
struct Instruction
{
	uint32_t ip;
	uint8_t raw0, raw1, raw2, raw3;
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

/* Condition Codes */
enum condition
{
Carry = (1 << 5),
Borrow = (1 << 4),
Overflow = (1 << 3),
GreaterThan = (1 << 2),
EQual = (1 << 1),
LessThan = 1
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

/* Correctly write out bytes on little endian hardware */
void writeout_Reg(struct lilith* vm, uint32_t p, uint32_t value)
{
	uint8_t raw0, raw1, raw2, raw3;
	uint32_t tmp = value;
	raw3 = tmp%0x100;
	tmp = tmp/0x100;
	raw2 = tmp%0x100;
	tmp = tmp/0x100;
	raw1 = tmp%0x100;
	tmp = tmp/0x100;
	raw0 = tmp%0x100;

	vm->memory[p] = raw0;
	vm->memory[p + 1] = raw1;
	vm->memory[p + 2] = raw2;
	vm->memory[p + 3] = raw3;
}

/* Allow the use of native data format for Register operations */
uint32_t readin_Reg(struct lilith* vm, uint32_t p)
{
	uint8_t raw0, raw1, raw2, raw3;
	uint32_t sum;
	raw0 = vm->memory[p];
	raw1 = vm->memory[p + 1];
	raw2 = vm->memory[p + 2];
	raw3 = vm->memory[p + 3];

	sum = raw0*0x1000000 +
		  raw1*0x10000 +
		  raw2*0x100 +
		  raw3;

	return sum;
}

/* Unify byte write functionality */
void writeout_byte(struct lilith* vm, uint32_t p, uint32_t value)
{
	vm->memory[p] = (uint8_t)(value%0x100);
}

/* Unify byte read functionality*/
uint32_t readin_byte(struct lilith* vm, uint32_t p, bool Signed)
{
	if(Signed)
	{
		int32_t raw0;
		raw0 = (int8_t)(vm->memory[p]);
		return (uint32_t)(raw0);
	}

	return (uint32_t)(vm->memory[p]);
}

/* Unify doublebyte write functionality */
void writeout_doublebyte(struct lilith* vm, uint32_t p, uint32_t value)
{
	uint8_t uraw0, uraw1;
	uint32_t utmp = value;
	utmp = utmp/0x10000;
	uraw1 = utmp%0x100;
	utmp = utmp/0x100;
	uraw0 = utmp%0x100;

	vm->memory[p] = uraw0;
	vm->memory[p + 1] = uraw1;
}

/* Unify doublebyte read functionality*/
uint32_t readin_doublebyte(struct lilith* vm, uint32_t p, bool Signed)
{
	if(Signed)
	{
		int8_t raw0, raw1;
		int32_t sum;
		raw0 = vm->memory[p];
		raw1 = vm->memory[p + 1];

		sum = raw0*0x100 + raw1;
		return (uint32_t)(sum);
	}

	uint8_t uraw0, uraw1;
	uint32_t usum;
	uraw0 = vm->memory[p];
	uraw1 = vm->memory[p + 1];

	usum = uraw0*0x100 + uraw1;
	return usum;
}

/* Determine the result of bit shifting */
uint32_t shift_register(uint32_t source, uint32_t amount, bool left, bool zero)
{
	uint32_t tmp = source;

	if(left)
	{
		while( amount > 0 )
		{
			tmp = tmp * 2;
			amount = amount - 1;
			if(!zero)
			{
				tmp = tmp + 1;
			}
		}
	}
	else
	{
		while( amount > 0 )
		{
			tmp = tmp / 2;
			amount = amount - 1;
			if(!zero)
			{
				tmp = tmp | (1 << 31);
			}
		}
	}

	return tmp;
}
