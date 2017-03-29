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

#include "lisp.h"
#include <stdbool.h>
#include <stdint.h>
#define max_string 255

FILE* source_file;
bool Reached_EOF;

static struct cell* token_stack;
struct cell* make_sym(char* name);
struct cell* intern(char *name);
struct cell* findsym(char *name);

struct cell* append_Cell(struct cell* head, struct cell* tail)
{
	if(NULL == head)
	{
		return tail;
	}

	if(NULL == head->cdr)
	{
		head->cdr = tail;
		return head;
	}

	append_Cell(head->cdr, tail);
	return head;
}

/****************************************************************
 * def tokenize(s):                                             *
 *      "Convert a string into a list of tokens."               *
 *      return s.replace('(',' ( ').replace(')',' ) ').split()  *
 ****************************************************************/

struct cell* tokenize(struct cell* head, char* fullstring, int32_t size)
{
	int32_t c;
	int32_t i = 0;
	bool done = false;
	if((0 >= size) || (0 == fullstring[0]))
	{
		return head;
	}

	char *store = calloc(max_string + 1, sizeof(char));

	do
	{
		c = fullstring[i];
		if((i > size) || (max_string <= i))
		{
			done = true;
		}
		else
		{
			if((' ' == c) || ('\t' == c) || ('\n' == c) | ('\r' == c))
			{
				i = i + 1;
				done = true;
			}
			else
			{
				store[i] = c;
				i = i + 1;
			}
		}
	} while(!done);

	if(i > 1)
	{
		head = append_Cell(head, make_sym(store));
	}
	else
	{
		free(store);
	}
	head = tokenize(head, (fullstring+i), (size - i));
	return head;
}


bool is_integer(char* a)
{
	if(('0' <= a[0]) && ('9' >= a[0]))
	{
		return true;
	}

	if('-' == a[0])
	{
		if(('0' <= a[1]) && ('9' >= a[1]))
		{
			return true;
		}
	}

	return false;
}


/********************************************************************
 * def atom(token):                                                 *
 *     "Numbers become numbers; every other token is a symbol."     *
 *     try: return int(token)                                       *
 *     except ValueError:                                           *
 *         try: return float(token)                                 *
 *         except ValueError:                                       *
 *             return Symbol(token)                                 *
 ********************************************************************/

struct cell* atom(struct cell* a)
{
	/* Check for quotes */
	if('\'' == a->string[0])
	{
		a->string = a->string + 1;
		return make_cons(quote, make_cons(a, nil));
	}
	/* Check for integer */
	if(is_integer(a->string))
	{
		a->type = INT;
		a->value = atoi(a->string);
		return a;
	}

	/* Check for functions */
	struct cell* op = findsym(a->string);
	if(nil != op)
	{
		return op->car;
	}

	/* Assume new symbol */
	all_symbols = make_cons(a, all_symbols);
	return a;
}

/****************************************************************
 * def read_from_tokens(tokens):                                *
 *     "Read an expression from a sequence of tokens."          *
 *     if len(tokens) == 0:                                     *
 *         raise SyntaxError('unexpected EOF while reading')    *
 *     token = tokens.pop(0)                                    *
 *     if '(' == token:                                         *
 *         L = []                                               *
 *         while tokens[0] != ')':                              *
 *             L.append(read_from_tokens(tokens))               *
 *         tokens.pop(0) # pop off ')'                          *
 *         return L                                             *
 *     elif ')' == token:                                       *
 *         raise SyntaxError('unexpected )')                    *
 *     else:                                                    *
 *         return atom(token)                                   *
 ****************************************************************/

struct cell* readlist();
struct cell* readobj()
{
	cell* head = token_stack;
	token_stack = head->cdr;
	head->cdr = NULL;
	if (! strncmp("(", head->string, max_string))
	{
		return readlist();
	}

	return atom(head);
}

struct cell* readlist()
{
	cell* head = token_stack;
	if (! strncmp(")", head->string, max_string))
	{
		token_stack = head->cdr;
		return nil;
	}

	cell* tmp = readobj();
//	token_stack = head->cdr;
	return make_cons(tmp,readlist());
}

/****************************************************
 * def parse(program):                              *
 *     "Read a Scheme expression from a string."    *
 *     return read_from_tokens(tokenize(program))   *
 ****************************************************/

struct cell* parse(char* program, int32_t size)
{
	token_stack = tokenize(NULL, program, size);
	if(NULL == token_stack)
	{
		return nil;
	}
	return readobj();
}

uint32_t Readline(FILE* source_file, char* temp)
{
	char store[max_string + 2] = {0};
	int32_t c;
	uint32_t i;
	uint32_t depth = 0;

	for(i = 0; i < max_string; i = i + 1)
	{
		c = fgetc(source_file);
		if(-1 == c)
		{
			exit(EXIT_SUCCESS);
		}
		else if((0 == depth) && ((10 == c) || (13 == c) || (32 == c) || (9 == c)))
		{
			goto Line_complete;
		}
		else if(('(' == c) || (')' == c))
		{
			if('(' == c)
			{
				depth = depth + 1;
			}

			if(')' == c)
			{
				depth = depth - 1;
			}

			store[i] = ' ';
			store[i+1] = c;
			store[i+2] = ' ';
			i = i + 2;
		}
		else
		{
			store[i] = (char)c;
		}
	}

Line_complete:
	if(1 > i)
	{
		return Readline(source_file, temp);
	}

	strncpy(temp, store, max_string);
	return i;
}
