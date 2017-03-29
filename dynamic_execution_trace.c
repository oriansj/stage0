/* This file is part of stage0.
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
