## Copyright (C) 2016 Jeremiah Orians
## This file is part of stage0.
##
## stage0 is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## stage0 is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with stage0.  If not, see <http://www.gnu.org/licenses/>.


all: cc_aarch64

CC?=gcc
CFLAGS=-D_GNU_SOURCE -O0 -std=c99 -ggdb

cc_aarch64: cc_reader.c cc_strings.c cc_core.c cc.c cc_types.c cc.h
	$(CC) $(CFLAGS) \
	functions/match.c \
	functions/numerate_number.c \
	functions/file_print.c \
	functions/string.c \
	cc_reader.c \
	cc_strings.c \
	cc_types.c \
	cc_core.c \
	cc.c \
	cc.h \
	gcc_req.h \
	-o cc_aarch64

clean: cc_aarch64
	rm -f cc_aarch64
