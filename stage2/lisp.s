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


;; is_integer
;; Recieves pointer to string in R0
;; Returns TRUE or FALSE in R0
:is_integer
	PUSHR R1 R15                ; Protect R1
	LOADU8 R1 R0 0              ; Read first Char
	FALSE R0                    ; Assume FALSE

	CMPSKIPI.GE R1 48           ; If below '0'
	JUMP @is_integer_done       ; Return FALSE

	CMPSKIPI.G R1 57            ; If 0 to 9
	TRUE R0                     ; Set to TRUE

:is_integer_done
	POPR R1 R15                 ; Restore R1
	RET R15


;; numerate_string function
;; Recieves pointer To string in R0
;; Returns number in R0 equal to value of string
;; Or Zero in the event of invalid string
:numerate_string
	;; Preserve Registers
	PUSHR R1 R15
	PUSHR R2 R15
	PUSHR R3 R15
	PUSHR R4 R15

	;; Initialize
	MOVE R1 R0                  ; Get Text pointer out of the way
	FALSE R2                    ; Set Negative flag to false
	FALSE R3                    ; Set current count to Zero
	LOAD8 R0 R1 1               ; Get second byte
	CMPSKIPI.NE R0 120          ; If the second byte is x
	JUMP @numerate_string_hex   ; treat string like hex

	;; Deal with Decimal input
	LOADUI R4 10                ; Multiply by 10
	LOAD8 R0 R1 0               ; Get a byte
	CMPSKIPI.NE R0 45           ; If - toggle flag
	TRUE R2                     ; So that we know to negate
	CMPSKIPI.E R2 0             ; If toggled
	ADDUI R1 R1 1               ; Move to next
:numerate_string_dec
	LOAD8 R0 R1 0               ; Get a byte

	CMPSKIPI.NE R0 0            ; If NULL
	JUMP @numerate_string_done  ; Be done

	MUL R3 R3 R4                ; Shift counter by 10
	SUBI R0 R0 48               ; Convert ascii to number
	CMPSKIPI.GE R0 0            ; If less than a number
	JUMP @numerate_string_done  ; Terminate NOW
	CMPSKIPI.L R0 10            ; If more than a number
	JUMP @numerate_string_done  ; Terminate NOW
	ADDU R3 R3 R0               ; Don't add to the count

	ADDUI R1 R1 1               ; Move onto next byte
	JUMP @numerate_string_dec

	;; Deal with Hex input
:numerate_string_hex
	LOAD8 R0 R1 0               ; Get a byte
	CMPSKIPI.E R0 48            ; All hex strings start with 0x
	JUMP @numerate_string_done  ; Be done if not a match
	ADDUI R1 R1 2               ; Move to after leading 0x
:numerate_string_hex_0
	LOAD8 R0 R1 0               ; Get a byte
	CMPSKIPI.NE R0 0            ; If NULL
	JUMP @numerate_string_done  ; Be done

	SL0I R3 4                   ; Shift counter by 16
	SUBI R0 R0 48               ; Convert ascii number to number
	CMPSKIPI.L R0 10            ; If A-F
	SUBI R0 R0 7                ; Shove into Range
	CMPSKIPI.L R0 16            ; If a-f
	SUBI R0 R0 32               ; Shove into Range
	ADDU R3 R3 R0               ; Add to the count

	ADDUI R1 R1 1               ; Get next Hex
	JUMP @numerate_string_hex_0

;; Clean up
:numerate_string_done
	CMPSKIPI.E R2 0             ; If Negate flag has been set
	NEG R3 R3                   ; Make the number negative
	MOVE R0 R3                  ; Put number in R0

	;; Restore Registers
	POPR R4 R15
	POPR R3 R15
	POPR R2 R15
	POPR R1 R15
	RET R15


;; atom
;; Converts tokens into native forms
;; Aka numbers become numbers and everything else is a symbol
;; Recieves a pointer to Token in R0
;; Returns a pointer to a Cell in R0
:atom
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3

	LOAD32 R1 R0 0              ; Get CAR
	LOADU8 R2 R1 0              ; Get first Char

	CMPSKIPI.E R2 39            ; If Not Quote Char
	JUMP @atom_integer          ; Move to next type

	;; When dealing with a quote
	ADDUI R1 R1 1               ; Move past quote Char
	STORE32 R1 R0 0             ; And write to CAR

	LOADUI R1 $NIL              ; Using NIL
	CALLI R15 @make_cons        ; Make a cons with the token
	MOVE R1 R0                  ; Put the resulting CONS in R1
	LOADUI R0 $QUOTE            ; Using QUOTE
	CALLI R15 @make_cons        ; Make a CONS with the CONS
	MOVE R1 R0                  ; Put What is being returned into R1
	JUMP @atom_done             ; We are done

:atom_integer
	COPY R2 R1                  ; Preserve String pointer
	SWAP R0 R1                  ; Put string Pointer in R0
	CALLI R15 @is_integer       ; Determine if it is an integer
	JUMP.Z R0 @atom_functions   ; If Not an integer move on
	LOADUI R0 4                 ; Using INT
	STORE32 R0 R1 0             ; Set type to Integer
	MOVE R0 R2                  ; Using String pointer
	CALLI R15 @numerate_string  ; Convert to Number
	STORE32 R0 R1 4             ; Store result in CAR
	JUMP @atom_done             ; We are done (Result is in R1)

:atom_functions
	COPY R0 R2                  ; Using String pointer
	CALLI R15 @findsym          ; Lookup Symbol
	LOADUI R3 $NIL              ; Using NIL
	CMPSKIP.NE R0 R3            ; If NIL was Returned
	JUMP @atom_new              ; Make a new Symbol

	LOAD32 R1 R0 4              ; Make OP->CAR our result
	JUMP @atom_done             ; We are done (Result is in R1)

:atom_new
	LOADR32 R0 @all_symbols     ; Get pointer to all symbols
	SWAP R0 R1                  ; Put pointers in correct order
	CALLI R15 @make_cons        ; Make a CONS out of Token and all_symbols
	STORER32 R0 @all_symbols    ; Update all_symbols
	MOVE R1 R0                  ; Put result in correct register

:atom_done
	MOVE R0 R1                  ; Put our result in R0
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


:token_stack
	NOP                         ; Pointer to Unparsed Tokens


;; readobj
;; Breaks up tokens on the token_stack until its empty
;; Recieves Nothing
;; Returns a Cell in R0
:readobj
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2

	LOADR32 R0 @token_stack     ; Get HEAD

	LOAD32 R1 R0 8              ; Get HEAD->CDR
	STORER32 R1 @token_stack    ; Update Token Stack

	FALSE R1                    ; Using NULL
	STORE32 R1 R0 8             ; Set HEAD->CDR

	LOAD32 R1 R0 4              ; Get HEAD->CAR
	LOADU8 R1 R1 0              ; Get First Char of HEAD->CAR
	CMPSKIPI.E R1 40            ; If NOT (
	JUMP @readobj_0             ; Atomize HEAD

	CALLI R15 @readlist         ; Otherwise we want the result of readlist
	JUMP @readobj_done

:readobj_0
	CALLI R15 @atom             ; Let Atom process HEAD for us

:readobj_done
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; readlist
;; CONS up Rest of elements until ) is found
;; Recieves nothing
;; Returns A Cell in R0
:readlist
	PUSHR R1 R15                ; Protect R1
	LOADR32 R0 @token_stack     ; Get HEAD
	LOAD32 R1 R0 4              ; Get HEAD->CAR
	LOADU8 R1 R1 0              ; Get first Char of HEAD->CAR
	CMPSKIPI.E R1 41            ; If NOT )
	JUMP @readlist_0            ; CONS up elements

	LOADUI R0 $NIL              ; Use NIL (Result in R0)
	JUMP @readlist_done

:readlist_0
	CALLI R15 @readobj          ; Have readobj do its work
	MOVE R1 R0                  ; Put the result in a safe place
	CALLI R15 @readlist         ; Recursively call self
	SWAP R0 R1                  ; Put results in proper order
	CALLI R15 @make_cons        ; Make into a CONS (Result in R0)

:readlist_done
	POPR R1 R15                 ; Restore R1
	RET R15


;; parse
;; Starts the recursive tokenizing and atomizing of input
;; Recieves a string in R0 and its length in R1
;; Returns a list of Cells in R0
:parse
	PUSHR R2 R15                ; Protect R2
	MOVE R2 R1                  ; Put Size in the correct place
	MOVE R1 R0                  ; Put string pointer in the correct place
	CALLI R15 @tokenize         ; Get a list of tokens from string
	STORER32 R0 @token_stack    ; Shove list to token_stack

	JUMP.NZ R0 @parse_0         ; If not a NULL list atomize

	LOADUI R0 $NIL              ; Otherwise we return NIL
	JUMP @parse_done            ; Result in R0

:parse_0
	CALLI R15 @readobj          ; Start the atomization (Result in R0)

:parse_done
	POPR R2 R15                 ; Restore R2
	RET R15

;; Stack starts at the end of the program
:stack
