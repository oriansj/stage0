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
#include <stdint.h>
#include <stdbool.h>

FILE* source_file;
bool toggle;
uint8_t holder;
uint32_t ip;

uint32_t* table;

void storeLabel()
{
	int c = fgetc(source_file);
	table[c] = ip;
}

void storePointer()
{
	ip = ip + 2;
	int c = fgetc(source_file);
	int target = table[c];
	uint8_t first, second;
	first = (target - ip + 4)/256;
	second = (target - ip + 4)%256;
	printf("%c%c", first, second );
}

void line_Comment()
{
	int c = fgetc(source_file);
	while((10 != c) && (13 != c))
	{
		c = fgetc(source_file);
	}
}

int8_t hex(int c)
{
	switch(c)
	{
		case '0' ... '9':
		{
			return (c - 48);
		}
		case 'a' ... 'z':
		{
			return (c - 87);
		}
		case 'A' ... 'Z':
		{
			return (c - 55);
		}
		case 35:
		case 59:
		{
			line_Comment();
			return -1;
		}
		default: return -1;
	}

}

void first_pass()
{
	int c;
	for(c = fgetc(source_file); EOF != c; c = fgetc(source_file))
	{
		/* Check for and deal with label */
		if(58 == c)
		{
			storeLabel();
		}

		/* check for and deal with pointers to labels */
		if(64 == c)
		{
			c = fgetc(source_file);
			ip = ip + 2;
		}
		else
		{
			if(0 <= hex(c))
			{
				if(toggle)
				{
					ip = ip + 1;
				}

				toggle = !toggle;
			}
		}
	}
}

void second_pass()
{
	int c;
	for(c = fgetc(source_file); EOF != c; c = fgetc(source_file))
	{
		if(58 == c)
		{
			c = fgetc(source_file);
		}
		else if(64 == c)
		{
			storePointer();
		}
		else
		{
			if(0 <= hex(c))
			{
				if(toggle)
				{
					printf("%c",((holder * 16)) + hex(c));
					ip = ip + 1;
					holder = 0;
				}
				else
				{
					holder = hex(c);
				}

				toggle = !toggle;
			}
		}
	}
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

	source_file = fopen(argv[1], "r");

	table = calloc(256, sizeof(uint32_t));
	toggle = false;
	ip = 0;
	holder = 0;

	first_pass();
	rewind(source_file);
	toggle = false;
	ip = 0;
	holder = 0;
	second_pass();

	return EXIT_SUCCESS;
}
