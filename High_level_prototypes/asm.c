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
#define max_string 255

FILE* source_file;
bool Reached_EOF;
uint32_t ip;

struct Token
{
	struct Token* next;
	struct Token* prev;
	uint32_t type;
	uint32_t size;
	uint32_t address;
	char Text[max_string + 1];
	char Expression[max_string + 1];
};

enum type
{
	EOL = 1,
	comment = (1 << 1),
	label = (1 << 2),
	string = (1 << 3),
	absolute_address = (1 << 4)
};

struct Token* newToken()
{
	struct Token* p;

	p = calloc (1, sizeof (struct Token));
	if (NULL == p)
	{
		fprintf (stderr, "calloc failed.\n");
		exit (EXIT_FAILURE);
	}

	p->size = -1;
	p->address = 0;

	return p;
}

void setText(struct Token* p, char Text[])
{
	strncpy(p->Text, Text, max_string);
}

struct Token* addToken(struct Token* head, struct Token* p)
{
	if(NULL == head)
	{
		return p;
	}
	if(NULL == head->next)
	{
		head->next = p;
		p->prev = head;
	}
	else
	{
		addToken(head->next, p);
	}
	return head;
}

struct Token* Tokenize_Line(struct Token* head)
{
	char store[max_string + 1] = {0};
	int32_t c;
	uint32_t i;
	struct Token* p = newToken();

Restart:
	p->type = p->type & ~(comment);

	for(i = 0; i < max_string; i = i + 1)
	{
		c = fgetc(source_file);
		if(-1 == c)
		{
			Reached_EOF = true;
			goto Token_complete;
		}
		else if((10 == c) || (13 == c))
		{ /* Deal with \n and \r */
			p->type = p->type | EOL;
			if(1 > i)
			{
				goto Restart;
			}
			else
			{
				goto Token_complete;
			}
		}
		else if((!(p->type & comment) && !(p->type & string)) && ((32 == c) || (9 == c)))
		{ /* Deal with " " and \t */
			if(1 > i)
			{
				goto Restart;
			}
			else
			{
				goto Token_complete;
			}
		}
		else if((!(p->type & comment ) && !(p->type & string)) && ((35 == c) ||(59 == c)))
		{ /* Deal with # and ; */
			p->type = p->type | comment;
			store[i] = (char)c;
		}
		else if((!(p->type & comment ) && !(p->type & string)) && ((34 == c) ||(39 == c)))
		{ /* Deal with " and ' */
			p->type = p->type | string;
			store[i] = (char)c;
		}
		else if((!(p->type & comment ) && !(p->type & string)) && (58 == c))
		{ /* Deal with : */
			p->type = p->type | label;
			store[i] = (char)c;
		}
		else if((!(p->type & comment ) && !(p->type & string)) && (38 == c))
		{ /* Deal with & */
			p->type = p->type | absolute_address;
			store[i] = (char)c;
		}
		else if((p->type & string) && ((34 == c) ||(39 == c)))
		{
			goto Token_complete;
		}
		else
		{
			store[i] = (char)c;
		}
	}

Token_complete:
	setText(p, store);
	return addToken(head, p);
}

void setExpression(struct Token* p, char match[], char Exp[], uint32_t size)
{
	if(NULL != p->next)
	{
		setExpression(p->next, match, Exp, size);
	}

	/* Leave Comments alone */
	if((p->type & comment))
	{
		return;
	}

	/* Only if there is an exact match replace */
	if(0 == strncmp(p->Text, match, max_string))
	{
		strncpy(p->Expression, Exp, max_string);
		p->size = size;
	}
}

void assemble(struct Token* p)
{
	/* Registers */
	setExpression(p, "R0", "0", 0);
	setExpression(p, "R1", "1", 0);
	setExpression(p, "R2", "2", 0);
	setExpression(p, "R3", "3", 0);
	setExpression(p, "R4", "4", 0);
	setExpression(p, "R5", "5", 0);
	setExpression(p, "R6", "6", 0);
	setExpression(p, "R7", "7", 0);
	setExpression(p, "R8", "8", 0);
	setExpression(p, "R9", "9", 0);
	setExpression(p, "R10", "A", 0);
	setExpression(p, "R11", "B", 0);
	setExpression(p, "R12", "C", 0);
	setExpression(p, "R13", "D", 0);
	setExpression(p, "R14", "E", 0);
	setExpression(p, "R15", "F", 0);

	/* 4OP Integer Group */
	setExpression(p, "ADD.CI", "0100", 4);
	setExpression(p, "ADD.CO", "0101", 4);
	setExpression(p, "ADD.CIO", "0102", 4);
	setExpression(p, "ADDU.CI", "0103", 4);
	setExpression(p, "ADDU.CO", "0104", 4);
	setExpression(p, "ADDU.CIO", "0105", 4);
	setExpression(p, "SUB.BI", "0106", 4);
	setExpression(p, "SUB.BO", "0107", 4);
	setExpression(p, "SUB.BIO", "0108", 4);
	setExpression(p, "SUBU.BI", "0109", 4);
	setExpression(p, "SUBU.BO", "010A", 4);
	setExpression(p, "SUBU.BIO", "010B", 4);
	setExpression(p, "MULTIPLY", "010C", 4);
	setExpression(p, "MULTIPLYU", "010D", 4);
	setExpression(p, "DIVIDE", "010E", 4);
	setExpression(p, "DIVIDEU", "010F", 4);
	setExpression(p, "MUX", "0110", 4);
	setExpression(p, "NMUX", "0111", 4);
	setExpression(p, "SORT", "0112", 4);
	setExpression(p, "SORTU", "0113", 4);

	/* 3OP Integer Group */
	setExpression(p, "ADD", "05000", 4);
	setExpression(p, "ADDU", "05001", 4);
	setExpression(p, "SUB", "05002", 4);
	setExpression(p, "SUBU", "05003", 4);
	setExpression(p, "CMP", "05004", 4);
	setExpression(p, "CMPU", "05005", 4);
	setExpression(p, "MUL", "05006", 4);
	setExpression(p, "MULH", "05007", 4);
	setExpression(p, "MULU", "05008", 4);
	setExpression(p, "MULUH", "05009", 4);
	setExpression(p, "DIV", "0500A", 4);
	setExpression(p, "MOD", "0500B", 4);
	setExpression(p, "DIVU", "0500C", 4);
	setExpression(p, "MODU", "0500D", 4);
	setExpression(p, "MAX", "05010", 4);
	setExpression(p, "MAXU", "05011", 4);
	setExpression(p, "MIN", "05012", 4);
	setExpression(p, "MINU", "05013", 4);
	setExpression(p, "AND", "05020", 4);
	setExpression(p, "OR", "05021", 4);
	setExpression(p, "XOR", "05022", 4);
	setExpression(p, "NAND", "05023", 4);
	setExpression(p, "NOR", "05024", 4);
	setExpression(p, "XNOR", "05025", 4);
	setExpression(p, "MPQ", "05026", 4);
	setExpression(p, "LPQ", "05027", 4);
	setExpression(p, "CPQ", "05028", 4);
	setExpression(p, "BPQ", "05029", 4);
	setExpression(p, "SAL", "05030", 4);
	setExpression(p, "SAR", "05031", 4);
	setExpression(p, "SL0", "05032", 4);
	setExpression(p, "SR0", "05033", 4);
	setExpression(p, "SL1", "05034", 4);
	setExpression(p, "SR1", "05035", 4);
	setExpression(p, "ROL", "05036", 4);
	setExpression(p, "ROR", "05037", 4);
	setExpression(p, "LOADX", "05038", 4);
	setExpression(p, "LOADX8", "05039", 4);
	setExpression(p, "LOADXU8", "0503A", 4);
	setExpression(p, "LOADX16", "0503B", 4);
	setExpression(p, "LOADXU16", "0503C", 4);
	setExpression(p, "LOADX32", "0503D", 4);
	setExpression(p, "LOADXU32", "0503E", 4);
	setExpression(p, "STOREX", "05048", 4);
	setExpression(p, "STOREX8", "05049", 4);
	setExpression(p, "STOREX16", "0504A", 4);
	setExpression(p, "STOREX32", "0504B", 4);
	setExpression(p, "CMPJUMP.G", "05050", 4);
	setExpression(p, "CMPJUMP.GE", "05051", 4);
	setExpression(p, "CMPJUMP.E", "05052", 4);
	setExpression(p, "CMPJUMP.NE", "05053", 4);
	setExpression(p, "CMPJUMP.LE", "05054", 4);
	setExpression(p, "CMPJUMP.L", "05055", 4);
	setExpression(p, "CMPJUMPU.G", "05060", 4);
	setExpression(p, "CMPJUMPU.GE", "05061", 4);
	setExpression(p, "CMPJUMPU.LE", "05064", 4);
	setExpression(p, "CMPJUMPU.L", "05065", 4);


	/* 2OP Integer Group */
	setExpression(p, "NEG", "090000", 4);
	setExpression(p, "ABS", "090001", 4);
	setExpression(p, "NABS", "090002", 4);
	setExpression(p, "SWAP", "090003", 4);
	setExpression(p, "COPY", "090004", 4);
	setExpression(p, "MOVE", "090005", 4);
	setExpression(p, "NOT", "090006", 4);
	setExpression(p, "BRANCH", "090100", 4);
	setExpression(p, "CALL", "090101", 4);
	setExpression(p, "PUSHR", "090200", 4);
	setExpression(p, "PUSH8", "090201", 4);
	setExpression(p, "PUSH16", "090202", 4);
	setExpression(p, "PUSH32", "090203", 4);
	setExpression(p, "POPR", "090280", 4);
	setExpression(p, "POP8", "090281", 4);
	setExpression(p, "POPU8", "090282", 4);
	setExpression(p, "POP16", "090283", 4);
	setExpression(p, "POPU16", "090284", 4);
	setExpression(p, "POP32", "090285", 4);
	setExpression(p, "POPU32", "090286", 4);
	setExpression(p, "CMPSKIP.G", "090300", 4);
	setExpression(p, "CMPSKIP.GE", "090301", 4);
	setExpression(p, "CMPSKIP.E", "090302", 4);
	setExpression(p, "CMPSKIP.NE", "090303", 4);
	setExpression(p, "CMPSKIP.LE", "090304", 4);
	setExpression(p, "CMPSKIP.L", "090305", 4);
	setExpression(p, "CMPSKIPU.G", "090380", 4);
	setExpression(p, "CMPSKIPU.GE", "090381", 4);
	setExpression(p, "CMPSKIPU.LE", "090384", 4);
	setExpression(p, "CMPSKIPU.L", "090385", 4);


	/* 1OP Group */
	setExpression(p, "READPC", "0D00000", 4);
	setExpression(p, "READSCID", "0D00001", 4);
	setExpression(p, "FALSE", "0D00002", 4);
	setExpression(p, "TRUE", "0D00003", 4);
	setExpression(p, "JSR_COROUTINE", "0D01000", 4);
	setExpression(p, "RET", "0D01001", 4);
	setExpression(p, "PUSHPC", "0D02000", 4);
	setExpression(p, "POPPC", "0D02001", 4);

	/* 2OPI Group */
	setExpression(p, "ADDI", "E1000E", 6);
	setExpression(p, "ADDUI", "E1000F", 6);
	setExpression(p, "SUBI", "E10010", 6);
	setExpression(p, "SUBUI", "E10011", 6);
	setExpression(p, "CMPI", "E10012", 6);
	setExpression(p, "LOAD", "E10013", 6);
	setExpression(p, "LOAD8", "E10014", 6);
	setExpression(p, "LOADU8", "E10015", 6);
	setExpression(p, "LOAD16", "E10016", 6);
	setExpression(p, "LOADU16", "E10017", 6);
	setExpression(p, "LOAD32", "E10018", 6);
	setExpression(p, "LOADU32", "E10019", 6);
	setExpression(p, "CMPUI", "E1001F", 6);
	setExpression(p, "STORE", "E10020", 6);
	setExpression(p, "STORE8", "E10021", 6);
	setExpression(p, "STORE16", "E10022", 6);
	setExpression(p, "STORE32", "E10023", 6);
	setExpression(p, "ANDI", "E100B0", 6);
	setExpression(p, "ORI", "E100B1", 6);
	setExpression(p, "XORI", "E100B2", 6);
	setExpression(p, "NANDI", "E100B3", 6);
	setExpression(p, "NORI", "E100B4", 6);
	setExpression(p, "XNORI", "E100B5", 6);
	setExpression(p, "CMPJUMPI.G", "E100C0", 6);
	setExpression(p, "CMPJUMPI.GE", "E100C1", 6);
	setExpression(p, "CMPJUMPI.E", "E100C2", 6);
	setExpression(p, "CMPJUMPI.NE", "E100C3", 6);
	setExpression(p, "CMPJUMPI.LE", "E100C4", 6);
	setExpression(p, "CMPJUMPI.L", "E100C5", 6);
	setExpression(p, "CMPJUMPUI.G", "E100D0", 6);
	setExpression(p, "CMPJUMPUI.GE", "E100D1", 6);
	setExpression(p, "CMPJUMPUI.LE", "E100D4", 6);
	setExpression(p, "CMPJUMPUI.L", "E100D5", 6);

	/* 1OPI Group */
	setExpression(p, "JUMP.C", "E0002C0", 6);
	setExpression(p, "JUMP.B", "E0002C1", 6);
	setExpression(p, "JUMP.O", "E0002C2", 6);
	setExpression(p, "JUMP.G", "E0002C3", 6);
	setExpression(p, "JUMP.GE", "E0002C4", 6);
	setExpression(p, "JUMP.E", "E0002C5", 6);
	setExpression(p, "JUMP.NE", "E0002C6", 6);
	setExpression(p, "JUMP.LE", "E0002C7", 6);
	setExpression(p, "JUMP.L", "E0002C8", 6);
	setExpression(p, "JUMP.Z", "E0002C9", 6);
	setExpression(p, "JUMP.NZ", "E0002CA", 6);
	setExpression(p, "JUMP.P", "E0002CB", 6);
	setExpression(p, "JUMP.NP", "E0002CC", 6);
	setExpression(p, "CALLI", "E0002D0", 6);
	setExpression(p, "LOADI", "E0002D1", 6);
	setExpression(p, "LOADUI", "E0002D2", 6);
	setExpression(p, "SALI", "E0002D3", 6);
	setExpression(p, "SARI", "E0002D4", 6);
	setExpression(p, "SL0I", "E0002D5", 6);
	setExpression(p, "SR0I", "E0002D6", 6);
	setExpression(p, "SL1I", "E0002D7", 6);
	setExpression(p, "SR1I", "E0002D8", 6);
	setExpression(p, "LOADR", "E0002E0", 6);
	setExpression(p, "LOADR8", "E0002E1", 6);
	setExpression(p, "LOADRU8", "E0002E2", 6);
	setExpression(p, "LOADR16", "E0002E3", 6);
	setExpression(p, "LOADRU16", "E0002E4", 6);
	setExpression(p, "LOADR32", "E0002E5", 6);
	setExpression(p, "LOADRU32", "E0002E6", 6);
	setExpression(p, "STORER", "E0002F0", 6);
	setExpression(p, "STORER8", "E0002F1", 6);
	setExpression(p, "STORER16", "E0002F2", 6);
	setExpression(p, "STORER32", "E0002F3", 6);
	setExpression(p, "CMPSKIPI.G", "E000A00", 6);
	setExpression(p, "CMPSKIPI.GE", "E000A01", 6);
	setExpression(p, "CMPSKIPI.E", "E000A02", 6);
	setExpression(p, "CMPSKIPI.NE", "E000A03", 6);
	setExpression(p, "CMPSKIPI.LE", "E000A04", 6);
	setExpression(p, "CMPSKIPI.L", "E000A05", 6);
	setExpression(p, "CMPSKIPUI.G", "E000A10", 6);
	setExpression(p, "CMPSKIPUI.GE", "E000A11", 6);
	setExpression(p, "CMPSKIPUI.LE", "E000A14", 6);
	setExpression(p, "CMPSKIPUI.L", "E000A15", 6);

	/* 0OPI Group */
	setExpression(p, "JUMP", "3C00", 4);

	/* HALCODE Group */
	setExpression(p, "FOPEN_READ", "42100000", 4);
	setExpression(p, "FOPEN_WRITE", "42100001", 4);
	setExpression(p, "FCLOSE", "42100002", 4);
	setExpression(p, "REWIND", "42100003", 4);
	setExpression(p, "FSEEK", "42100004", 4);
	setExpression(p, "FGETC", "42100100", 4);
	setExpression(p, "FPUTC", "42100200", 4);
	setExpression(p, "HAL_MEM", "42110000", 4);

	/* 0OP Group*/
	setExpression(p, "NOP", "00000000", 4);
	setExpression(p, "HALT", "FFFFFFFF", 4);
}

void assign_addresses(struct Token* p)
{
	if(-1 == (int32_t)p->size)
	{
		p->address = ip;
	}
	else if(0 == p->size)
	{
		p->address = p->prev->address;
	}
	else
	{
		p->address = ip;
		ip = ip + p->size;
	}

	if(NULL != p->next)
	{
		assign_addresses(p->next);
	}
}

uint32_t get_address(struct Token* p, char match[])
{
	if((label & p->type) && (0 == strncmp(p->Text, match, max_string)))
	{
		return p->address;
	}

	if(NULL != p->next)
	{
		return get_address(p->next, match);
	}

	return -1;
}

void update_jumps(struct Token* head, struct Token* p)
{
	uint32_t dest = -1;

	/* Find matching label */
	if(('@' == p->Text[0]) || ('$' == p->Text[0]) || ('&' == p->Text[0]))
	{
		char temp[256] = {0};
		strncpy(temp, p->Text, max_string);
		temp[0] = ':';
		dest = get_address(head, temp);
	}

	/* If match is found */
	if(-1 != (int32_t)dest)
	{
		/* Deal with Relative 16bit jumps */
		if('@' == p->Text[0])
		{
			int16_t dist = 0;
			dist = dest - p->address;
			sprintf(p->Expression, "%04x", (uint16_t)dist);
		}

		/* Deal with Absolute 16bit jumps */
		if('$' == p->Text[0])
		{
			int16_t dist = 0;
			dist = dest;
			sprintf(p->Expression, "%04x", (uint16_t)dist);
		}

		/* Deal with storing Pointers to absolute addresses */
		if('&' == p->Text[0])
		{
			sprintf(p->Expression, "%08x", dest);
		}
	}

	if(NULL != p->next)
	{
		update_jumps(head, p->next);
	}
}

void hexify_string(char* s, char* d, int max)
{
	char table[16] = {0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46};
	int i = ((strnlen(s, max)/4) + 1) * 8;

	while(0 < i)
	{
		i = i - 1;
		d[i] = 0x30;
	}

	while( i < max)
	{
		if(0 == s[i])
		{
			i = max;
		}
		else
		{
			d[2*i]  = table[s[i] / 16];
			d[2*i + 1] = table[s[i] % 16];
			i = i + 1;
		}
	}
}

int get_hex_size(char* a)
{
	int count = 0;
	while(0 != a[0])
	{
		switch(a[0])
		{
			case '0' ... '9':
			case 'A' ... 'F':
			case 'a' ... 'f': count = count + 1; break;
			default: break;
		}
		a = a + 1;
	}
	return (count / 2);
}

void process_string(struct Token* p)
{
	/* Adjust hex and ascii strings */
	if(p->type & string)
	{
		if('\'' == p->Text[0])
		{ /* Handle Hex strings */
			strncpy(p->Expression, p->Text + 1, max_string);
			p->size = get_hex_size(p->Expression);
		}
		else if('"' == p->Text[0])
		{ /* Handle ASCII strings */
			hexify_string(p->Text + 1, p->Expression, max_string/2);
			p->size = strnlen(p->Expression, max_string)/2;
		}
	}

	/* Deal with special case of absolute addresses */
	if(p->type & absolute_address)
	{	/* Absolute addresses are always the Register size */
		p->size = 4;
		/* Values are set when jumps are calculated */
	}

	if(NULL != p->next)
	{
		process_string(p->next);
	}
}

uint16_t numerate_string(char a[])
{
	char *ptr;
	return (uint16_t)strtol(a, &ptr, 0);
}

void eval_immediates(struct Token* p)
{
	char tmp[max_string + 1] = {0};

	if(0 == strncmp(p->Expression, tmp, max_string))
	{
		uint16_t value;
		value = numerate_string(p->Text);

		if(('0' == p->Text[0]) || (0 != value))
		{
			sprintf(p->Expression, "%04x", value & 0xFFFF);
		}
	}

	if(NULL != p->next)
	{
		eval_immediates(p->next);
	}
}

void print_text(struct Token* p)
{
	fprintf(stdout, " %s", p->Text);
	if(34 == p->Text[0])
	{
		fprintf(stdout, "\"");
	}
	else if(39 == p->Text[0])
	{
		fprintf(stdout, "'");
	}
	else if(':' == p->Text[0])
	{
		fprintf(stdout, " ; offset = %x", p->address);
	}

	if((NULL != p->next) && !((p->type & EOL)))
	{
		print_text(p->next);
	}
}

struct Token* print_Expression(struct Token* p)
{
	if(!(p->type & comment))
	{
		fprintf(stdout, "%s", p->Expression);
	}
	else
	{
		return p->next;
	}

	if((NULL != p->next) && !((p->type & EOL)))
	{
		return print_Expression(p->next);
	}

	return p->next;
}

void print_hex(struct Token* p)
{
	struct Token* n = NULL;
	fprintf(stdout, "#");
	print_text(p);
	fprintf(stdout, "\n");
	n = print_Expression(p);
	fprintf(stdout, "\n");

	if(NULL != n)
	{
		print_hex(n);
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

	Reached_EOF = false;
	ip = 0;
	struct Token* head = NULL;
	while(!Reached_EOF)
	{
		head = Tokenize_Line(head);
	}

	assemble(head);
	process_string(head);
	assign_addresses(head);
	update_jumps(head, head);
	eval_immediates(head);
	print_hex(head);

	return EXIT_SUCCESS;
}
