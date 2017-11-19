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
	if (c >= '0' && c <= '9')
	{
		return (c - 48);
	}
	else if (c >= 'a' && c <= 'z')
	{
		return (c - 87);
	}
	else if (c >= 'A' && c <= 'Z')
	{
		return (c - 55);
	}
        printf("You managed to call a hex function without a hex value!!!\n");
        exit(EXIT_FAILURE);
}

int main(int argc, char *argv[])
{
	int c;
	int sum;
	bool toggle;
	toggle = false;

	do
	{
		c = getchar();
                if (c == '#')
                	purge_line_comments();
		else if ((c >= '0' && c <= '9')
                         || (c >= 'a' && c <= 'z')
                         || (c >= 'A' && c <= 'Z'))
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
				fputc(sum, stdout);
			}
		}
	}while(c != EOF);

	exit(EXIT_SUCCESS);
}
