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


all: lisp.h lisp.c lisp_cell.c lisp_eval.c lisp_print.c lisp_read.c
	gcc -ggdb lisp.h lisp.c lisp_cell.c lisp_eval.c lisp_print.c lisp_read.c -o lisp

lisp: lisp.h lisp.c lisp_cell.c lisp_eval.c lisp_print.c lisp_read.c
	gcc -O2 lisp.h lisp.c lisp_cell.c lisp_eval.c lisp_print.c lisp_read.c -o lisp

coverage-test: lisp.h lisp.c lisp_cell.c lisp_eval.c lisp_print.c lisp_read.c
	gcc -fprofile-arcs -ftest-coverage lisp.h lisp.c lisp_cell.c lisp_eval.c lisp_print.c lisp_read.c -o lisp

clean: lisp
	rm lisp

Coverage-cleanup:
	rm *.gc{da,no,ov}
