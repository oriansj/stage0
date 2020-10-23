/* Copyright (C) 2016 Jeremiah Orians
 * Copyright (C) 2018 Jan (janneke) Nieuwenhuizen <janneke@gnu.org>
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

#include<stdio.h>
#include<stdlib.h>

void file_print(char* s, FILE* f);

void require(int bool, char* error)
{
	if(!bool)
	{
		file_print(error, stderr);
		exit(EXIT_FAILURE);
	}
}
