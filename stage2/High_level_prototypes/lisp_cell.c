#include "lisp.h"

struct cell* make_int(int a)
{
	struct cell* c = calloc(1, sizeof(cell));
	c->type = INT;
	c->value = a;
	return c;
}

struct cell* make_sym(char* name)
{
	struct cell* c = calloc(1, sizeof(cell));
	c->type = SYM;
	c->string = name;
	return c;
}

struct cell* make_cons(struct cell* a, struct cell* b)
{
	struct cell* c = calloc(1, sizeof(cell));
	c->type = CONS;
	c->car = a;
	c->cdr = b;
	return c;
}

struct cell* make_proc(struct cell* a, struct cell* b, struct cell* env)
{
	struct cell* c = calloc(1, sizeof(cell));
	c->type = PROC;
	c->car = a;
	c->cdr = b;
	c->env = env;
	return c;
}

struct cell* make_prim(void* fun)
{
	struct cell* c = calloc(1, sizeof(cell));
	c->type = PRIMOP;
	c->function = fun;
	return c;
}
