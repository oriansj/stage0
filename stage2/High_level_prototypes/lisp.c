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
#include <stdint.h>

/* Prototypes */
struct cell* eval(struct cell* exp, struct cell* env);
void init_sl3();
uint32_t Readline(FILE* source_file, char* temp);
struct cell* parse(char* program, int32_t size);
void writeobj(FILE *ofp, struct cell* op);
void garbage_init();
void garbage_collect();

/*** Main Driver ***/
int main()
{
	garbage_init();
	init_sl3();
	for(;;)
	{
		garbage_collect();
		int read;
		char* message = calloc(1024, sizeof(char));
		read = Readline(stdin, message);
		struct cell* temp = parse(message, read);
		temp = eval(temp, top_env);
		writeobj(stdout, temp);
		printf("\n");
	}
	return 0;
}
