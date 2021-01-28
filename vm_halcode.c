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
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>

FILE* tape_01;
FILE* tape_02;

#ifdef tty_lib
char tty_getchar();
#endif

/* Imported functions */
void writeout_string(struct lilith* vm, char* s, unsigned_vm_register pointer);
char* string_copy(struct lilith* vm, signed_vm_register address);

/******************************************
 *         Always existing calls          *
 ******************************************/
void vm_HAL_MEM(struct lilith* vm)
{
	vm->reg[0] = vm->amount_of_Ram;
}


void vm_HALT(struct lilith* vm, uint64_t performance_counter)
{
	vm->halted = true;
	fprintf(stderr, "Computer Program has Halted\nAfter Executing %lu instructions\n", performance_counter);

	#ifdef TRACE
	record_trace("HALT");
	print_traces();
	#endif
}

/******************************************
 *         POSIX specific calls           *
 ******************************************/
char* SYS_READ_BUF;
void vm_SYS_READ(struct lilith* vm)
{
	if(NULL == SYS_READ_BUF) SYS_READ_BUF = calloc(Memory_Size, sizeof(char)); /* 20MB */
	int fd = vm->reg[0];
	int want = vm->reg[2];
	int count = read(fd, SYS_READ_BUF, want);

	int i = 0;
	while(i < count)
	{
		vm->memory[vm->reg[1] + i] = SYS_READ_BUF[i];
		i = i + 1;
	}
	vm->reg[0] = count;
}

char* SYS_WRITE_BUF;

void vm_SYS_WRITE(struct lilith* vm)
{
	if(NULL == SYS_WRITE_BUF) SYS_WRITE_BUF = calloc(Memory_Size, sizeof(char)); /* 20MB */
	int i = 0;
	while(i < vm->reg[2])
	{
		SYS_WRITE_BUF[i] = vm->memory[vm->reg[1] + i];
		i = i + 1;
	}
	int count = write(vm->reg[0], SYS_WRITE_BUF, vm->reg[2]);
	vm->reg[0] = count;
}


void vm_SYS_FOPEN(struct lilith* vm)
{
	char* s = string_copy(vm, vm->reg[0]);
	vm->reg[0] = open(s, vm->reg[1], vm->reg[2]);
	free(s);
}


void vm_SYS_FCLOSE(struct lilith* vm)
{
	close(vm->reg[0]);
}


void vm_SYS_FSEEK(struct lilith* vm)
{
	lseek(vm->reg[0], vm->reg[1], SEEK_CUR);
}


void vm_SYS_EXIT(struct lilith* vm, uint64_t performance_counter)
{
	vm->halted = true;
	fprintf(stderr, "Computer Program has Halted\nAfter Executing %lu instructions\n", performance_counter);

	#ifdef TRACE
	record_trace("SYS_EXIT");
	print_traces();
	#endif

	exit(vm->reg[0]);
}

void vm_SYS_CHMOD(struct lilith* vm)
{
	char* s = string_copy(vm, vm->reg[0]);
	chmod(s, vm->reg[1]);
	free(s);
}

void vm_SYS_UNAME(struct lilith* vm)
{
	writeout_string(vm, "sysname", vm->reg[0]);
	writeout_string(vm, "nodename", vm->reg[0] + 65);
	writeout_string(vm, "release", vm->reg[0] + 130);
	writeout_string(vm, "version", vm->reg[0] + 195);
	writeout_string(vm, arch_name, vm->reg[0] + 260);
}

void vm_SYS_GETCWD(struct lilith* vm)
{
	char* s = malloc(vm->reg[1]);
	s = getcwd(s, vm->reg[1]);
	if(NULL == s)
	{
		vm->reg[0] = 0;
	}
	else
	{
		writeout_string(vm, s, vm->reg[0]);
	}
	free(s);
}

void vm_SYS_CHDIR(struct lilith* vm)
{
	char* s = string_copy(vm, vm->reg[0]);
	vm->reg[0] = chdir(s);
	free(s);
}

void vm_SYS_FCHDIR(struct lilith* vm)
{
	vm->reg[0] = fchdir(vm->reg[0]);
}

void vm_SYS_ACCESS(struct lilith* vm)
{
	char* s = string_copy(vm, vm->reg[0]);
	vm->reg[0] = access(s, vm->reg[1]);
	free(s);
}


/******************************************
 * Bare metal specific instructions       *
 ******************************************/
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
	if(FUZZING)
	{
		vm->reg[0] = 0;
	}
	else
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
}


void vm_FCLOSE(struct lilith* vm)
{
	if(0x00001100 == vm->reg[0])
	{
		require(NULL != tape_01, "tape_01 not valid for fclose\nAborting to prevent issues\n");
		fclose(tape_01);
		tape_01 = NULL;
	}

	if (0x00001101 == vm->reg[0])
	{
		require(NULL != tape_02, "tape_02 not valid for fclose\nAborting to prevent issues\n");
		fclose(tape_02);
		tape_02 = NULL;
	}
}


void vm_REWIND(struct lilith* vm)
{
	if(0x00001100 == vm->reg[0])
	{
		require(NULL != tape_01, "tape_01 not valid for rewind\nAborting to prevent issues\n");
		rewind(tape_01);
	}

	if (0x00001101 == vm->reg[0])
	{
		require(NULL != tape_02, "tape_02 not valid for rewind\nAborting to prevent issues\n");
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
		byte = fgetc(TTY_in);
		#endif
	}

	if(0x00001100 == vm->reg[1])
	{
		require(NULL != tape_01, "tape_01 not valid for fgetc\nAborting to prevent issues\n");
		byte = fgetc(tape_01);
	}

	if (0x00001101 == vm->reg[1])
	{
		require(NULL != tape_02, "tape_02 not valid for fgetc\nAborting to prevent issues\n");
		byte = fgetc(tape_02);
	}

	vm->reg[0] = byte;
}


void vm_FPUTC(struct lilith* vm)
{
	signed_vm_register byte = vm->reg[0] & 0xFF;

	if (0x00000000 == vm->reg[1])
	{
		fputc(byte, TTY_out);
		#ifdef tty_lib
		fflush(TTY_out);
		#endif
	}

	if(0x00001100 == vm->reg[1])
	{
		require(NULL != tape_01, "tape_01 not valid for fputc\nAborting to prevent issues\n");
		fputc(byte, tape_01);
	}

	if (0x00001101 == vm->reg[1])
	{
		require(NULL != tape_02, "tape_02 not valid for fputc\nAborting to prevent issues\n");
		fputc(byte, tape_02);
	}
}
