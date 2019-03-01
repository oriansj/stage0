/* -*- c-file-style: "linux";indent-tabs-mode:t -*- */
/* Copyright (C) 2017 Jeremiah Orians
 * Copyright (C) 2017 Jan Nieuwenhuizen <janneke@gnu.org>
 * This file is part of mescc-tools
 *
 * mescc-tools is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mescc-tools is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with mescc-tools.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdlib.h>

struct arguments
{
	struct arguments* next;
	int ip;
	int size;
	char* text;
};

int IP;
char* image;

int string_length(char* s)
{
	int c = 0;
	while(0 != s[0])
	{
		c = c + 1;
		s = s + 1;
	}

	c = (c | 0x3) + 1;
	return c;
}

void write_padded(char* s, int c, FILE* out)
{
	while(0 < c)
	{
		fputc(s[0], out);
		if(0 != s[0]) s = s + 1;
		c = c - 1;
	}
}

void write_int(int value, FILE* output)
{
	fputc((value >> 24), output);
	fputc(((value >> 16)%256), output);
	fputc(((value >> 8)%256), output);
	fputc((value % 256), output);
	IP = IP + 4;
}

void clone_file(FILE* in, FILE* out)
{
	if(NULL == in)
	{
		fprintf(stderr, "Was unable to open input binary: %s\naborting hard\n", image);
		exit(EXIT_FAILURE);
	}

	int c;
	for(c = fgetc(in); EOF != c; c = fgetc(in))
	{
		IP = IP + 1;
		fputc(c, out);
	}
}

struct arguments* reverse_list(struct arguments* head)
{
	struct arguments* root = NULL;
	while(NULL != head)
	{
		struct arguments* next = head->next;
		head->next = root;
		root = head;
		head = next;
	}
	return root;
}


/* Standard C main program */
int main(int argc, char **argv)
{
	IP = 0;
	int count = 0;
	int table;
	struct arguments* head = NULL;
	struct arguments* i;

	image = argv[1];
	clone_file(fopen(image, "r"), stdout);

	int option_index = 1;
	while(option_index < argc)
	{
		i = calloc(1, sizeof(struct arguments));
		i->next = head;
		head = i;
		head->ip = IP;
		head->text = argv[option_index];
		option_index = option_index + 1;
		head->size = string_length(head->text);
		IP = IP + head->size;
		count = count + 1;
	}

	head = reverse_list(head);

	for(i = head; NULL != i; i = i->next)
	{
		write_padded(i->text, i->size, stdout);
	}

	/* Get Address of the ARGV strings */
	table = IP;

	/* Write out pointers to argvs */
	for(i = head; NULL != i; i = i->next)
	{
		write_int(i->ip, stdout);
	}

	/* Do the NULL padding */
	write_int(0, stdout);

	/* Write out the ARGC */
	write_int(count, stdout);
	write_int(table, stdout);
	write_int(0, stdout);
	write_int(0, stdout);

	return EXIT_SUCCESS;
}
