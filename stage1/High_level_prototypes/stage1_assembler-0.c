/* Copyright (C) 2020 Jeremiah Orians
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

FILE* source_file;

void line_Comment()
{
	int c = fgetc(source_file);
	while(('\n' != c) && ('\r' != c)) //Discard input until we get to a newline
	{
		c = fgetc(source_file);
	}
}

int hex(int c)
{
	/* Clear out line comments */
	if((';' == c) || ('#' == c))
	{
		line_Comment();
		return -1;
	}

	/* Deal with non-hex chars*/
	if('0' > c) return -1;

	/* Deal with 0-9 */
	if('9' >= c) return (c - ('0' - 0x0));

	/* Convert a-f to A-F*/
	c = c & 0xDF;

	/* Get rid of everything below A */
	if('A' > c) return -1;

	/* Deal with A-F */
	if('F' >= c) return (c - ('A' - 0xA));

	/* Everything else is garbage */
	return -1;
}

/* Standard C main program */
int main()
{
	source_file = fopen("tape_01", "r");
	FILE* destination_file = fopen("tape_02", "w");

	int toggle = false;
	int holder = 0;

	int c;
	int R0;

	for(c = fgetc(source_file); EOF != c; c = fgetc(source_file))
	{
		R0 = hex(c);
		if(0 <= R0)
		{
			if(toggle)
			{
				fputc(((holder * 16)) + R0, destination_file);
				holder = 0;
			}
			else
			{
				holder = R0;
			}

			toggle = !toggle;
		}
	}

	return EXIT_SUCCESS;
}
