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
#include <string.h>
#define max_string 60

FILE* source_file;
bool toggle;
uint8_t holder;
uint32_t ip;

struct entry
{
	uint32_t target;
	char name[max_string + 1];
};

char temp[max_string + 1];
struct entry table[256];

uint32_t GetTarget(char* c)
{
	int i = -1;
	do
	{
		i = i + 1;
	} while (0 != strncmp(table[i].name, c, max_string));

	return table[i].target;
}

void storeLabel()
{
	int c = fgetc(source_file);
	int i = 0;
	int index = -1;

	do
	{
		index = index + 1;
	} while(0 != table[index].name[0]);

	while((' ' != c) && ('\t' != c) && ('\n' != c))
	{
		table[index].name[i] = c;
		i = i + 1;
		c = fgetc(source_file);
	}

	table[index].target = ip;
}

void storePointer(char ch)
{
	if('&' == ch)
	{
		ip = ip + 4;
	}
	else
	{
		ip = ip + 2;
	}
	int c = fgetc(source_file);
	int i = 0;

	while(0 != temp[i])
	{
		temp[i] = 0;
		i = i+1;
	}

	i = 0;

	while((' ' != c) && ('\t' != c) && ('\n' != c))
	{
		temp[i] = c;
		i = i + 1;
		c = fgetc(source_file);
	}

	int target = GetTarget(temp);
	uint8_t first, second;
	if('$' == ch)
	{ /* Deal with $ */
		first = target/256;
		second = target%256;
		printf("%c%c", first, second );
	}
	else if('@' == ch)
	{ /* Deal with @ */
		first = (target - ip + 4)/256;
		second = (target - ip + 4)%256;
		printf("%c%c", first, second );
	}
	else if('&' == ch)
	{
		uint8_t third, fourth;
		first = target >> 24;
		second = (target >> 16)%256;
		third = (target >> 8)%256;
		fourth = target%256;
		printf("%c%c%c%c", first, second, third, fourth);
	}
}

void line_Comment()
{
	int c = fgetc(source_file);
	while(('\n' != c) && ('\r' != c))
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
			return (c - ('0' - 0x0));
		}
		case 'a' ... 'z':
		{
			return (c - ('a' - 0xa));
		}
		case 'A' ... 'Z':
		{
			return (c - ('A' - 0xA));
		}
		case '#':
		case ';':
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
		if(':' == c)
		{
			storeLabel();
		}

		/* check for and deal with relative pointers to labels */
		if(('@' == c) || ('$' == c))
		{ /* deal with @ and $ */
			while((' ' != c) && ('\t' != c) && ('\n' != c))
			{
				c = fgetc(source_file);
			}
			ip = ip + 2;
		}
		else if('&' == c)
		{ /* deal with & */
			while((' ' != c) && ('\t' != c) && ('\n' != c))
			{
				c = fgetc(source_file);
			}
			ip = ip + 4;
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
		if(':' == c)
		{ /* Deal with : */
			while((' ' != c) && ('\t' != c) && ('\n' != c))
			{
				c = fgetc(source_file);
			}
		}
		else if(('@' == c) || ('$' == c) || ('&' == c))
		{ /* Deal with @, $ and & */
			storePointer(c);
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
