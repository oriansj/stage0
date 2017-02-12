#include "lisp.h"

struct cell *free_cells, *gc_block_start, *gc_block_end;
int64_t left_to_take;

int64_t cells_remaining()
{
	return left_to_take;
}

void update_remaining()
{
	int64_t count = 0;
	struct cell* i = free_cells;
	while(NULL != i)
	{
		count = count + 1;
		i = i->cdr;
	}
	left_to_take = count;
}

void reclaim_marked()
{
	struct cell* i;
	for(i= gc_block_start; i < gc_block_end; i = i + 1)
	{
		if(i->type & MARKED)
		{
			i->type = FREE;
			i->car = NULL;
			i->cdr = free_cells;
			i->env = NULL;
			free_cells = i;
		}
	}
}

void mark_all_cells()
{
	struct cell* i;
	for(i= gc_block_start; i < gc_block_end; i = i + 1)
	{
		/* if not in the free list */
		if(!(i->type & FREE))
		{
			/* Mark it */
			i->type = i->type | MARKED;
		}
	}
}

void unmark_cells(struct cell* list)
{
	for(; NULL != list; list = list->cdr)
	{
		list->type = list->type & ~MARKED;
		if((list->type & CONS)|| list->type & PROC )
		{
			unmark_cells(list->car);
		}
	}
}

void garbage_collect()
{
	mark_all_cells();
	unmark_cells(all_symbols);
	unmark_cells(top_env);
	reclaim_marked();
	update_remaining();
}

void garbage_init()
{
	int number_of_Cells = 1000000;
	gc_block_start = calloc(number_of_Cells + 1, sizeof(cell));
	gc_block_end = gc_block_start + number_of_Cells;
	free_cells = NULL;
	garbage_collect();
}

struct cell* pop_cons()
{
	if(NULL == free_cells)
	{
		printf("OOOPS we ran out of cells");
		exit(EXIT_FAILURE);
	}
	struct cell* i;
	i = free_cells;
	free_cells = i->cdr;
	i->cdr = NULL;
	left_to_take = left_to_take - 1;
	return i;
}

struct cell* make_int(int a)
{
	struct cell* c = pop_cons();
	c->type = INT;
	c->value = a;
	return c;
}

struct cell* make_sym(char* name)
{
	struct cell* c = pop_cons();
	c->type = SYM;
	c->string = name;
	return c;
}

struct cell* make_cons(struct cell* a, struct cell* b)
{
	struct cell* c = pop_cons();
	c->type = CONS;
	c->car = a;
	c->cdr = b;
	return c;
}

struct cell* make_proc(struct cell* a, struct cell* b, struct cell* env)
{
	struct cell* c = pop_cons();
	c->type = PROC;
	c->car = a;
	c->cdr = b;
	c->env = env;
	return c;
}

struct cell* make_prim(void* fun)
{
	struct cell* c = pop_cons();
	c->type = PRIMOP;
	c->function = fun;
	return c;
}
