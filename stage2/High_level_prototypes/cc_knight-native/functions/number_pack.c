/* Copyright (C) 2016 Jeremiah Orians
 * This file is part of M2-Planet.
 *
 * M2-Planet is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * M2-Planet is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with M2-Planet.  If not, see <http://www.gnu.org/licenses/>.
 */

#include<stdlib.h>
#include<string.h>
#include<stdio.h>
// void* calloc(int count, int size);
int hex2char(int c);
void file_print(char* s, FILE* f);

char* number_to_hex(int a, int bytes)
{
	char* result = calloc(1 + (bytes << 1), sizeof(char));
	if(NULL == result)
	{
		file_print("calloc failed in number_to_hex\n", stderr);
		exit(EXIT_FAILURE);
	}
	int i = 0;

	int divisor = (bytes << 3);

	/* Simply collect numbers until divisor is gone */
	while(0 != divisor)
	{
		divisor = divisor - 4;
		result[i] = hex2char((a >> divisor) & 0xF);
		i = i + 1;
	}

	return result;
}
