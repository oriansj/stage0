/****************************************
 * Shitty Expensive Typewriter			*
 * A more shitty remake of the PDP-1's	*
 * Expensive Typewriter program		*
 ****************************************/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#define max_string 255

bool Reached_EOF;
char temp[max_string + 1];

struct Line
{
	char Text[max_string + 1];
	struct Line* next;
	struct Line* prev;
};

struct Line* newLine()
{
	struct Line* p;

	p = calloc (1, sizeof (struct Line));
	if (NULL == p)
	{
		fprintf (stderr, "calloc failed.\n");
		exit (EXIT_FAILURE);
	}

	return p;
}

void setText(struct Line* p, char Text[])
{
	strncpy(p->Text, Text, max_string);
}

struct Line* addLine(struct Line* head, struct Line* p)
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
		addLine(head->next, p);
	}
	return head;
}

void Readline(FILE* source_file)
{
	char store[max_string + 1] = {0};
	int32_t c;
	uint32_t i;

	for(i = 0; i < max_string; i = i + 1)
	{
		c = fgetc(source_file);
		if(-1 == c)
		{
			Reached_EOF = true;
			goto Line_complete;
		}
		else if((10 == c) || (13 == c))
		{
			store[i] = (char)(10);
			goto Line_complete;
		}
		else
		{
			store[i] = (char)c;
		}
	}

Line_complete:
	strncpy(temp, store, max_string);
}

void WriteOut(struct Line* head, FILE* source_file)
{
	if(NULL == head)
	{
		return;
	}

	fputs(head->Text, source_file);
	WriteOut(head->next, source_file);
}

struct Line* GetHead(struct Line* p)
{
	if(NULL == p)
	{
		return NULL;
	}

	if(NULL == p->prev)
	{
		return p;
	}

	return GetHead(p->prev);
}

struct Line* RemoveLine(struct Line* p)
{
	if((NULL == p->prev) && (NULL == p->next))
	{
		return NULL;
	}

	if(NULL != p->next)
	{
		p->next->prev = p->prev;
	}

	if(NULL != p->prev)
	{
		p->prev->next = p->next;
		return p->prev;
	}

	return p->next;
}

struct Line* InsertLine(struct Line* head)
{
	struct Line* p;
	p = newLine();

	if(NULL == head)
	{
		return p;
	}

	if(NULL != head->prev)
	{
		head->prev->next = p;
	}

	p->prev = head->prev;
	p->next = head;
	head->prev = p;
	return head;
}

struct Line* AppendLine(struct Line* head)
{
	struct Line* p;
	p = newLine();

	if(NULL == head)
	{
		return p;
	}

	if(NULL != head->next)
	{
		head->next->prev = p;
	}

	p->next = head->next;
	p->prev = head;
	head->next = p;
	return head;
}

void Editor_loop(struct Line* head, FILE* source_file)
{
	Readline(stdin);
	switch(temp[0])
	{
		case 'a':
		{
			AppendLine(head);
			break;
		}
		case 'b':
		{
			if(NULL != head->prev)
			{
				Editor_loop(head->prev, source_file);
			}
			break;
		}
		case 'd':
		{
			head = RemoveLine(head);
			break;
		}
		case 'e':
		{
			Readline(stdin);
			setText(head, temp);
			break;
		}
		case 'f':
		{
			if(NULL != head->next)
			{
				Editor_loop(head->next, source_file);
			}
			break;
		}
		case 'i':
		{
			InsertLine(head);
			break;
		}
		case 'p':
		{
			fputs(head->Text, stdout);
			break;
		}
		case 'q':
		{
			exit(EXIT_SUCCESS);
		}
		case 'w':
		{
			rewind(source_file);
			WriteOut(GetHead(head), source_file);
			break;
		}
		case '?':
		default:
		{
			fputs("? for help\ne to edit the line\nd to delete the line\np print line\nf to move to next line\nb to move to previous line\ni to insert a newline before this one\na to insert a newline after this one\nw to write out to file\nq to quit\n", stdout);
		}
	}

	Editor_loop(head,source_file);
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

	FILE* source_file;
	source_file = fopen(argv[1], "rw+");

	Reached_EOF = false;
	struct Line* head = NULL;
	struct Line* p = NULL;
	while(!Reached_EOF)
	{
		Readline(source_file);
		p = newLine();
		setText(p, temp);
		head = addLine(head, p);
	}

	Editor_loop(head, source_file);

	return EXIT_SUCCESS;
}
