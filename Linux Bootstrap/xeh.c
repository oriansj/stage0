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

#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>

int main ()
{
	char output[3] = {0};
	/* {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'} */
	char table[16] = {0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46};
	uint8_t c;
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
