	;; A simple lisp with a precise garbage collector for cells
	;; Cells are in the following form:
	;; Type (0), CAR (4), CDR (8), ENV (12)
	;; Each being the length of a register [32bits]
	;;
	;; Type maps to the following values
	;; FREE = 1, MARKED = (1 << 1),INT = (1 << 2),SYM = (1 << 3),
	;; CONS = (1 << 4),PROC = (1 << 5),PRIMOP = (1 << 6),ASCII = (1 << 7)

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

;; Append_Cell
;; Adds a cell to the end of a CDR chain
;; Recieves HEAD in R0 and Tail in R1
;; Returns HEAD if not NULL
:append_Cell
	CMPSKIPI.NE R0 0            ; If HEAD is NULL
	MOVE R0 R1                  ; Swap TAIL and HEAD
	PUSHR R3 R15                ; Protect R3
	PUSHR R0 R15                ; Preserve HEAD

:append_Cell_loop
	LOAD32 R3 R0 8              ; Load HEAD->CDR
	CMPSKIPI.NE R3 0            ; If HEAD->CDR is NULL
	JUMP @append_Cell_done      ; Append and call it done

	;; Walk down list
	MOVE R0 R3                  ; Make HEAD->CDR the new HEAD
	JUMP @append_Cell_loop      ; And try again

:append_Cell_done
	STORE32 R1 R0 8             ; Store HEAD->CDR = Tail
	POPR R0 R15                 ; Ensure we are returning HEAD of list
	POPR R3 R15                 ; Restore R3
	RET R15

;; Tokenize
;; Converts a string into a list of tokens
;; Recieves HEAD in R0, Pointer to String in R1 and Size of string in R2
;; Returns HEAD of list in R0
:tokenize
	;; Deal with Edge case
	CMPSKIPI.NE R2 0            ; If remaining is 0
	RET R15                     ; Just return
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	FALSE R4                    ; Set Counter to 0

	;; Try to find whitespace Char
:tokenize_loop
	LOADXU8 R3 R1 R4            ; Get char
	CMPSKIPI.G R3 32            ; If control character or SPACE
	JUMP @tokenize_append       ; Stop

	;; Walk further down string
	ADDUI R4 R4 1               ; Next char
	JUMP @tokenize_loop         ; And try again

:tokenize_append
	FALSE R3                    ; NULL terminate
	STOREX8 R3 R1 R4            ; Found Token

	CMPSKIPI.NE R4 0            ; If empty
	JUMP @tokenize_iterate      ; Don't bother to append

	;; Make string token and append
	SWAP R0 R1                  ; Need to send string in R0 for call
	COPY R3 R0                  ; Preserve pointer to string
	CALLI R15 @make_sym         ; Convert string to token
	SWAP R0 R1                  ; Put HEAD and Tail in proper order
	CALLI R15 @append_Cell      ; Append Token to HEAD
	ADD R1 R3 R4                ; Update string pointer
	SUB R2 R2 R4                ; Decrement by size used

	;; Loop down string until end, appending tokens along the way
:tokenize_iterate
	ADDUI R1 R1 1               ; Move past NULL
	SUBUI R2 R2 1               ; And reduce size accordingly
	FALSE R4                    ; Reset Counter

	CMPSKIPI.LE R2 0            ; If NOT end of string
	JUMP @tokenize_loop         ; try to append another token

	;; Clean up
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	RET R15

;; Stack starts at the end of the program
:stack
