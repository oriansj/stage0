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
