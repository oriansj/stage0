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
			fprintf(ofp, "%s", op->string);
			break;
		}
		case PRIMOP: fprintf(ofp, "#<PRIMOP>"); break;
		case PROC: fprintf(ofp, "#<PROC>"); break;
		case ASCII: fprintf(ofp, "%c", op->value); break;
		default: exit(1);
	}
}
