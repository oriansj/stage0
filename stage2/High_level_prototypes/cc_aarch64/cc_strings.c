/* Copyright (C) 2016 Jeremiah Orians
 * Copyright (C) 2018 Jan (janneke) Nieuwenhuizen <janneke@gnu.org>
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

#include "cc.h"
#include <stdint.h>

struct token_list* emit(char *s, struct token_list* head);
int char2hex(int c);

char upcase(char a)
{
	if(in_set(a, "abcdefghijklmnopqrstuvwxyz"))
	{
		a = a - 32;
	}

	return a;
}

int hexify(int c, int high)
{
	int i = char2hex(c);

	if(0 > i)
	{
		file_print("Tried to print non-hex number\n", stderr);
		exit(EXIT_FAILURE);
	}

	if(high)
	{
		i = i << 4;
	}
	return i;
}

int escape_lookup(char* c);
int weird(char* string)
{
	int c;
	string = string + 1;
weird_reset:
	c = string[0];
	if(0 == c) return FALSE;
	if('\\' == c)
	{
		c = escape_lookup(string);
		if('x' == string[1]) string = string + 2;
		string = string + 1;
	}

	if(!in_set(c, "\t\n !#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")) return TRUE;
	if(in_set(c, " \t\n\r") && (':' == string[1])) return TRUE;
	string = string + 1;
	goto weird_reset;
}

/* Lookup escape values */
int escape_lookup(char* c)
{
	if('\\' != c[0]) return c[0];

	if(c[1] == 'x')
	{
		int t1 = hexify(c[2], TRUE);
		int t2 = hexify(c[3], FALSE);
		return t1 + t2;
	}
	else if(c[1] == 't') return 9;
	else if(c[1] == 'n') return 10;
	else if(c[1] == 'v') return 11;
	else if(c[1] == 'f') return 12;
	else if(c[1] == 'r') return 13;
	else if(c[1] == 'e') return 27;
	else if(c[1] == '"') return 34;
	else if(c[1] == '\'') return 39;
	else if(c[1] == '\\') return 92;

	file_print("Unknown escape recieved: ", stderr);
	file_print(c, stderr);
	file_print(" Unable to process\n", stderr);
	exit(EXIT_FAILURE);
}

/* Deal with human strings */
char* collect_regular_string(char* string)
{
	string_index = 0;

collect_regular_string_reset:
	if(string[0] == '\\')
	{
		hold_string[string_index] = escape_lookup(string);
		if (string[1] == 'x') string = string + 2;
		string = string + 2;
	}
	else
	{
		hold_string[string_index] = string[0];
		string = string + 1;
	}

	string_index = string_index + 1;
	if(string[0] != 0) goto collect_regular_string_reset;

	hold_string[string_index] = '"';
	hold_string[string_index + 1] = '\n';
	char* message = calloc(string_index + 3, sizeof(char));
	copy_string(message, hold_string);
	reset_hold_string();
	return message;
}

/* Deal with non-human strings */
char* collect_weird_string(char* string)
{
	string_index = 1;
	int temp;
	char* table = "0123456789ABCDEF";

	hold_string[0] = '\'';
collect_weird_string_reset:
	string = string + 1;
	hold_string[string_index] = ' ';
	temp = escape_lookup(string);
	hold_string[string_index + 1] = table[(temp >> 4)];
	hold_string[string_index + 2] = table[(temp & 15)];

	if(string[0] == '\\')
	{
		if(string[1] == 'x') string = string + 2;
		string = string + 1;
	}

	string_index = string_index + 3;
	if(string[1] != 0) goto collect_weird_string_reset;

	hold_string[string_index] = ' ';
	hold_string[string_index + 1] = '0';
	hold_string[string_index + 2] = '0';
	hold_string[string_index + 3] = '\'';
	hold_string[string_index + 4] = '\n';

	char* hold = calloc(string_index + 6, sizeof(char));
	copy_string(hold, hold_string);
	reset_hold_string();
	return hold;
}

/* Parse string to deal with hex characters*/
char* parse_string(char* string)
{
	/* the string */
	if(weird(string)) return collect_weird_string(string);
	else return collect_regular_string(string);
}
