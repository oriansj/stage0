#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

static uint32_t address;

void dehex(uint8_t c)
{
	if(0 == address%4)
	{
		char line[255] = {0};
		sprintf(line, "%08x", address);
		printf("\n%s:\t", line);
	}

	char table[16] = {0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46};
	printf("%c%c ", table[c/16], table[c%16]);
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

	FILE* source_file = fopen(argv[1], "r");

	int c = fgetc(source_file);
	while(EOF != c)
	{
		dehex(c);
		c = fgetc(source_file);
		address = address + 1;
	}

	exit(EXIT_SUCCESS);
}
