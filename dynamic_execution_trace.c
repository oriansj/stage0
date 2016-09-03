#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* Unique instruction type */
struct instruction_trace
{
	uint64_t count;
	char name[255];
	struct instruction_trace* next;
	struct instruction_trace* prev;
};

static struct instruction_trace* traces;

struct instruction_trace* create_trace(char* c)
{
	struct instruction_trace* p;
	p = calloc(1, sizeof(struct instruction_trace));
	strncpy(p->name, c, 255);
	p->count = 1;
	return p;
}

struct instruction_trace* add_trace(struct instruction_trace* head, struct instruction_trace* p)
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
		add_trace(head->next, p);
	}
	return head;
}

bool update_trace(struct instruction_trace* p, char* c)
{
	if(0 == strncmp(p->name, c, 255))
	{
		p->count = p->count + 1;
		return true;
	}

	if(NULL != p->next)
	{
		return update_trace(p->next, c);
	}

	return false;
}

void record_trace(char* c)
{
	if((NULL != traces) && (update_trace(traces, c)))
	{
		return;
	}

	traces = add_trace(traces, create_trace(c));
}

struct instruction_trace* print_trace(struct instruction_trace* p)
{
	printf("%s\t%u\n", p->name, (unsigned int)p->count);
	return p->next;
}

void print_traces()
{
	struct instruction_trace* i = traces;
	while(NULL != i)
	{
		i = print_trace(i);
	}
}
