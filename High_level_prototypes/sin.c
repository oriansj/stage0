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
#include <stdbool.h>

/* Standard C main program */
int main(int argc, char **argv)
{
	/* Make sure we have a program tape to run */
	if (argc < 2)
	{
		fprintf(stderr, "Usage: %s $FileName\nWhere $FileName is the name of the file being examined\n", argv[0]);
		return EXIT_FAILURE;
	}

	FILE* source_file = fopen(argv[1], "r");
	int numbers = 0;
	int lowers = 0;
	int upppers = 0;
	int others = 0;

	int c;
	do
	{
		c = fgetc(source_file);
		switch(c)
		{
			case -1: fprintf(stderr, "Reached end of File\n"); break;
			case 48 ... 57: numbers = numbers + 1; break;
			case 65 ... 90: upppers = upppers + 1; break;
			case 97 ... 122: lowers = lowers + 1; break;
			case 9:
			case 10:
			case 32 ... 47:
			case 58 ... 64:
			case 91 ... 96:
			case 123 ...126: others = others + 1; break;
			default: fprintf(stderr, "read %02X\n", c);
		}
	} while(EOF != c);

	fprintf(stderr, "Found %d numbers\nFound %d uppers\nFound %d lowers\nFound %d others\n", numbers, upppers, lowers, others);

	fclose(source_file);
	return EXIT_SUCCESS;
}
