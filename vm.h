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

#include <stdio.h>
#include <stdlib.h>
#include "vm_types.h"

/* Prototypes for functions in vm_instructions.c*/
extern void vm_EXIT(struct lilith* vm, uint64_t performance_counter);
extern void vm_CHMOD(struct lilith* vm);
extern void vm_UNAME(struct lilith* vm);
extern void vm_GETCWD(struct lilith* vm);
extern void vm_CHDIR(struct lilith* vm);
extern void vm_FCHDIR(struct lilith* vm);
extern void vm_ACCESS(struct lilith* vm);
extern void vm_FOPEN(struct lilith* vm);
extern void vm_FOPEN_READ(struct lilith* vm);
extern void vm_FOPEN_WRITE(struct lilith* vm);
extern void vm_FCLOSE(struct lilith* vm);
extern void vm_FSEEK(struct lilith* vm);
extern void vm_REWIND(struct lilith* vm);
extern void vm_FGETC(struct lilith* vm);
extern void vm_FPUTC(struct lilith* vm);
extern void vm_HAL_MEM(struct lilith* vm);
extern void ADD_CI(struct lilith* vm, struct Instruction* c);
extern void ADD_CO(struct lilith* vm, struct Instruction* c);
extern void ADD_CIO(struct lilith* vm, struct Instruction* c);
extern void ADDU_CI(struct lilith* vm, struct Instruction* c);
extern void ADDU_CO(struct lilith* vm, struct Instruction* c);
extern void ADDU_CIO(struct lilith* vm, struct Instruction* c);
extern void SUB_BI(struct lilith* vm, struct Instruction* c);
extern void SUB_BO(struct lilith* vm, struct Instruction* c);
extern void SUB_BIO(struct lilith* vm, struct Instruction* c);
extern void SUBU_BI(struct lilith* vm, struct Instruction* c);
extern void SUBU_BO(struct lilith* vm, struct Instruction* c);
extern void SUBU_BIO(struct lilith* vm, struct Instruction* c);
extern void MULTIPLY(struct lilith* vm, struct Instruction* c);
extern void MULTIPLYU(struct lilith* vm, struct Instruction* c);
extern void DIVIDE(struct lilith* vm, struct Instruction* c);
extern void DIVIDEU(struct lilith* vm, struct Instruction* c);
extern void MUX(struct lilith* vm, struct Instruction* c);
extern void NMUX(struct lilith* vm, struct Instruction* c);
extern void SORT(struct lilith* vm, struct Instruction* c);
extern void SORTU(struct lilith* vm, struct Instruction* c);
extern void ADD(struct lilith* vm, struct Instruction* c);
extern void ADDU(struct lilith* vm, struct Instruction* c);
extern void SUB(struct lilith* vm, struct Instruction* c);
extern void SUBU(struct lilith* vm, struct Instruction* c);
extern void CMP(struct lilith* vm, struct Instruction* c);
extern void CMPU(struct lilith* vm, struct Instruction* c);
extern void MUL(struct lilith* vm, struct Instruction* c);
extern void MULH(struct lilith* vm, struct Instruction* c);
extern void MULU(struct lilith* vm, struct Instruction* c);
extern void MULUH(struct lilith* vm, struct Instruction* c);
extern void DIV(struct lilith* vm, struct Instruction* c);
extern void MOD(struct lilith* vm, struct Instruction* c);
extern void DIVU(struct lilith* vm, struct Instruction* c);
extern void MODU(struct lilith* vm, struct Instruction* c);
extern void MAX(struct lilith* vm, struct Instruction* c);
extern void MAXU(struct lilith* vm, struct Instruction* c);
extern void MIN(struct lilith* vm, struct Instruction* c);
extern void MINU(struct lilith* vm, struct Instruction* c);
extern void AND(struct lilith* vm, struct Instruction* c);
extern void OR(struct lilith* vm, struct Instruction* c);
extern void XOR(struct lilith* vm, struct Instruction* c);
extern void NAND(struct lilith* vm, struct Instruction* c);
extern void NOR(struct lilith* vm, struct Instruction* c);
extern void XNOR(struct lilith* vm, struct Instruction* c);
extern void MPQ(struct lilith* vm, struct Instruction* c);
extern void LPQ(struct lilith* vm, struct Instruction* c);
extern void CPQ(struct lilith* vm, struct Instruction* c);
extern void BPQ(struct lilith* vm, struct Instruction* c);
extern void SAL(struct lilith* vm, struct Instruction* c);
extern void SAR(struct lilith* vm, struct Instruction* c);
extern void SL0(struct lilith* vm, struct Instruction* c);
extern void SR0(struct lilith* vm, struct Instruction* c);
extern void SL1(struct lilith* vm, struct Instruction* c);
extern void SR1(struct lilith* vm, struct Instruction* c);
extern void ROL(struct lilith* vm, struct Instruction* c);
extern void ROR(struct lilith* vm, struct Instruction* c);
extern void LOADX(struct lilith* vm, struct Instruction* c);
extern void LOADX8(struct lilith* vm, struct Instruction* c);
extern void LOADXU8(struct lilith* vm, struct Instruction* c);
extern void LOADX16(struct lilith* vm, struct Instruction* c);
extern void LOADXU16(struct lilith* vm, struct Instruction* c);
extern void LOADX32(struct lilith* vm, struct Instruction* c);
extern void LOADXU32(struct lilith* vm, struct Instruction* c);
extern void STOREX(struct lilith* vm, struct Instruction* c);
extern void STOREX8(struct lilith* vm, struct Instruction* c);
extern void STOREX16(struct lilith* vm, struct Instruction* c);
extern void STOREX32(struct lilith* vm, struct Instruction* c);
extern void NEG(struct lilith* vm, struct Instruction* c);
extern void ABS(struct lilith* vm, struct Instruction* c);
extern void NABS(struct lilith* vm, struct Instruction* c);
extern void SWAP(struct lilith* vm, struct Instruction* c);
extern void COPY(struct lilith* vm, struct Instruction* c);
extern void MOVE(struct lilith* vm, struct Instruction* c);
extern void BRANCH(struct lilith* vm, struct Instruction* c);
extern void CALL(struct lilith* vm, struct Instruction* c);
extern void READPC(struct lilith* vm, struct Instruction* c);
extern void READSCID(struct lilith* vm, struct Instruction* c);
extern void FALSE(struct lilith* vm, struct Instruction* c);
extern void TRUE(struct lilith* vm, struct Instruction* c);
extern void JSR_COROUTINE(struct lilith* vm, struct Instruction* c);
extern void RET(struct lilith* vm, struct Instruction* c);
extern void PUSHPC(struct lilith* vm, struct Instruction* c);
extern void POPPC(struct lilith* vm, struct Instruction* c);
extern void ADDI(struct lilith* vm, struct Instruction* c);
extern void ADDUI(struct lilith* vm, struct Instruction* c);
extern void SUBI(struct lilith* vm, struct Instruction* c);
extern void SUBUI(struct lilith* vm, struct Instruction* c);
extern void CMPI(struct lilith* vm, struct Instruction* c);
extern void LOAD(struct lilith* vm, struct Instruction* c);
extern void LOAD8(struct lilith* vm, struct Instruction* c);
extern void LOADU8(struct lilith* vm, struct Instruction* c);
extern void LOAD16(struct lilith* vm, struct Instruction* c);
extern void LOADU16(struct lilith* vm, struct Instruction* c);
extern void LOAD32(struct lilith* vm, struct Instruction* c);
extern void LOADU32(struct lilith* vm, struct Instruction* c);
extern void CMPUI(struct lilith* vm, struct Instruction* c);
extern void STORE(struct lilith* vm, struct Instruction* c);
extern void STORE8(struct lilith* vm, struct Instruction* c);
extern void STORE16(struct lilith* vm, struct Instruction* c);
extern void STORE32(struct lilith* vm, struct Instruction* c);
extern void JUMP_C(struct lilith* vm, struct Instruction* c);
extern void JUMP_B(struct lilith* vm, struct Instruction* c);
extern void JUMP_O(struct lilith* vm, struct Instruction* c);
extern void JUMP_G(struct lilith* vm, struct Instruction* c);
extern void JUMP_GE(struct lilith* vm, struct Instruction* c);
extern void JUMP_E(struct lilith* vm, struct Instruction* c);
extern void JUMP_NE(struct lilith* vm, struct Instruction* c);
extern void JUMP_LE(struct lilith* vm, struct Instruction* c);
extern void JUMP_L(struct lilith* vm, struct Instruction* c);
extern void JUMP_Z(struct lilith* vm, struct Instruction* c);
extern void JUMP_NZ(struct lilith* vm, struct Instruction* c);
extern void CALLI(struct lilith* vm, struct Instruction* c);
extern void LOADI(struct lilith* vm, struct Instruction* c);
extern void LOADUI(struct lilith* vm, struct Instruction* c);
extern void SALI(struct lilith* vm, struct Instruction* c);
extern void SARI(struct lilith* vm, struct Instruction* c);
extern void SL0I(struct lilith* vm, struct Instruction* c);
extern void SR0I(struct lilith* vm, struct Instruction* c);
extern void SL1I(struct lilith* vm, struct Instruction* c);
extern void SR1I(struct lilith* vm, struct Instruction* c);
extern void LOADR(struct lilith* vm, struct Instruction* c);
extern void LOADR8(struct lilith* vm, struct Instruction* c);
extern void LOADRU8(struct lilith* vm, struct Instruction* c);
extern void LOADR16(struct lilith* vm, struct Instruction* c);
extern void LOADRU16(struct lilith* vm, struct Instruction* c);
extern void LOADR32(struct lilith* vm, struct Instruction* c);
extern void LOADRU32(struct lilith* vm, struct Instruction* c);
extern void STORER(struct lilith* vm, struct Instruction* c);
extern void STORER8(struct lilith* vm, struct Instruction* c);
extern void STORER16(struct lilith* vm, struct Instruction* c);
extern void STORER32(struct lilith* vm, struct Instruction* c);
extern void JUMP(struct lilith* vm, struct Instruction* c);
extern void JUMP_P(struct lilith* vm, struct Instruction* c);
extern void JUMP_NP(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPI_G(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPI_GE(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPI_E(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPI_NE(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPI_LE(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPI_L(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPUI_G(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPUI_GE(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPUI_LE(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPUI_L(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPI_G(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPI_GE(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPI_E(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPI_NE(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPI_LE(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPI_L(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPUI_G(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPUI_GE(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPUI_LE(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPUI_L(struct lilith* vm, struct Instruction* c);
extern void PUSHR(struct lilith* vm, struct Instruction* c);
extern void PUSH8(struct lilith* vm, struct Instruction* c);
extern void PUSH16(struct lilith* vm, struct Instruction* c);
extern void PUSH32(struct lilith* vm, struct Instruction* c);
extern void POPR(struct lilith* vm, struct Instruction* c);
extern void POP8(struct lilith* vm, struct Instruction* c);
extern void POPU8(struct lilith* vm, struct Instruction* c);
extern void POP16(struct lilith* vm, struct Instruction* c);
extern void POPU16(struct lilith* vm, struct Instruction* c);
extern void POP32(struct lilith* vm, struct Instruction* c);
extern void POPU32(struct lilith* vm, struct Instruction* c);
extern void ANDI(struct lilith* vm, struct Instruction* c);
extern void ORI(struct lilith* vm, struct Instruction* c);
extern void XORI(struct lilith* vm, struct Instruction* c);
extern void NANDI(struct lilith* vm, struct Instruction* c);
extern void NORI(struct lilith* vm, struct Instruction* c);
extern void XNORI(struct lilith* vm, struct Instruction* c);
extern void NOT(struct lilith* vm, struct Instruction* c);
extern void CMPSKIP_G(struct lilith* vm, struct Instruction* c);
extern void CMPSKIP_GE(struct lilith* vm, struct Instruction* c);
extern void CMPSKIP_E(struct lilith* vm, struct Instruction* c);
extern void CMPSKIP_NE(struct lilith* vm, struct Instruction* c);
extern void CMPSKIP_LE(struct lilith* vm, struct Instruction* c);
extern void CMPSKIP_L(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPU_G(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPU_GE(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPU_LE(struct lilith* vm, struct Instruction* c);
extern void CMPSKIPU_L(struct lilith* vm, struct Instruction* c);
extern void CMPJUMP_G(struct lilith* vm, struct Instruction* c);
extern void CMPJUMP_GE(struct lilith* vm, struct Instruction* c);
extern void CMPJUMP_E(struct lilith* vm, struct Instruction* c);
extern void CMPJUMP_NE(struct lilith* vm, struct Instruction* c);
extern void CMPJUMP_LE(struct lilith* vm, struct Instruction* c);
extern void CMPJUMP_L(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPU_G(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPU_GE(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPU_LE(struct lilith* vm, struct Instruction* c);
extern void CMPJUMPU_L(struct lilith* vm, struct Instruction* c);
extern void SET_G(struct lilith* vm, struct Instruction* c);
extern void SET_GE(struct lilith* vm, struct Instruction* c);
extern void SET_E(struct lilith* vm, struct Instruction* c);
extern void SET_NE(struct lilith* vm, struct Instruction* c);
extern void SET_LE(struct lilith* vm, struct Instruction* c);
extern void SET_L(struct lilith* vm, struct Instruction* c);

/* Prototypes for functions in vm_decode.c*/
extern struct lilith* create_vm(size_t size);
extern void destroy_vm(struct lilith* vm);
extern void read_instruction(struct lilith* vm, struct Instruction *current);
extern void eval_instruction(struct lilith* vm, struct Instruction* current);
extern void outside_of_world(struct lilith* vm, unsigned_vm_register place, char* message);

/* Allow tape names to be effectively changed */
extern char* tape_01_name;
extern char* tape_02_name;

/* Enable POSIX Mode */
extern bool POSIX_MODE;
extern bool FUZZING;

/* Commonly useful functions */
extern void require(int boolean, char* error);
extern int match(char* a, char* b);
