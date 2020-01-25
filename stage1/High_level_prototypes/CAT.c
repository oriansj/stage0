/* Copyright (C) 2019 Jeremiah Orians
 * This file is part of mescc-tools
 *
 * mescc-tools is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * mescc-tools is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with mescc-tools.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

int main(int argc, char** argv)
{
	if(2 > argc)
	{
		fprintf(stderr, "catm requires 2 or more arguments\n");
		exit(EXIT_FAILURE);
	}

	int output = open(argv[1], 577 , 384);
	if(-1 == output)
	{
		fprintf(stderr, "The file: %s is not a valid output file name\n", argv[1]);
		exit(EXIT_FAILURE);
	}

	int i;
	int bytes;
	char* buffer = calloc(2, sizeof(char));
	int input;
	for(i = 2; i <= argc ; i =  i + 1)
	{
		input = open(argv[i], 0, 0);
		if(-1 == input)
		{
			fprintf(stderr, "The file: %s is not a valid input file name\n", argv[i]);
			exit(EXIT_FAILURE);
		}
keep:
		bytes = read(input, buffer, 1);
		write(output, buffer, bytes);
		if(1 == bytes) goto keep;
	}

	free(buffer);
	return EXIT_SUCCESS;
}
