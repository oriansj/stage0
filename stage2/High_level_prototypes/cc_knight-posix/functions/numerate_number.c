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
#include<stdlib.h>
#include<string.h>
// void* calloc(int count, int size);
#define TRUE 1
//CONSTANT TRUE 1
#define FALSE 0
//CONSTANT FALSE 0

char* numerate_number(int a)
{
	char* result = calloc(16, sizeof(char));
	int i = 0;

	/* Deal with Zero case */
	if(0 == a)
	{
		result[0] = '0';
		return result;
	}

	/* Deal with negatives */
	if(0 > a)
	{
		result[0] = '-';
		i = 1;
		a = a * -1;
	}

	/* Using the largest 10^n number possible in 32bits */
	int divisor = 0x3B9ACA00;
	/* Skip leading Zeros */
	while(0 == (a / divisor)) divisor = divisor / 10;

	/* Now simply collect numbers until divisor is gone */
	while(0 < divisor)
	{
		result[i] = ((a / divisor) + 48);
		a = a % divisor;
		divisor = divisor / 10;
		i = i + 1;
	}

	return result;
}

int char2hex(int c)
{
	if (c >= '0' && c <= '9') return (c - 48);
	else if (c >= 'a' && c <= 'f') return (c - 87);
	else if (c >= 'A' && c <= 'F') return (c - 55);
	else return -1;
}

int hex2char(int c)
{
	if((c >= 0) && (c <= 9)) return (c + 48);
	else if((c >= 10) && (c <= 15)) return (c + 55);
	else return -1;
}

int char2dec(int c)
{
	if (c >= '0' && c <= '9') return (c - 48);
	else return -1;
}

int dec2char(int c)
{
	if((c >= 0) && (c <= 9)) return (c + 48);
	else return -1;
}

int numerate_string(char *a)
{
	int count = 0;
	int index;
	int negative;

	/* If NULL string */
	if(0 == a[0])
	{
		return 0;
	}
	/* Deal with hex */
	else if (a[0] == '0' && a[1] == 'x')
	{
		if('-' == a[2])
		{
			negative = TRUE;
			index = 3;
		}
		else
		{
			negative = FALSE;
			index = 2;
		}

		while(0 != a[index])
		{
			if(-1 == char2hex(a[index])) return 0;
			count = (16 * count) + char2hex(a[index]);
			index = index + 1;
		}
	}
	/* Deal with decimal */
	else
	{
		if('-' == a[0])
		{
			negative = TRUE;
			index = 1;
		}
		else
		{
			negative = FALSE;
			index = 0;
		}

		while(0 != a[index])
		{
			if(-1 == char2dec(a[index])) return 0;
			count = (10 * count) + char2dec(a[index]);
			index = index + 1;
		}
	}

	if(negative)
	{
		count = count * -1;
	}
	return count;
}
