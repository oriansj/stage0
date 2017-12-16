/* Copyright (C) 2016 Jeremiah Orians
 * This file is part of stage0.
 *
 * stage0 is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * stage0 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with stage0.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "vm.h"
#include <sys/stat.h>
FILE* tape_01;
FILE* tape_02;

#ifdef tty_lib
char tty_getchar();
#endif

/* Stub as the current specification makes all instructions 4 bytes but future enhancements may change that */
int next_instruction_size(struct lilith* vm)
{
	return 4;
}

/* Correctly write out bytes on little endian hardware */
void writeout_Reg(struct lilith* vm, unsigned_vm_register p, unsigned_vm_register value)
{
	uint8_t raw0, raw1, raw2, raw3;
	unsigned_vm_register tmp = value;
	raw3 = tmp%0x100;
	tmp = tmp/0x100;
	raw2 = tmp%0x100;
	tmp = tmp/0x100;
	raw1 = tmp%0x100;
	tmp = tmp/0x100;
	raw0 = tmp%0x100;

	outside_of_world(vm, p, "Writeout Reg Address is outside of World");

	vm->memory[p] = raw0;
	vm->memory[p + 1] = raw1;
	vm->memory[p + 2] = raw2;
	vm->memory[p + 3] = raw3;
}

/* Allow the use of native data format for Register operations */
unsigned_vm_register readin_Reg(struct lilith* vm, unsigned_vm_register p)
{
	outside_of_world(vm, p, "READIN REG Address is outside of World");

	uint8_t raw0, raw1, raw2, raw3;
	unsigned_vm_register sum;
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
void writeout_byte(struct lilith* vm, unsigned_vm_register p, unsigned_vm_register value)
{
	outside_of_world(vm, p, "Write Byte Address is outside of World");
	vm->memory[p] = (uint8_t)(value%0x100);
}

/* Unify byte read functionality*/
unsigned_vm_register readin_byte(struct lilith* vm, unsigned_vm_register p, bool Signed)
{
	outside_of_world(vm, p, "Read Byte Address is outside of World");
	if(Signed)
	{
		signed_vm_register raw0;
		raw0 = (int8_t)(vm->memory[p]);
		return (unsigned_vm_register)(raw0);
	}

	return (unsigned_vm_register)(vm->memory[p]);
}

/* Unify doublebyte write functionality */
void writeout_doublebyte(struct lilith* vm, unsigned_vm_register p, unsigned_vm_register value)
{
	uint8_t uraw0, uraw1;
	unsigned_vm_register utmp = value;
	utmp = utmp%0x10000;
	uraw1 = utmp%0x100;
	utmp = utmp/0x100;
	uraw0 = utmp%0x100;

	outside_of_world(vm, p, "Write DoubleByte Address is outside of World");

	vm->memory[p] = uraw0;
	vm->memory[p + 1] = uraw1;
}

/* Unify doublebyte read functionality*/
unsigned_vm_register readin_doublebyte(struct lilith* vm, unsigned_vm_register p, bool Signed)
{
	outside_of_world(vm, p, "Read Doublebyte Address is outside of World");

	if(Signed)
	{
		int8_t raw0, raw1;
		signed_vm_register sum;
		raw0 = vm->memory[p];
		raw1 = vm->memory[p + 1];

		sum = raw0*0x100 + raw1;
		return (unsigned_vm_register)(sum);
	}

	uint8_t uraw0, uraw1;
	unsigned_vm_register usum;
	uraw0 = vm->memory[p];
	uraw1 = vm->memory[p + 1];

	usum = uraw0*0x100 + uraw1;
	return usum;
}

/* Determine the result of bit shifting */
unsigned_vm_register shift_register(unsigned_vm_register source, unsigned_vm_register amount, bool left, bool zero)
{
	unsigned_vm_register tmp = source;

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
				tmp = tmp | (1 << imax);
			}
		}
	}

	return tmp;
}

void vm_FOPEN_READ(struct lilith* vm)
{
	struct stat sb;

	if(0x00001100 == vm->reg[0])
	{
		if(-1 == stat(tape_01_name, &sb))
		{
			fprintf(stderr, "File named %s does not exist\n", tape_01_name);
			exit(EXIT_FAILURE);
		}
		tape_01 = fopen(tape_01_name, "r");
	}

	if (0x00001101 == vm->reg[0])
	{
			if(-1 == stat(tape_02_name, &sb))
		{
			fprintf(stderr, "File named %s does not exist\n", tape_02_name);
			exit(EXIT_FAILURE);
		}
		tape_02 = fopen(tape_02_name, "r");
	}
}

void vm_FOPEN_WRITE(struct lilith* vm)
{
	if(0x00001100 == vm->reg[0])
	{
		tape_01 = fopen(tape_01_name, "w");
	}

	if (0x00001101 == vm->reg[0])
	{
		tape_02 = fopen(tape_02_name, "w");
	}
}

void vm_FCLOSE(struct lilith* vm)
{
	if(0x00001100 == vm->reg[0])
	{
		fclose(tape_01);
	}

	if (0x00001101 == vm->reg[0])
	{
		fclose(tape_02);
	}
}

void vm_FSEEK(struct lilith* vm)
{
	if(0x00001100 == vm->reg[0])
	{
		fseek(tape_01, vm->reg[1], SEEK_CUR);
	}

	if (0x00001101 == vm->reg[0])
	{
		fseek(tape_02, vm->reg[1], SEEK_CUR);
	}
}

void vm_REWIND(struct lilith* vm)
{
	if(0x00001100 == vm->reg[0])
	{
		rewind(tape_01);
	}

	if (0x00001101 == vm->reg[0])
	{
		rewind(tape_02);
	}
}

void vm_FGETC(struct lilith* vm)
{
	signed_vm_register byte = -1;

	if (0x00000000 == vm->reg[1])
	{
		#ifdef tty_lib
		byte = tty_getchar();
		#endif
		#ifndef tty_lib
		byte = fgetc(stdin);
		#endif
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
}

void vm_FPUTC(struct lilith* vm)
{
	signed_vm_register byte = vm->reg[0];

	if (0x00000000 == vm->reg[1])
	{
		fputc(byte, stdout);
		#ifdef tty_lib
		fflush(stdout);
		#endif
	}

	if(0x00001100 == vm->reg[1])
	{
		fputc(byte, tape_01);
	}

	if (0x00001101 == vm->reg[1])
	{
		fputc(byte, tape_02);
	}
}

void vm_HAL_MEM(struct lilith* vm)
{
	vm->reg[0] = vm->amount_of_Ram;
}


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

bool Carry_bit_set(unsigned_vm_register a)
{
	return a & Carry;
}

bool Borrow_bit_set(unsigned_vm_register a)
{
	return a & Borrow;
}

bool Overflow_bit_set(unsigned_vm_register a)
{
	return a & Overflow;
}

bool GreaterThan_bit_set(unsigned_vm_register a)
{
	return a & GreaterThan;
}

bool EQual_bit_set(unsigned_vm_register a)
{
	return a & EQual;
}

bool LessThan_bit_set(unsigned_vm_register a)
{
	return a & LessThan;
}

void ADD_CI(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	/* If carry bit set add in the carry */
	if(Carry_bit_set(vm->reg[c->reg3]))
	{
		vm->reg[c->reg0] = tmp1 + tmp2 + 1;
	}
	else
	{
		vm->reg[c->reg0] = tmp1 + tmp2;
	}
}

void ADD_CO(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	signed_wide_register btmp1;
	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);
	btmp1 = ((signed_wide_register)tmp1) + ((signed_wide_register)tmp2);

	/* If addition exceeds int32_t MAX, set carry bit */
	if(1 == ( btmp1 >> imax ))
	{
		vm->reg[c->reg3] = vm->reg[c->reg3] | Carry;
	}
	else
	{
		vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Carry);
	}

	/* Standard addition */
	vm->reg[c->reg0] = (tmp1 + tmp2);
}

void ADD_CIO(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	signed_wide_register btmp1;
	bool C = Carry_bit_set(vm->reg[c->reg3]);

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);
	btmp1 = ((signed_wide_register)tmp1) + ((signed_wide_register)tmp2);

	/* If addition exceeds int32_t MAX, set carry bit */
	if(1 == ( btmp1 >> imax ))
	{
		vm->reg[c->reg3] = vm->reg[c->reg3] | Carry;
	}
	else
	{
		vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Carry);
	}

	/* If carry bit set before operation add in the carry */
	if(C)
	{
		vm->reg[c->reg0] = tmp1 + tmp2 + 1;
	}
	else
	{
		vm->reg[c->reg0] = tmp1 + tmp2;
	}
}

void ADDU_CI(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register utmp1, utmp2;

	utmp1 = vm->reg[c->reg1];
	utmp2 = vm->reg[c->reg2];

	/* If carry bit set add in the carry */
	if(Carry_bit_set(vm->reg[c->reg3]))
	{
		vm->reg[c->reg0] = utmp1 + utmp2 + 1;
	}
	else
	{
		vm->reg[c->reg0] = utmp1 + utmp2;
	}
}

void ADDU_CO(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register utmp1, utmp2;
	unsigned_wide_register ubtmp1;

	utmp1 = vm->reg[c->reg1];
	utmp2 = vm->reg[c->reg2];
	ubtmp1 = ((unsigned_wide_register)utmp1) + ((unsigned_wide_register)utmp2);

	/* If addition exceeds uint32_t MAX, set carry bit */
	if(0 != ( ubtmp1 >> umax ))
	{
		vm->reg[c->reg3] = vm->reg[c->reg3] | Carry;
	}
	else
	{
		vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Carry);
	}

	/* Standard addition */
	vm->reg[c->reg0] = (utmp1 + utmp2);
}

void ADDU_CIO(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register utmp1, utmp2;
	unsigned_wide_register ubtmp1;
	bool C;

	C = Carry_bit_set(vm->reg[c->reg3]);
	utmp1 = vm->reg[c->reg1];
	utmp2 = vm->reg[c->reg2];
	ubtmp1 = ((unsigned_wide_register)utmp1) + ((unsigned_wide_register)utmp2);

	/* If addition exceeds uint32_t MAX, set carry bit */
	if(0 != ( ubtmp1 >> umax ))
	{
		vm->reg[c->reg3] = vm->reg[c->reg3] | Carry;
	}
	else
	{
		vm->reg[c->reg3] = vm->reg[c->reg3] & ~(Carry);
	}

	/* If carry bit was set before operation add in the carry */
	if(C)
	{
		vm->reg[c->reg0] = utmp1 + utmp2 + 1;
	}
	else
	{
		vm->reg[c->reg0] = utmp1 + utmp2;
	}
}

void SUB_BI(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	/* If borrow bit set subtract out the borrow */
	if(Borrow_bit_set(vm->reg[c->reg3]))
	{
		vm->reg[c->reg0] = tmp1 - tmp2 - 1;
	}
	else
	{
		vm->reg[c->reg0] = tmp1 - tmp2;
	}
}

void SUB_BO(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	signed_wide_register btmp1;

	btmp1 = (signed_wide_register)(vm->reg[c->reg1]);
	tmp1 = (signed_vm_register)(vm->reg[c->reg2]);
	tmp2 = (signed_vm_register)(btmp1 - tmp1);

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
}

void SUB_BIO(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	signed_wide_register btmp1;
	bool B;

	B = Borrow_bit_set(vm->reg[c->reg3]);
	btmp1 = (signed_wide_register)(vm->reg[c->reg1]);
	tmp1 = (signed_vm_register)(vm->reg[c->reg2]);
	tmp2 = (signed_vm_register)(btmp1 - tmp1);

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
	if(B)
	{
		vm->reg[c->reg0] = tmp2 - 1;
	}
	else
	{
		vm->reg[c->reg0] = tmp2;
	}
}

void SUBU_BI(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register utmp1, utmp2;

	utmp1 = vm->reg[c->reg1];
	utmp2 = vm->reg[c->reg2];

	/* If borrow bit set subtract out the borrow */
	if(Borrow_bit_set(vm->reg[c->reg3]))
	{
		vm->reg[c->reg0] = utmp1 - utmp2 - 1;
	}
	else
	{
		vm->reg[c->reg0] = utmp1 - utmp2;
	}
}

void SUBU_BO(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register utmp1, utmp2;
	unsigned_wide_register ubtmp1;

	utmp1 = vm->reg[c->reg1];
	utmp2 = vm->reg[c->reg2];
	ubtmp1 = (unsigned_wide_register)(utmp1 - utmp2);

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
}

void SUBU_BIO(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register utmp1, utmp2;
	unsigned_wide_register ubtmp1;
	bool B;

	B = Borrow_bit_set(vm->reg[c->reg3]);
	utmp1 = vm->reg[c->reg1];
	utmp2 = vm->reg[c->reg2];
	ubtmp1 = (unsigned_wide_register)(utmp1 - utmp2);

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
	if(B)
	{
		vm->reg[c->reg0] = utmp1 - utmp2 - 1;
	}
	else
	{
		vm->reg[c->reg0] = utmp1 - utmp2;
	}
}

void MULTIPLY(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	signed_wide_register btmp1;

	tmp1 = (signed_vm_register)(vm->reg[c->reg2]);
	tmp2 = (signed_vm_register)( vm->reg[c->reg3]);
	btmp1 = ((signed_wide_register)tmp1) * ((signed_wide_register)tmp2);
	vm->reg[c->reg0] = (signed_vm_register)(btmp1 % 0x100000000);
	vm->reg[c->reg1] = (signed_vm_register)(btmp1 / 0x100000000);
}

void MULTIPLYU(struct lilith* vm, struct Instruction* c)
{
	unsigned_wide_register ubtmp1;

	ubtmp1 = (unsigned_wide_register)(vm->reg[c->reg2]) * (unsigned_wide_register)(vm->reg[c->reg3]);
	vm->reg[c->reg0] = ubtmp1 % 0x100000000;
	vm->reg[c->reg1] = ubtmp1 / 0x100000000;
}

void DIVIDE(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg2]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg3]);
	vm->reg[c->reg0] = tmp1 / tmp2;
	vm->reg[c->reg1] = tmp1 % tmp2;
}

void DIVIDEU(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register utmp1, utmp2;

	utmp1 = vm->reg[c->reg2];
	utmp2 = vm->reg[c->reg3];
	vm->reg[c->reg0] = utmp1 / utmp2;
	vm->reg[c->reg1] = utmp1 % utmp2;
}

void MUX(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ((vm->reg[c->reg2] & ~(vm->reg[c->reg1])) |
						(vm->reg[c->reg3] & vm->reg[c->reg1]));
}

void NMUX(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ((vm->reg[c->reg2] & vm->reg[c->reg1]) |
						(vm->reg[c->reg3] & ~(vm->reg[c->reg1])));
}

void SORT(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg2]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg3]);

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
}

void SORTU(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register utmp1, utmp2;

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
}

void ADD(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	vm->reg[c->reg0] = (signed_vm_register)(tmp1 + tmp2);
}

void ADDU(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] + vm->reg[c->reg2];
}

void SUB(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	vm->reg[c->reg0] = (signed_vm_register)(tmp1 - tmp2);
}

void SUBU(struct lilith* vm, struct Instruction* c)
{
		vm->reg[c->reg0] = vm->reg[c->reg1] - vm->reg[c->reg2];
}

void CMP(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	unsigned_vm_register result = 0;

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	/* Set condition bits accordingly*/
	if(tmp1 > tmp2)
	{
		vm->reg[c->reg0] = result | GreaterThan;
	}
	else if(tmp1 == tmp2)
	{
		vm->reg[c->reg0] = result | EQual;
	}
	else
	{
		vm->reg[c->reg0] = result | LessThan;
	}
}

void CMPU(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register result = 0;

	if(vm->reg[c->reg1] > vm->reg[c->reg2])
	{
		vm->reg[c->reg0] = result | GreaterThan;
	}
	else if(vm->reg[c->reg1] == vm->reg[c->reg2])
	{
		vm->reg[c->reg0] = result | EQual;
	}
	else
	{
		vm->reg[c->reg0] = result | LessThan;
	}
}

void MUL(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	signed_wide_register sum = tmp1 * tmp2;

	/* We only want the bottom 32bits */
	vm->reg[c->reg0] = sum % 0x100000000;
}

void MULH(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	signed_wide_register sum = tmp1 * tmp2;

	/* We only want the top 32bits */
	vm->reg[c->reg0] = sum / 0x100000000;
}

void MULU(struct lilith* vm, struct Instruction* c)
{
	unsigned_wide_register tmp1, tmp2, sum;

	tmp1 = vm->reg[c->reg1];
	tmp2 = vm->reg[c->reg2];
	sum = tmp1 * tmp2;

		/* We only want the bottom 32bits */
		vm->reg[c->reg0] = sum % 0x100000000;
}

void MULUH(struct lilith* vm, struct Instruction* c)
{
	unsigned_wide_register tmp1, tmp2, sum;

	tmp1 = vm->reg[c->reg1];
	tmp2 = vm->reg[c->reg2];
	sum = tmp1 * tmp2;

		/* We only want the top 32bits */
		vm->reg[c->reg0] = sum / 0x100000000;
}

void DIV(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	vm->reg[c->reg0] = tmp1 / tmp2;
}

void MOD(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	vm->reg[c->reg0] = tmp1 % tmp2;
}

void DIVU(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] / vm->reg[c->reg2];
}

void MODU(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] % vm->reg[c->reg2];
}

void MAX(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	if(tmp1 > tmp2)
	{
		vm->reg[c->reg0] = tmp1;
	}
	else
	{
		vm->reg[c->reg0] = tmp2;
	}
}

void MAXU(struct lilith* vm, struct Instruction* c)
{
	if(vm->reg[c->reg1] > vm->reg[c->reg2])
	{
		vm->reg[c->reg0] = vm->reg[c->reg1];
	}
	else
	{
		vm->reg[c->reg0] = vm->reg[c->reg2];
	}
}

void MIN(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;

	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg2]);

	if(tmp1 < tmp2)
	{
		vm->reg[c->reg0] = tmp1;
	}
	else
	{
		vm->reg[c->reg0] = tmp2;
	}
}

void MINU(struct lilith* vm, struct Instruction* c)
{
	if(vm->reg[c->reg1] < vm->reg[c->reg2])
	{
		vm->reg[c->reg0] = vm->reg[c->reg1];
	}
	else
	{
		vm->reg[c->reg0] = vm->reg[c->reg2];
	}
}

void AND(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] & vm->reg[c->reg2];
}

void OR(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] | vm->reg[c->reg2];
}

void XOR(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] ^ vm->reg[c->reg2];
}

void NAND(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ~(vm->reg[c->reg1] & vm->reg[c->reg2]);
}

void NOR(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ~(vm->reg[c->reg1] | vm->reg[c->reg2]);
}

void XNOR(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ~(vm->reg[c->reg1] ^ vm->reg[c->reg2]);
}

void MPQ(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ~(vm->reg[c->reg1]) & vm->reg[c->reg2];
}

void LPQ(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] & ~(vm->reg[c->reg2]);
}

void CPQ(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ~(vm->reg[c->reg1]) | vm->reg[c->reg2];
}

void BPQ(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] | ~(vm->reg[c->reg2]);
}

void SAL(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] << vm->reg[c->reg2];
}

void SAR(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] >> vm->reg[c->reg2];
}

void SL0(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], true, true);
}

void SR0(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], false, true);
}

void SL1(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], true, false);
}

void SR1(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = shift_register(vm->reg[c->reg1], vm->reg[c->reg2], false, false);
}

void ROL(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register i, tmp;
	bool bit;

	tmp = vm->reg[c->reg1];
	for(i = vm->reg[c->reg2]; i > 0; i = i - 1)
	{
		bit = (tmp & 1);
		tmp = (tmp / 2) + (bit << imax);
	}

	vm->reg[c->reg0] = tmp;
}

void ROR(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register i, tmp;
	bool bit;

	tmp = vm->reg[c->reg1];
	for(i = vm->reg[c->reg2]; i > 0; i = i - 1)
	{
		bit = ((tmp >> imax) & 1);
		tmp = (tmp * 2) + bit;
	}

	vm->reg[c->reg0] = tmp;
}

void LOADX(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2]);
}

void LOADX8(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_byte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], true);
}

void LOADXU8(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_byte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], false);
}

void LOADX16(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_doublebyte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], true);
}

void LOADXU16(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_doublebyte(vm, vm->reg[c->reg1] + vm->reg[c->reg2], false);
}

void LOADX32(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2]);
}

void LOADXU32(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2]);
}

void STOREX(struct lilith* vm, struct Instruction* c)
{
	writeout_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
}

void STOREX8(struct lilith* vm, struct Instruction* c)
{
	writeout_byte(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
}

void STOREX16(struct lilith* vm, struct Instruction* c)
{
	writeout_doublebyte(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
}

void STOREX32(struct lilith* vm, struct Instruction* c)
{
	writeout_Reg(vm, vm->reg[c->reg1] + vm->reg[c->reg2] , vm->reg[c->reg0]);
}

void NEG(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = (signed_vm_register)(vm->reg[c->reg1]) * -1;
}

void ABS(struct lilith* vm, struct Instruction* c)
{
	if(0 <= (signed_vm_register)(vm->reg[c->reg1]))
	{
		vm->reg[c->reg0] = vm->reg[c->reg1];
	}
	else
	{
		vm->reg[c->reg0] = (signed_vm_register)(vm->reg[c->reg1]) * -1;
	}
}

void NABS(struct lilith* vm, struct Instruction* c)
{
	if(0 > (signed_vm_register)(vm->reg[c->reg1]))
	{
		vm->reg[c->reg0] = vm->reg[c->reg1];
	}
	else
	{
		vm->reg[c->reg0] = (signed_vm_register)(vm->reg[c->reg1]) * -1;
	}
}

void SWAP(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register utmp1;

	utmp1 = vm->reg[c->reg1];
	vm->reg[c->reg1] = vm->reg[c->reg0];
	vm->reg[c->reg0] = utmp1;
}

void COPY(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1];
}

void MOVE(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1];
	vm->reg[c->reg1] = 0;
}

void BRANCH(struct lilith* vm, struct Instruction* c)
{
	/* Write out the PC */
	writeout_Reg(vm, vm->reg[c->reg1], vm->ip);

	/* Update PC */
	vm->ip = vm->reg[c->reg0];
}

void CALL(struct lilith* vm, struct Instruction* c)
{
	/* Write out the PC */
	writeout_Reg(vm, vm->reg[c->reg1], vm->ip);

	/* Update our index */
	vm->reg[c->reg1] = vm->reg[c->reg1] + reg_size;

	/* Update PC */
	vm->ip = vm->reg[c->reg0];
}

void READPC(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->ip;
}

void READSCID(struct lilith* vm, struct Instruction* c)
{
#ifdef VM256
	/* We only support Base 8, 16, 32, 64, 128 and 256 */
	vm->reg[c->reg0] = 0x00000005;
#elif VM128
	/* We only support Base 8, 16, 32, 64 and 128 */
	vm->reg[c->reg0] = 0x00000004;
#elif VM64
	/* We only support Base 8, 16, 32 and 64 */
	vm->reg[c->reg0] = 0x00000003;
#elif VM32
	/* We only support Base 8, 16 and 32 */
	vm->reg[c->reg0] = 0x00000002;
#else
	/* We only support Base 8 and 16 */
	vm->reg[c->reg0] = 0x00000001;
#endif
}

void FALSE(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = 0;
}

void TRUE(struct lilith* vm, struct Instruction* c)
{
#ifdef VM256
	vm->reg[c->reg0] = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
#elif VM128
	vm->reg[c->reg0] = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
#elif VM64
	vm->reg[c->reg0] = 0xFFFFFFFFFFFFFFFF;
#elif VM32
	vm->reg[c->reg0] = 0xFFFFFFFF;
#else
	vm->reg[c->reg0] = 0xFFFF;
#endif
}

void JSR_COROUTINE(struct lilith* vm, struct Instruction* c)
{
	vm->ip = vm->reg[c->reg0];
}

void RET(struct lilith* vm, struct Instruction* c)
{
	/* Update our index */
	vm->reg[c->reg0] = vm->reg[c->reg0] - reg_size;

	/* Read in the new PC */
	vm->ip = readin_Reg(vm, vm->reg[c->reg0]);

	/* Clear Stack Values */
	writeout_Reg(vm, vm->reg[c->reg0], 0);
}

void PUSHPC(struct lilith* vm, struct Instruction* c)
{
	/* Write out the PC */
	writeout_Reg(vm, vm->reg[c->reg0], vm->ip);

	/* Update our index */
	vm->reg[c->reg0] = vm->reg[c->reg0] + reg_size;
}

void POPPC(struct lilith* vm, struct Instruction* c)
{
	/* Update our index */
	vm->reg[c->reg0] = vm->reg[c->reg0] - reg_size;

	/* Read in the new PC */
	vm->ip = readin_Reg(vm, vm->reg[c->reg0]);

	/* Clear memory where PC was */
	writeout_Reg(vm, vm->reg[c->reg0], 0);
}

void ADDI(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1;
	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	vm->reg[c->reg0] = (signed_vm_register)(tmp1 + c->raw_Immediate);
}

void ADDUI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] + c->raw_Immediate;
}

void SUBI(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1;
	tmp1 = (signed_vm_register)(vm->reg[c->reg1]);
	vm->reg[c->reg0] = (signed_vm_register)(tmp1 - c->raw_Immediate);
}

void SUBUI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] - c->raw_Immediate;
}

void CMPI(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register result = 0;

	if((signed_vm_register)(vm->reg[c->reg1]) > c->raw_Immediate)
	{
		vm->reg[c->reg0] = result | GreaterThan;
	}
	else if((signed_vm_register)(vm->reg[c->reg1]) == c->raw_Immediate)
	{
		vm->reg[c->reg0] = result | EQual;
	}
	else
	{
		vm->reg[c->reg0] = result | LessThan;
	}
}

void LOAD(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_Reg(vm, (vm->reg[c->reg1] + c->raw_Immediate));
}

void LOAD8(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_byte(vm, vm->reg[c->reg1] + c->raw_Immediate, true);
}

void LOADU8(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_byte(vm, vm->reg[c->reg1] + c->raw_Immediate, false);
}

void LOAD16(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_doublebyte(vm, vm->reg[c->reg1] + c->raw_Immediate, true);
}

void LOADU16(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_doublebyte(vm, vm->reg[c->reg1] + c->raw_Immediate, false);
}

void LOAD32(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_Reg(vm, (vm->reg[c->reg1] + c->raw_Immediate));
}

void LOADU32(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_Reg(vm, (vm->reg[c->reg1] + c->raw_Immediate));
}

void CMPUI(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register result = 0;

	if(vm->reg[c->reg1] > (unsigned_vm_register)c->raw_Immediate)
	{
		vm->reg[c->reg0] = result | GreaterThan;
	}
	else if(vm->reg[c->reg1] == (unsigned_vm_register)c->raw_Immediate)
	{
		vm->reg[c->reg0] = result | EQual;
	}
	else
	{
		vm->reg[c->reg0] = result | LessThan;
	}
}

void STORE(struct lilith* vm, struct Instruction* c)
{
	writeout_Reg(vm, (vm->reg[c->reg1] + c->raw_Immediate), vm->reg[c->reg0]);
}

void STORE8(struct lilith* vm, struct Instruction* c)
{
	writeout_byte(vm, (vm->reg[c->reg1] + c->raw_Immediate), vm->reg[c->reg0]);
}

void STORE16(struct lilith* vm, struct Instruction* c)
{
	writeout_doublebyte(vm, (vm->reg[c->reg1] + c->raw_Immediate), vm->reg[c->reg0]);
}

void STORE32(struct lilith* vm, struct Instruction* c)
{
	writeout_Reg(vm, (vm->reg[c->reg1] + c->raw_Immediate), vm->reg[c->reg0]);
}

void JUMP_C(struct lilith* vm, struct Instruction* c)
{
	if(Carry_bit_set(vm->reg[c->reg0]))
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_B(struct lilith* vm, struct Instruction* c)
{
	if(Borrow_bit_set(vm->reg[c->reg0]))
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_O(struct lilith* vm, struct Instruction* c)
{
	if(Overflow_bit_set(vm->reg[c->reg0]))
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_G(struct lilith* vm, struct Instruction* c)
{
	if(GreaterThan_bit_set(vm->reg[c->reg0]))
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_GE(struct lilith* vm, struct Instruction* c)
{
	if(GreaterThan_bit_set(vm->reg[c->reg0]) || EQual_bit_set(vm->reg[c->reg0]))
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_E(struct lilith* vm, struct Instruction* c)
{
	if(EQual_bit_set(vm->reg[c->reg0]))
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_NE(struct lilith* vm, struct Instruction* c)
{
	if(!EQual_bit_set(vm->reg[c->reg0]))
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_LE(struct lilith* vm, struct Instruction* c)
{
	if(LessThan_bit_set(vm->reg[c->reg0]) || EQual_bit_set(vm->reg[c->reg0]))
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_L(struct lilith* vm, struct Instruction* c)
{
	if(LessThan_bit_set(vm->reg[c->reg0]))
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_Z(struct lilith* vm, struct Instruction* c)
{
	if(0 == vm->reg[c->reg0])
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_NZ(struct lilith* vm, struct Instruction* c)
{
	if(0 != vm->reg[c->reg0])
	{
		/* Adust the IP relative the the start of this instruction*/
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CALLI(struct lilith* vm, struct Instruction* c)
{
	/* Write out the PC */
	writeout_Reg(vm, vm->reg[c->reg0], vm->ip);

	/* Update our index */
	vm->reg[c->reg0] = vm->reg[c->reg0] + reg_size;

	/* Update PC */
	vm->ip = vm->ip + c->raw_Immediate - 4;
}

void LOADI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = (int16_t)c->raw_Immediate;
}

void LOADUI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = c->raw_Immediate;
}

void SALI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg0] << c->raw_Immediate;
}

void SARI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg0] >> c->raw_Immediate;
}

void SL0I(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, true, true);
}

void SR0I(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, false, true);
}

void SL1I(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, true, false);
}

void SR1I(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = shift_register(vm->reg[c->reg0], c->raw_Immediate, false, false);
}

void LOADR(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_Reg(vm, (vm->ip + c->raw_Immediate -4));
}
void LOADR8(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_byte(vm, (vm->ip + c->raw_Immediate -4), true);
}

void LOADRU8(struct lilith* vm, struct Instruction* c)
{
vm->reg[c->reg0] = readin_byte(vm, (vm->ip + c->raw_Immediate -4), false);
}

void LOADR16(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_doublebyte(vm, (vm->ip + c->raw_Immediate -4), true);
}

void LOADRU16(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_doublebyte(vm, (vm->ip + c->raw_Immediate -4), false);
}

void LOADR32(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_Reg(vm, (vm->ip + c->raw_Immediate -4));
}
void LOADRU32(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = readin_Reg(vm, (vm->ip + c->raw_Immediate -4));
}

void STORER(struct lilith* vm, struct Instruction* c)
{
	writeout_Reg(vm, (vm->ip + c->raw_Immediate - 4), vm->reg[c->reg0]);
}

void STORER8(struct lilith* vm, struct Instruction* c)
{
	writeout_byte(vm, (vm->ip + c->raw_Immediate - 4), vm->reg[c->reg0]);
}

void STORER16(struct lilith* vm, struct Instruction* c)
{
	writeout_doublebyte(vm, (vm->ip + c->raw_Immediate - 4), vm->reg[c->reg0]);
}

void STORER32(struct lilith* vm, struct Instruction* c)
{
	writeout_Reg(vm, (vm->ip + c->raw_Immediate - 4), vm->reg[c->reg0]);
}

void JUMP(struct lilith* vm, struct Instruction* c)
{
	vm->ip = vm->ip + c->raw_Immediate - 4;
}

void JUMP_P(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	if(0 <= tmp1)
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void JUMP_NP(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	if(0 > tmp1)
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPJUMPI_G(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);
	if(tmp1 > tmp2)
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPJUMPI_GE(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);
	if(tmp1 >= tmp2)
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPJUMPI_E(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) == (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPJUMPI_NE(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) != (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPJUMPI_LE(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);
	if(tmp1 <= tmp2)
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPJUMPI_L(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);
	if(tmp1 < tmp2)
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPJUMPUI_G(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) > (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPJUMPUI_GE(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) >= (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPJUMPUI_LE(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) <= (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPJUMPUI_L(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) < (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + c->raw_Immediate - 4;
	}
}

void CMPSKIPI_G(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(c->raw_Immediate);

	if(tmp1 > tmp2)
	{
		vm->ip = vm->ip + 4;
	}
}

void CMPSKIPI_GE(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(c->raw_Immediate);

	if(tmp1 >= tmp2)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPI_E(struct lilith* vm, struct Instruction* c)
{
	uint16_t utmp1;

	utmp1 = (uint16_t)(c->raw_Immediate);

	if((vm->reg[c->reg0]) == utmp1)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPI_NE(struct lilith* vm, struct Instruction* c)
{
	uint16_t utmp1;

	utmp1 = (uint16_t)(c->raw_Immediate);

	if((vm->reg[c->reg0]) != utmp1)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPI_LE(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(c->raw_Immediate);

	if(tmp1 <= tmp2)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPI_L(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(c->raw_Immediate);

	if(tmp1 < tmp2)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPUI_G(struct lilith* vm, struct Instruction* c)
{
	uint16_t utmp1;

	utmp1 = (uint16_t)(c->raw_Immediate);

	if((vm->reg[c->reg0]) > utmp1)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPUI_GE(struct lilith* vm, struct Instruction* c)
{
	uint16_t utmp1;

	utmp1 = (uint16_t)(c->raw_Immediate);

	if((vm->reg[c->reg0]) >= utmp1)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPUI_LE(struct lilith* vm, struct Instruction* c)
{
	uint16_t utmp1;

	utmp1 = (uint16_t)(c->raw_Immediate);

	if((vm->reg[c->reg0]) <= utmp1)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPUI_L(struct lilith* vm, struct Instruction* c)
{
	uint16_t utmp1;

	utmp1 = (uint16_t)(c->raw_Immediate);

	if((vm->reg[c->reg0]) < utmp1)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void PUSHR(struct lilith* vm, struct Instruction* c)
{
	writeout_Reg(vm, vm->reg[c->reg1], vm->reg[c->reg0]);
	vm->reg[c->reg1] = vm->reg[c->reg1] + next_instruction_size(vm);
}
void PUSH8(struct lilith* vm, struct Instruction* c)
{
	writeout_byte(vm, vm->reg[c->reg1] , vm->reg[c->reg0]);
	vm->reg[c->reg1] = vm->reg[c->reg1] + 1;
}
void PUSH16(struct lilith* vm, struct Instruction* c)
{
	writeout_doublebyte(vm, vm->reg[c->reg1] , vm->reg[c->reg0]);
	vm->reg[c->reg1] = vm->reg[c->reg1] + 2;
}
void PUSH32(struct lilith* vm, struct Instruction* c)
{
	writeout_Reg(vm, vm->reg[c->reg1] , vm->reg[c->reg0]);
	vm->reg[c->reg1] = vm->reg[c->reg1] + 4;
}
void POPR(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register tmp;
	vm->reg[c->reg1] = vm->reg[c->reg1] - reg_size;
	tmp = readin_Reg(vm, vm->reg[c->reg1]);
	writeout_Reg(vm, vm->reg[c->reg1], 0);
	vm->reg[c->reg0] = tmp;
}
void POP8(struct lilith* vm, struct Instruction* c)
{
	int8_t tmp;
	vm->reg[c->reg1] = vm->reg[c->reg1] - 1;
	tmp = readin_byte(vm, vm->reg[c->reg1], true);
	writeout_byte(vm, vm->reg[c->reg1], 0);
	vm->reg[c->reg0] = tmp;
}
void POPU8(struct lilith* vm, struct Instruction* c)
{
	uint8_t tmp;
	vm->reg[c->reg1] = vm->reg[c->reg1] - 1;
	tmp = readin_byte(vm, vm->reg[c->reg1], false);
	writeout_byte(vm, vm->reg[c->reg1], 0);
	vm->reg[c->reg0] = tmp;
}
void POP16(struct lilith* vm, struct Instruction* c)
{
	int16_t tmp;
	vm->reg[c->reg1] = vm->reg[c->reg1] - 2;
	tmp = readin_doublebyte(vm, vm->reg[c->reg1], true);
	writeout_doublebyte(vm, vm->reg[c->reg1], 0);
	vm->reg[c->reg0] = tmp;
}
void POPU16(struct lilith* vm, struct Instruction* c)
{
	uint16_t tmp;
	vm->reg[c->reg1] = vm->reg[c->reg1] - 2;
	tmp = readin_doublebyte(vm, vm->reg[c->reg1], false);
	writeout_doublebyte(vm, vm->reg[c->reg1], 0);
	vm->reg[c->reg0] = tmp;
}
void POP32(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp;
	vm->reg[c->reg1] = vm->reg[c->reg1] - 4;
	tmp = readin_Reg(vm, vm->reg[c->reg1]);
	writeout_Reg(vm, vm->reg[c->reg1], 0);
	vm->reg[c->reg0] = tmp;
}
void POPU32(struct lilith* vm, struct Instruction* c)
{
	unsigned_vm_register tmp;
	vm->reg[c->reg1] = vm->reg[c->reg1] - 4;
	tmp = readin_Reg(vm, vm->reg[c->reg1]);
	writeout_Reg(vm, vm->reg[c->reg1], 0);
	vm->reg[c->reg0] = tmp;
}

void ANDI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] & c->raw_Immediate;
}

void ORI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] | c->raw_Immediate;
}

void XORI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] ^ c->raw_Immediate;
}

void NANDI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ~(vm->reg[c->reg1] & c->raw_Immediate);
}

void NORI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ~(vm->reg[c->reg1] | c->raw_Immediate);
}

void XNORI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ~(vm->reg[c->reg1] ^ c->raw_Immediate);
}

void NOT(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = ~(vm->reg[c->reg1]);
}

void CMPSKIP_G(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);

	if(tmp1 > tmp2)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIP_GE(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);

	if(tmp1 >= tmp2)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIP_E(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) == (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIP_NE(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) != (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIP_LE(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);

	if(tmp1 <= tmp2)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIP_L(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);

	if(tmp1 < tmp2)
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPU_G(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) > (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPU_GE(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) >= (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPU_LE(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) <= (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPSKIPU_L(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) < (vm->reg[c->reg1]))
	{
		vm->ip = vm->ip + next_instruction_size(vm);
	}
}

void CMPJUMP_G(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);
	if(tmp1 > tmp2)
	{
		vm->ip = vm->reg[c->reg2];
	}
}

void CMPJUMP_GE(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);
	if(tmp1 >= tmp2)
	{
		vm->ip = vm->reg[c->reg2];
	}
}

void CMPJUMP_E(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) == (vm->reg[c->reg1]))
	{
		vm->ip = vm->reg[c->reg2];
	}
}

void CMPJUMP_NE(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) != (vm->reg[c->reg1]))
	{
		vm->ip = vm->reg[c->reg2];
	}
}

void CMPJUMP_LE(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);
	if(tmp1 <= tmp2)
	{
		vm->ip = vm->reg[c->reg2];
	}
}

void CMPJUMP_L(struct lilith* vm, struct Instruction* c)
{
	signed_vm_register tmp1, tmp2;
	tmp1 = (signed_vm_register)(vm->reg[c->reg0]);
	tmp2 = (signed_vm_register)(vm->reg[c->reg1]);
	if(tmp1 < tmp2)
	{
		vm->ip = vm->reg[c->reg2];
	}
}

void CMPJUMPU_G(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) > (vm->reg[c->reg1]))
	{
		vm->ip = vm->reg[c->reg2];
	}
}

void CMPJUMPU_GE(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) >= (vm->reg[c->reg1]))
	{
		vm->ip = vm->reg[c->reg2];
	}
}

void CMPJUMPU_LE(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) <= (vm->reg[c->reg1]))
	{
		vm->ip = vm->reg[c->reg2];
	}
}

void CMPJUMPU_L(struct lilith* vm, struct Instruction* c)
{
	if((vm->reg[c->reg0]) < (vm->reg[c->reg1]))
	{
		vm->ip = vm->reg[c->reg2];
	}
}
