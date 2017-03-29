 /* This file is part of stage0.
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
