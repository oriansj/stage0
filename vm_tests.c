#include "vm_instructions.c"

int main(int argc, char **argv)
{
	/* Make sure we have a program tape to run */
	if (argc < 2)
	{
		fprintf(stderr, "Usage: %s $FileName\nWhere $FileName is the name of the paper tape of the program being run\n", argv[0]);
		return EXIT_FAILURE;
	}

	/* Perform all the essential stages in order */
	struct lilith* vm;
	vm = create_vm(1 << 20);
	struct Instruction* c = calloc(1, sizeof(struct Instruction));

	destroy_vm(vm);
	free(c);
	return EXIT_SUCCESS;
}
