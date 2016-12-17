#include "lisp.h"

void writeobj(FILE *ofp, struct cell* op)
{
	switch(op->type)
	{
		case INT: fprintf(ofp, "%d", op->value); break;
		case CONS:
		{
			fprintf(ofp, "(");
			for(;;)
			{
				writeobj(ofp, op->car);
				if(nil == op->cdr)
				{
					fprintf(ofp, ")");
					break;
				}
				op = op->cdr;
				if(op->type != CONS)
				{
					fprintf(ofp, " . ");
					writeobj(ofp, op);
					fprintf(ofp, ")");
					break;
				}
				fprintf(ofp, " ");
			}
			break;
		}
		case SYM:
		{
			if(nil == op) fprintf(ofp, "()");
			else fprintf(ofp, "%s", op->string);
			break;
		}
		case PRIMOP: fprintf(ofp, "#<PRIMOP>"); break;
		case PROC: fprintf(ofp, "#<PROC>"); break;
		default: exit(1);
	}
}
