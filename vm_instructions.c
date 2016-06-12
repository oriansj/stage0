#include "vm.h"
FILE* tape_01;
FILE* tape_02;

void vm_FOPEN(struct lilith* vm)
{
	if(0x00001100 == vm->reg[0])
	{
		tape_01 = fopen("tape_01", "r");
	}

	if (0x00001101 == vm->reg[0])
	{
		tape_02 = fopen("tape_02", "w");
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
}

void vm_FPUTC(struct lilith* vm)
{
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
}

bool Carry_bit_set(uint32_t a)
{
	return a & Carry;
}

bool Borrow_bit_set(uint32_t a)
{
	return a & Borrow;
}

bool Overflow_bit_set(uint32_t a)
{
	return a & Overflow;
}

bool GreaterThan_bit_set(uint32_t a)
{
	return a & GreaterThan;
}

bool EQual_bit_set(uint32_t a)
{
	return a & EQual;
}

bool LessThan_bit_set(uint32_t a)
{
	return a & LessThan;
}

void ADD_CI(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;
	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

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
	int32_t tmp1, tmp2;
	int64_t btmp1;
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
}

void ADD_CIO(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;
	int64_t btmp1;
	bool C = Carry_bit_set(vm->reg[c->reg3]);

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
	uint32_t utmp1, utmp2;

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
	uint32_t utmp1, utmp2;
	uint64_t ubtmp1;

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
}

void ADDU_CIO(struct lilith* vm, struct Instruction* c)
{
	uint32_t utmp1, utmp2;
	uint64_t ubtmp1;
	bool C;

	C = Carry_bit_set(vm->reg[c->reg3]);
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
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

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
	int32_t tmp1, tmp2;
	int64_t btmp1;

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
}

void SUB_BIO(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;
	int64_t btmp1;
	bool B;

	B = Borrow_bit_set(vm->reg[c->reg3]);
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
	uint32_t utmp1, utmp2;

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
	uint32_t utmp1, utmp2;
	uint64_t ubtmp1;

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
}

void SUBU_BIO(struct lilith* vm, struct Instruction* c)
{
	uint32_t utmp1, utmp2;
	uint64_t ubtmp1;
	bool B;

	B = Borrow_bit_set(vm->reg[c->reg3]);
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
	int32_t tmp1, tmp2;
	int64_t btmp1;

	tmp1 = (int32_t)(vm->reg[c->reg2]);
	tmp2 = (int32_t)( vm->reg[c->reg3]);
	btmp1 = ((int64_t)tmp1) * ((int64_t)tmp2);
	vm->reg[c->reg0] = (int32_t)(btmp1 % 0x100000000);
	vm->reg[c->reg1] = (int32_t)(btmp1 / 0x100000000);
}

void MULTIPLYU(struct lilith* vm, struct Instruction* c)
{
	uint64_t ubtmp1;

	ubtmp1 = (uint64_t)(vm->reg[c->reg2]) * (uint64_t)(vm->reg[c->reg3]);
	vm->reg[c->reg0] = ubtmp1 % 0x100000000;
	vm->reg[c->reg1] = ubtmp1 / 0x100000000;
}

void DIVIDE(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg2]);
	tmp2 = (int32_t)(vm->reg[c->reg3]);
	vm->reg[c->reg0] = tmp1 / tmp2;
	vm->reg[c->reg1] = tmp1 % tmp2;
}

void DIVIDEU(struct lilith* vm, struct Instruction* c)
{
	uint32_t utmp1, utmp2;

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
	int32_t tmp1, tmp2;

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
}

void SORTU(struct lilith* vm, struct Instruction* c)
{
	uint32_t utmp1, utmp2;

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
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

	vm->reg[c->reg0] = (int32_t)(tmp1 + tmp2);
}

void ADDU(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] + vm->reg[c->reg2];
}

void SUB(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

	vm->reg[c->reg0] = (int32_t)(tmp1 - tmp2);
}

void SUBU(struct lilith* vm, struct Instruction* c)
{
		vm->reg[c->reg0] = vm->reg[c->reg1] - vm->reg[c->reg2];
}

void CMP(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

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
}

void CMPU(struct lilith* vm, struct Instruction* c)
{
	/* Clear bottom 3 bits of condition register */
	vm->reg[c->reg0] = vm->reg[c->reg0] & 0xFFFFFFF8;
	if(vm->reg[c->reg1] > vm->reg[c->reg2])
	{
		vm->reg[c->reg0] = vm->reg[c->reg0] | GreaterThan;
	}
	else if(vm->reg[c->reg1] == vm->reg[c->reg2])
	{
		vm->reg[c->reg0] = vm->reg[c->reg0] | EQual;
	}
	else
	{
		vm->reg[c->reg0] = vm->reg[c->reg0] | LessThan;
	}
}

void MUL(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

	int64_t sum = tmp1 * tmp2;

	/* We only want the bottom 32bits */
	vm->reg[c->reg0] = sum % 0x100000000;
}

void MULH(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

	int64_t sum = tmp1 * tmp2;

	/* We only want the top 32bits */
	vm->reg[c->reg0] = sum / 0x100000000;
}

void MULU(struct lilith* vm, struct Instruction* c)
{
	uint64_t tmp1, tmp2, sum;

	tmp1 = vm->reg[c->reg1];
	tmp2 = vm->reg[c->reg2];
	sum = tmp1 * tmp2;

		/* We only want the bottom 32bits */
		vm->reg[c->reg0] = sum % 0x100000000;
}

void MULUH(struct lilith* vm, struct Instruction* c)
{
	uint64_t tmp1, tmp2, sum;

	tmp1 = vm->reg[c->reg1];
	tmp2 = vm->reg[c->reg2];
	sum = tmp1 * tmp2;

		/* We only want the top 32bits */
		vm->reg[c->reg0] = sum / 0x100000000;
}

void DIV(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

	vm->reg[c->reg0] = tmp1 / tmp2;
}

void MOD(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

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
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

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
	int32_t tmp1, tmp2;

	tmp1 = (int32_t)(vm->reg[c->reg1]);
	tmp2 = (int32_t)(vm->reg[c->reg2]);

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

void PACK(struct lilith* vm, struct Instruction* c)
{

}

void UNPACK(struct lilith* vm, struct Instruction* c)
{

}

void PACK8_CO(struct lilith* vm, struct Instruction* c)
{

}

void PACK8U_CO(struct lilith* vm, struct Instruction* c)
{

}

void PACK16_CO(struct lilith* vm, struct Instruction* c)
{

}

void PACK16U_CO(struct lilith* vm, struct Instruction* c)
{

}

void PACK32_CO(struct lilith* vm, struct Instruction* c)
{

}

void PACK32U_CO(struct lilith* vm, struct Instruction* c)
{

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

}

void ROR(struct lilith* vm, struct Instruction* c)
{

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
	vm->reg[c->reg0] = (int32_t)(vm->reg[c->reg1]) * -1;
}

void ABS(struct lilith* vm, struct Instruction* c)
{
	if(0 <= (int32_t)(vm->reg[c->reg1]))
	{
		vm->reg[c->reg0] = vm->reg[c->reg1];
	}
	else
	{
		vm->reg[c->reg0] = (int32_t)(vm->reg[c->reg1]) * -1;
	}
}

void NABS(struct lilith* vm, struct Instruction* c)
{
	if(0 > (int32_t)(vm->reg[c->reg1]))
	{
		vm->reg[c->reg0] = vm->reg[c->reg1];
	}
	else
	{
		vm->reg[c->reg0] = (int32_t)(vm->reg[c->reg1]) * -1;
	}
}

void SWAP(struct lilith* vm, struct Instruction* c)
{
	uint32_t utmp1;

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
	vm->reg[c->reg1] = vm->reg[c->reg1] + 4;

	/* Update PC */
	vm->ip = vm->reg[c->reg0];
}

void READPC(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->ip;
}

void READSCID(struct lilith* vm, struct Instruction* c)
{
	/* We only support Base 8,16 and 32*/
	vm->reg[c->reg0] = 0x00000007;
}

void FALSE(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = 0;
}

void TRUE(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = 0xFFFFFFFF;
}

void JSR_COROUTINE(struct lilith* vm, struct Instruction* c)
{
	vm->ip = vm->reg[c->reg0];
}

void RET(struct lilith* vm, struct Instruction* c)
{
	/* Update our index */
	vm->reg[c->reg0] = vm->reg[c->reg0] - 4;

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
	vm->reg[c->reg0] = vm->reg[c->reg0] + 4;
}

void POPPC(struct lilith* vm, struct Instruction* c)
{
	/* Read in the new PC */
	vm->ip = readin_Reg(vm, vm->reg[c->reg0]);

	/* Update our index */
	vm->reg[c->reg0] = vm->reg[c->reg0] - 4;
}

void ADDI(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1;
	tmp1 = (int32_t)(vm->reg[c->reg1]);
	vm->reg[c->reg0] = (int32_t)(tmp1 + c->raw_Immediate);
}

void ADDUI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] + c->raw_Immediate;
}

void SUBI(struct lilith* vm, struct Instruction* c)
{
	int32_t tmp1;
	tmp1 = (int32_t)(vm->reg[c->reg1]);
	vm->reg[c->reg0] = (int32_t)(tmp1 - c->raw_Immediate);
}

void SUBUI(struct lilith* vm, struct Instruction* c)
{
	vm->reg[c->reg0] = vm->reg[c->reg1] - c->raw_Immediate;
}

void CMPI(struct lilith* vm, struct Instruction* c)
{
			/* Clear bottom 3 bits of condition register */
			vm->reg[c->reg0] = vm->reg[c->reg0] & 0xFFFFFFF8;
			if((int32_t)(vm->reg[c->reg1]) > c->raw_Immediate)
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | GreaterThan;
			}
			else if((int32_t)(vm->reg[c->reg1]) == c->raw_Immediate)
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | EQual;
			}
			else
			{
				vm->reg[c->reg0] = vm->reg[c->reg0] | LessThan;
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
	/* Clear bottom 3 bits of condition register */
	vm->reg[c->reg0] = vm->reg[c->reg0] & 0xFFFFFFF8;
	if(vm->reg[c->reg1] > (uint32_t)c->raw_Immediate)
	{
		vm->reg[c->reg0] = vm->reg[c->reg0] | GreaterThan;
	}
	else if(vm->reg[c->reg0] == (uint32_t)c->raw_Immediate)
	{
		vm->reg[c->reg0] = vm->reg[c->reg0] | EQual;
	}
	else
	{
		vm->reg[c->reg0] = vm->reg[c->reg0] | LessThan;
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
	vm->reg[c->reg0] = vm->reg[c->reg0] + 4;

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

void JUMP(struct lilith* vm, struct Instruction* c)
{
	vm->ip = vm->ip + c->raw_Immediate - 4;
}
