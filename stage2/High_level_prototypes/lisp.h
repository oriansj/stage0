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
#include <stdarg.h>
#include <string.h>
#include <ctype.h>

enum otype
{
	FREE = 1,
	MARKED = (1 << 1),
	INT = (1 << 2),
	SYM = (1 << 3),
	CONS = (1 << 4),
	PROC = (1 << 5),
	PRIMOP = (1 << 6),
	ASCII = (1 << 7)
};

typedef struct cell* (*Operation)(struct cell *);

typedef struct cell
{
	enum otype type;
	union
	{
		struct cell* car;
		int value;
		char* string;
		Operation function;
	};
	struct cell* cdr;
	struct cell* env;
} cell;

#define MAXLEN 256


struct cell* make_cons(struct cell* a, struct cell* b);

/* Global objects */
struct cell *all_symbols;
struct cell *top_env;
struct cell *nil;
struct cell *tee;
struct cell *quote;
struct cell *s_if;
struct cell *s_lambda;
struct cell *s_define;
struct cell *s_setb;
struct cell *s_cond;
struct cell *s_begin;
struct cell *s_let;
FILE* output;
