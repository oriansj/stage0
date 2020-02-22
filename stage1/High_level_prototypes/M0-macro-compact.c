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

// CONSTANT max_string 4096
#define max_string 4096
// CONSTANT FALSE 0
#define FALSE 0
// CONSTANT TRUE 1
#define TRUE 1

struct Token
{
	struct Token* next;
	char* Text;
	char* Expression;
};


FILE* source_file;
char* scratch;
int length;
struct Token* tokens;


int in_set(int c, char* s)
{
	while(0 != s[0])
	{
		if(c == s[0]) return TRUE;
		s = s + 1;
	}
	return FALSE;
}


int match(char* a, char* b)
{
	int i = -1;
	do
	{
		i = i + 1;
		if(a[i] != b[i])
		{
			return FALSE;
		}
	} while((0 != a[i]) && (0 !=b[i]));
	return TRUE;
}


void file_print(char* s, FILE* f)
{
	while(0 != s[0])
	{
		fputc(s[0], f);
		s = s + 1;
	}
}


int char2hex(int c)
{
	if (c >= '0' && c <= '9') return (c - 48);
	else if (c >= 'a' && c <= 'f') return (c - 87);
	else if (c >= 'A' && c <= 'F') return (c - 55);
	else return -1;
}


int char2dec(int c)
{
	if (c >= '0' && c <= '9') return (c - 48);
	else return -1;
}


int numerate_string(char *a)
{
	int count = 0;
	int index;
	int negative;

	/* If NULL string */
	if(0 == a[0])
	{
		return 0;
	}
	/* Deal with hex */
	else if (a[0] == '0' && a[1] == 'x')
	{
		if('-' == a[2])
		{
			negative = TRUE;
			index = 3;
		}
		else
		{
			negative = FALSE;
			index = 2;
		}

		while(0 != a[index])
		{
			if(-1 == char2hex(a[index])) return 0;
			count = (16 * count) + char2hex(a[index]);
			index = index + 1;
		}
	}
	/* Deal with decimal */
	else
	{
		if('-' == a[0])
		{
			negative = TRUE;
			index = 1;
		}
		else
		{
			negative = FALSE;
			index = 0;
		}

		while(0 != a[index])
		{
			if(-1 == char2dec(a[index])) return 0;
			count = (10 * count) + char2dec(a[index]);
			index = index + 1;
		}
	}

	if(negative)
	{
		count = count * -1;
	}
	return count;
}


void clear_scratch()
{
	int i = 0;
	while(0 != scratch[i])
	{
		scratch[i] = 0;
		i = i + 1;
	}
	length = 0;
}


int read_string(int terminator)
{
	int c = terminator;
	do
	{
		scratch[length] = c;
		c = fgetc(source_file);
		length = length + 1;
	} while(terminator != c);
	return fgetc(source_file);
}


int delete_line_comment()
{
	int c = fgetc(source_file);
	while(c != '\n') c = fgetc(source_file);
	return c;
}


int read_token()
{
	int c = fgetc(source_file);
	if (EOF == c) return EOF;
	if(in_set(c, "#;")) return delete_line_comment();
	if (in_set(c, "\"'")) return read_string(c);
	while(!in_set(c, "\n\t "))
	{
		scratch[length] = c;
		c = fgetc(source_file);
		length = length + 1;
	}

	return c;
}


void collect_defines()
{
	int c;
	struct Token* n;
	do
	{
		c = read_token();
		if(match(scratch, "DEFINE"))
		{
			clear_scratch();
			n = calloc(1, sizeof(struct Token));
			n->next = tokens;
			tokens = n;
			read_token();
			n->Text = scratch;
			scratch = calloc(max_string, sizeof(char));
			length = 0;
			c = read_token();
			n->Expression = scratch;
			scratch = calloc(max_string, sizeof(char));
			length = 0;
		}
		else
		{
			clear_scratch();
		}
	} while(EOF != c);
}


void hexify_string()
{
	char* table = "0123456789ABCDEF";
	int i = 0;

	while(0 != scratch[i])
	{
		fputc(table[scratch[i+1] / 16], stdout);
		fputc(table[scratch[i+1] % 16], stdout);
		i = i + 1;
	}

	/* Add null padding */
	while(0 != (i & 0x3))
	{
		fputc('0', stdout);
		fputc('0', stdout);
		i = i + 1;
	}
}


char* find_match()
{
	struct Token* p = tokens;
	while(NULL != p)
	{
		if(match(p->Text, scratch)) return p->Expression;
		p = p->next;
	}
	return NULL;
}


void generate_output()
{
	int c;
	char* r;
	int value;
	do
	{
		c = read_token();
		if(0 == length) continue;
		else if(in_set(scratch[0], ":!@$%&"))
		{
			file_print(scratch, stdout);
			fputc('\n', stdout);
		}
		else if(match(scratch, "DEFINE"))
		{
			clear_scratch();
			read_token();
			clear_scratch();
			c = read_token();
		}
		else if('"' == scratch[0])
		{
			hexify_string();
			fputc('\n', stdout);
		}
		else if('\'' == scratch[0])
		{
			file_print(scratch + 1, stdout);
			fputc('\n', stdout);
		}
		else
		{
			r = find_match();
			if(NULL != r)
			{
				file_print(r, stdout);
				fputc('\n', stdout);
			}
			else
			{
				value = numerate_string(scratch);
				if((0 != value) || ('0' == scratch[0]))
				{
					if((value > 65535) || (value < -32768))
					{
						file_print("number exceeds range -32768 to 65535\nPlease use '00 11 22 33' format instead to express such a large value\n", stdout);
						exit(EXIT_FAILURE);
					}
					fprintf(stdout, "%04X\n", (value & 0xFFFF));
				}
				else
				{
					file_print("\nUnknown other: ", stdout);
					file_print(scratch, stdout);
					file_print("\nAborting to prevent problems", stdout);
					exit(EXIT_FAILURE);
				}
			}
		}
		clear_scratch();
	} while(EOF != c);
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
	scratch = calloc(max_string, sizeof(char));

	source_file = fopen(argv[1], "r");

	collect_defines();
	rewind(source_file);
	generate_output();
}
