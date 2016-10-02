#include<stdlib.h>

int main (int argc, char *argv[])
{
	char output[2] = {};
	char table[16] = {0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46};
	char c;
	int col = 40;
	int i = read(0, &c, 1);
	while( i > 0)
	{
	    output[0] = table[c / 16];
	    output[1] = table[c % 16];
	    write(1, output, 2 );
	    col = col - 2;
	    if(0 == col)
	    {
		col = 40;
		write(1, "\n", 1);
	    }
	    i = read(0, &c, 1);
	}
	write(1, "\n", 1);
	exit(EXIT_SUCCESS);
}
