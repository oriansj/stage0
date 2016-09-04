#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
char tty_getchar();

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
	int count = 10;
	while(EOF != c)
	{
		fprintf(stdout, "%c", c);
		if(10 == c)
		{
			count = count - 1;
		}
		if(0 == count)
		{
			tty_getchar();
			count = 10;
		}
		c = fgetc(source_file);
	}

	exit(EXIT_SUCCESS);
}
