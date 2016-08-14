#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#define max_string 63

FILE* source_file;
bool Reached_EOF;
uint32_t ip;

struct Token
{
	struct Token* next;
	uint8_t type;
	char* Text;
	char* Expression;
};

enum type
{
	macro = 1,
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

	return p;
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
	}
	else
	{
		addToken(head->next, p);
	}
	return head;
}

void purge_lineComment()
{
	int c = fgetc(source_file);
	while((10 != c) && (13 != c))
	{
		c = fgetc(source_file);
	}
}

struct Token* Tokenize_Line(struct Token* head)
{
	char* store = calloc(max_string + 1, sizeof(char));
	int32_t c;
	uint32_t i;
	struct Token* p = newToken();

Restart:
	for(i = 0; i < max_string; i = i + 1)
	{
		c = fgetc(source_file);
		if(-1 == c)
		{
			Reached_EOF = true;
			goto Token_complete;
		}
		else if((10 == c) || (13 == c))
		{
			if(1 > i)
			{
				goto Restart;
			}
			else
			{
				goto Token_complete;
			}
		}
		else if((35 == c) || (59 == c))
		{
			purge_lineComment();
			goto Restart;
		}
		else if((32 == c) || (9 == c))
		{
			if(1 > i)
			{
				goto Restart;
			}
			else
			{
				goto Token_complete;
			}
		}
		else
		{
			store[i] = (char)c;
		}
	}

Token_complete:
	p->Text = store;
	return addToken(head, p);
}

void setExpression(struct Token* p, char match[], char Exp[])
{
	if(NULL != p->next)
	{
		setExpression(p->next, match, Exp);
	}

	/* Leave macros alone */
	if((p->type & macro))
	{
		return;
	}

	/* Only if there is an exact match replace */
	if(0 == strncmp(p->Text, match, max_string))
	{
		p->Expression = Exp;
	}
}

void identify_macros(struct Token* p)
{
	if(0 == strncmp(p->Text, "DEFINE", max_string))
	{
		p->type = macro;
		p->next->type = macro;
		p->next->next->type = macro;
	}

	if(NULL != p->next)
	{
		identify_macros(p->next);
	}
}

void line_macro(struct Token* p)
{
	if(0 == strncmp(p->Text, "DEFINE", max_string))
	{
		setExpression(p, p->next->Text, p->next->next->Text);
	}

	if(NULL != p->next)
	{
		line_macro(p->next);
	}
}

void preserve_other(struct Token* p)
{
	if(NULL != p->next)
	{
		preserve_other(p->next);
	}

	if((NULL == p->Expression) && !(p->type & macro))
	{
		p->Expression = p->Text;
	}
}

uint16_t numerate_string(char a[])
{
	char *ptr;
	return (uint16_t)strtol(a, &ptr, 0);
}

void eval_immediates(struct Token* p)
{
	if(NULL != p->next)
	{
		eval_immediates(p->next);
	}

	if((NULL == p->Expression) && !(p->type & macro))
	{
		uint16_t value;
		value = numerate_string(p->Text);

		if(('0' == p->Text[0]) || (0 != value))
		{
			char* c = calloc(5, sizeof(char));
			sprintf(c, "%04x", value);
			p->Expression = c;
		}
	}
}

void print_hex(struct Token* p)
{
	if(NULL != p->Expression)
	{
		fprintf(stdout, "\n%s", p->Expression);
	}

	if(NULL != p->next)
	{
		print_hex(p->next);
	}
	else
	{
		fprintf(stdout, "\n");
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

	identify_macros(head);
	line_macro(head);
	eval_immediates(head);
	preserve_other(head);
	print_hex(head);

	return EXIT_SUCCESS;
}
