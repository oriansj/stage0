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
