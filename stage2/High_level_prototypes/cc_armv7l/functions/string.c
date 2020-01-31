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
#include<stdlib.h>
#define MAX_STRING 4096
//CONSTANT MAX_STRING 4096
// void* calloc(int count, int size);

char* copy_string(char* target, char* source)
{
	while(0 != source[0])
	{
		target[0] = source[0];
		target = target + 1;
		source = source + 1;
	}
	return target;
}

char* postpend_char(char* s, char a)
{
	char* ret = calloc(MAX_STRING, sizeof(char));
	char* hold = copy_string(ret, s);
	hold[0] = a;
	return ret;
}

char* prepend_char(char a, char* s)
{
	char* ret = calloc(MAX_STRING, sizeof(char));
	ret[0] = a;
	copy_string((ret+1), s);
	return ret;
}

char* prepend_string(char* add, char* base)
{
	char* ret = calloc(MAX_STRING, sizeof(char));
	copy_string(copy_string(ret, add), base);
	return ret;
}

int string_length(char* a)
{
	int i = 0;
	while(0 != a[i]) i = i + 1;
	return i;
}
