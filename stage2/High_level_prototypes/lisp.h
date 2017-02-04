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
struct cell *all_symbols, *top_env, *nil, *tee, *quote, *s_if, *s_lambda, *s_define, *s_setb, *s_cond, *s_begin;
