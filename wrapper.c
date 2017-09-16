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
#define DEBUG true
uint32_t performance_counter;
static struct lilith* Globalvm;

void unpack_byte(uint8_t a, char* c);

/* Load program tape into Memory */
void load_program(struct lilith* vm, char* name)
{
	FILE* program;
	program = fopen(name, "r");

	/* Figure out how much we need to load */
	fseek(program, 0, SEEK_END);
	size_t end = ftell(program);
	rewind(program);

	/* Load the entire tape into memory */
	fread(vm->memory, 1, end, program);

	fclose(program);
}

void execute_vm(struct lilith* vm)
{
	struct Instruction* current;
	current = calloc(1, sizeof(struct Instruction));

	read_instruction(vm, current);
	eval_instruction(vm, current);

	free(current);
	return;
}

void initialize_lilith(unsigned int size)
{
	tape_01_name = "tape_01";
	tape_02_name = "tape_02";
	struct lilith* vm;
	vm = create_vm(size);
	Globalvm = vm;
}

void load_lilith(char* name)
{
	load_program(Globalvm, name);
}

unsigned int step_lilith()
{
	if(!Globalvm->halted)
	{
		execute_vm(Globalvm);
	}
	return Globalvm->ip;
}

unsigned int get_register(unsigned int reg)
{
	unsigned int i;
	switch(reg)
	{
		case 0 ... 15:
		{
			i = Globalvm->reg[reg];
			break;
		}
		case 16: /* Get PC */
		{
			i = Globalvm->ip;
			break;
		}
		case 17: /* Instruction count */
		{
			i = performance_counter;
			break;
		}
		default:
		{
			fprintf(stderr, "What have you done????\n");
			exit(EXIT_FAILURE);
		}
	}
	return i;
}

void set_register(unsigned int reg, unsigned int value)
{
	switch(reg)
	{
		case 0 ... 15:
		{
			Globalvm->reg[reg] = value;
			break;
		}
		case 16: /* Set PC */
		{
			Globalvm->ip = value;
			break;
		}
		case 17: /* No one mess with the Instruction count */
		{
			fprintf(stderr, "Don't be a moron!!!!\n");
			break;
		}
		default:
		{
			fprintf(stderr, "What are you trying to do????\n");
			exit(EXIT_FAILURE);
		}
	}
}

void set_memory(unsigned int address, unsigned char value)
{
	outside_of_world(Globalvm, address, "Address outside of World");
	Globalvm->memory[address] = value;
}

unsigned char get_byte(unsigned int add)
{
	outside_of_world(Globalvm, add, "Address outside of World");
	return Globalvm->memory[add];
}

void insert_address(char* p, uint32_t value)
{
	char* segment;
	segment = p;
	unpack_byte((value >> 24), segment);
	segment = segment + 2;
	unpack_byte((value >> 16)%256, segment);
	segment = segment + 2;
	unpack_byte((value >> 8)%256, segment);
	segment = segment + 2;
	unpack_byte((value%256), segment);
}

void process_Memory_Row(char* p, uint32_t addr)
{
	char* segment = p;
	strncpy(segment, "<tr>\n<td>", 9);
	segment = segment + 9;
	insert_address(segment, addr);
	segment = segment + 8;
	strncpy(segment, "</td>", 5);
	segment = segment + 5;
	int i;
	for(i = 0; i < 16; i = i + 1)
	{
		strncpy(segment, "<td>", 4);
		segment = segment + 4;
		unpack_byte(Globalvm->memory[i + addr], segment);
		segment = segment + 2;
		strncpy(segment, "</td>", 5);
		segment = segment + 5;
	}

	strncpy(segment, "\n</tr>\n", 7);
}

char* get_memory(unsigned int start)
{
	char* result = calloc(4096 * 205 + 1, sizeof(char));
	int i, point;
	point = 0;
	for(i = 0; i < 4096; i = i + 16)
	{
		process_Memory_Row(result + point, start + i);
		point = point + 205;
	}

	return result;
}
