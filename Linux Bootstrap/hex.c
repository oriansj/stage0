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

#include<stdio.h>
#include<stdlib.h>
#include<stdbool.h>

void purge_line_comments()
{
	char c;
	do
	{
		c = getchar();

		if (EOF == c)
		{
			exit(EXIT_SUCCESS);
		}
	} while ( '\n' != c );
}

int hex(char c)
{
	switch(c)
	{
		case '0' ... '9': return (c - 48);
		case 'a' ... 'f': return (c - 87);
		case 'A' ... 'F': return (c - 55);
		default: break;
	}

	printf("You managed to call a hex function without a hex value!!!\n");
	exit(EXIT_FAILURE);
}

int main(int argc, char *argv[])
{
	char c;
	int sum;
	bool toggle;
	toggle = false;

	do
	{
		c = getchar();
		switch(c)
		{
			case '0' ... '9':
			case 'a' ... 'f':
			case 'A' ... 'F':
			{
				if(!toggle)
				{
					sum = hex(c);
					toggle = true;
				}
				else
				{
					sum = (sum * 16) + hex(c);
					toggle = false;
					putc(sum, stdout);
				}
				break;
			}
			case '#': purge_line_comments();
			default: break;
		}
	}while(c != EOF);

	exit(EXIT_SUCCESS);
}
