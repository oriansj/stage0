	;; A simple lisp with a precise garbage collector for cells

;; Start function
:start
	LOADUI R15 $stack           ; Put stack at end of program
	;; We will be using R14 for our condition codes
	;; We will be using R13 for which IO we will be using

	;; Initialize
	CALLI R15 @garbage_init
	CALLI R15 @init_sl3

	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; We first read Tape_01 until completion
	LOADUI R13 0x1100

;; Main loop
:main
	CALLI R15 @garbage_collect  ; Clean up unused cells
	CALLI R15 @Readline         ; Read another S-expression
	CALLI R15 @parse            ; Convert into tokens
	CALLI R15 @eval             ; Evaluate tokens
	CALLI R15 @writeobj         ; Print result
	JUMP @main                  ; Loop forever
	HALT                        ; If broken get the fuck out now



;; Stack starts at the end of the program
:stack
