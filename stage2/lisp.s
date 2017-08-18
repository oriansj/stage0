; Copyright (C) 2016 Jeremiah Orians
; This file is part of stage0.
;
; stage0 is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; stage0 is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with stage0.  If not, see <http://www.gnu.org/licenses/>.

	;; A simple lisp with a precise garbage collector for cells
	;; Cells are in the following form:
	;; Type (0), CAR (4), CDR (8), ENV (12)
	;; Each being the length of a register [32bits]
	;;
	;; Type maps to the following values
	;; FREE = 1, MARKED = (1 << 1),INT = (1 << 2),SYM = (1 << 3),
	;; CONS = (1 << 4),PROC = (1 << 5),PRIMOP = (1 << 6),CHAR = (1 << 7), STRING = (1 << 8)

	;; CONS space: End of program -> 1MB (0x100000)
	;; HEAP space: 1MB -> 1.5MB (0x180000)
	;; STACK space: 1.5MB -> End of Memory (2MB (0x200000))

;; Start function
:start
	;; Check if we are going to hit outside the world
	HAL_MEM                     ; Get total amount of Memory
	LOADR R1 @MINIMAL_MEMORY    ; Get our Minimal Value
	CMPSKIP.GE R0 R1            ; Check if we have enough
	JUMP @FAILED_INITIALIZATION ; If not fail gracefully

	LOADR R15 @stack_start      ; Put stack after CONS and HEAP
	;; We will be using R14 for our condition codes
	;; We will be using R13 for which Input we will be using
	;; We will be using R12 for which Output we will be using

	;; Ensure a known good state
	FALSE R0                    ; Reset R0
	FALSE R1                    ; Reset R1

	;; Initialize
	CALLI R15 @garbage_init
	CALLI R15 @init_sl3

	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; We first read Tape_01 until completion
	LOADUI R13 0x1100

	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE

;; Main loop
:main
	CALLI R15 @garbage_collect  ; Clean up unused cells
	CALLI R15 @Readline         ; Read another S-expression
	JUMP.Z R1 @main             ; Don't allow empty strings
	CALLI R15 @parse            ; Convert into tokens
	LOADR R1 @top_env           ; Get TOP_ENV
	CALLI R15 @eval             ; Evaluate tokens
	CALLI R15 @writeobj         ; Print result
	LOADUI R0 10                ; Use LF
	COPY R1 R12                 ; And desired Output
	FPUTC                       ; Write Line Feed
	FALSE R0                    ; Clear R0
	FALSE R1                    ; Clear R1
	JUMP @main                  ; Loop forever
	HALT                        ; If broken get the fuck out now

:stack_start
	'00180000'


;; How much memory is too little
:MINIMAL_MEMORY
'00180000'

;; Halt the machine in the event of insufficient Memory
:FAILED_INITIALIZATION
	FALSE R1                    ; Set output to TTY
	LOADUI R0 $FAILED_STRING    ; Prepare our Message
	CALLI R15 @Print_String     ; Print it
	HALT                        ; Prevent any further damage

:FAILED_STRING
"Please provide 1600KB of Memory for this Lisp to run (More is recommended for large programs)
"

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

	CMPSKIPI.NE R3 34           ; If raw string
	JUMP @tokenize_string       ; Process that whole thing

	;; Walk further down string
	ADDUI R4 R4 1               ; Next char
	JUMP @tokenize_loop         ; And try again

:tokenize_string
	;; Walk further down string
	ADDUI R4 R4 1               ; Next char
	LOADXU8 R3 R1 R4            ; Get char
	CMPSKIPI.NE R3 34           ; If Found matching quote
	JUMP @tokenize_append       ; Stop

	JUMP @tokenize_string       ; And try again

:tokenize_append
	FALSE R3                    ; NULL terminate
	STOREX8 R3 R1 R4            ; Found Token

	COPY R3 R1                  ; Preserve pointer to string
	CMPSKIPI.NE R4 0            ; If empty
	JUMP @tokenize_iterate      ; Don't bother to append

	;; Make string token and append
	SWAP R0 R1                  ; Need to send string in R0 for call
	CALLI R15 @make_sym         ; Convert string to token
	SWAP R0 R1                  ; Put HEAD and Tail in proper order
	CALLI R15 @append_Cell      ; Append Token to HEAD

	;; Loop down string until end, appending tokens along the way
:tokenize_iterate
	ADDUI R4 R4 1               ; Move past NULL
	ADD R1 R3 R4                ; Update string pointer
	SUB R2 R2 R4                ; Decrement by size used
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

	CMPSKIPI.NE R1 45           ; If starts with -
	LOADU8 R1 R0 1              ; Get Second Char

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

	LOAD32 R1 R0 4              ; Get CAR
	LOADU8 R2 R1 0              ; Get first Char

	CMPSKIPI.E R2 39            ; If Not Quote Char
	JUMP @atom_string           ; Move to next type

	;; When dealing with a quote
	ADDUI R1 R1 1               ; Move past quote Char
	STORE32 R1 R0 4             ; And write to CAR

	LOADUI R1 $NIL              ; Using NIL
	CALLI R15 @make_cons        ; Make a cons with the token
	MOVE R1 R0                  ; Put the resulting CONS in R1
	LOADUI R0 $s_quote          ; Using S_QUOTE
	CALLI R15 @make_cons        ; Make a CONS with the CONS
	MOVE R1 R0                  ; Put What is being returned into R1
	JUMP @atom_done             ; We are done

:atom_string
	CMPSKIPI.E R2 34            ; If Not Double quote
	JUMP @atom_integer          ; Move to next type

	;; a->string = a->string + 1
	ADDUI R1 R1 1               ; Move past quote Char
	STORE32 R1 R0 4             ; And write to CAR

	;; a->type = STRING
	LOADUI R1 256               ; Using STRING
	STORE32 R1 R0 0             ; Set type to Integer

	COPY R1 R0                  ; Put the cell we were given in the right place
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
	COPY R3 R0                  ; Protect A
	CALLI R15 @make_cons        ; Make a CONS out of Token and all_symbols
	STORER32 R0 @all_symbols    ; Update all_symbols
	MOVE R1 R3                  ; Put result in correct register

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

	LOAD32 R1 R0 8              ; Get HEAD->CDR
	STORER32 R1 @token_stack    ; Update token stack
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


;; Our simple malloc function
;; Recieves A number of bytes to allocate in R0
;; Returns a pointer to Segment in R0
:malloc
	PUSHR R1 R15                ; Protect R1
	LOADR R1 @malloc_pointer    ; Get current malloc pointer

	;; update malloc pointer
	SWAP R0 R1
	ADD R1 R0 R1
	STORER R1 @malloc_pointer

;; Done
	POPR R1 R15                 ; Restore R1
	RET R15

;; Our static value for malloc pointer
;; Starting at 1MB
:malloc_pointer
	'00100000'


;; Switch_Input
;; If R13 is TTY, HALT
;; Else Set input to TTY
:Switch_Input
	CMPSKIPI.NE R13 0           ; IF TTY
	HALT                        ; Simply Done

	FALSE R13                   ; Otherwise switch to TTY
	RET R15


;; Readline
;; Using IO source in R13 read a FULL S-expression
;; Returns String pointer in R0 and Length in R1
:Readline
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	PUSHR R5 R15                ; Protect R5

	FALSE R0                    ; Get where space is free
	CALLI R15 @malloc
	MOVE R2 R0                  ; Preserve pointer
	FALSE R3                    ; Set index to 0
	FALSE R4                    ; Set Depth to 0
	COPY R1 R13                 ; Set desired IO
	LOADUI R5 32                ; Keep SPACE for ()

	;; Main Loop
:Readline_loop
	FGETC                       ; Get a Byte
	CMPSKIPI.G R0 4             ; If EOF
	CALLI R15 @Switch_Input     ; Do the correct thing

	CMPSKIPI.NE R0 13           ; If CR
	LOADUI R0 10                ; Replace with LF

	CMPSKIPI.NE R13 0           ; Don't display unless TTY
	FPUTC                       ; Display the Char we just pressed

	CMPSKIPI.G R0 32            ; If SPACE or below
	JUMP @Readline_1

	CMPSKIPI.NE R0 34           ; Look for double quote
	JUMP @Readline_string       ; Keep looping until then

	CMPSKIPI.NE R0 59           ; If LINE Comment (;)
	JUMP @Readline_0            ; Drop until the end of Line

	CMPSKIPI.NE R0 40           ; If (
	JUMP @Readline_2            ; Deal with depth and spacing

	CMPSKIPI.NE R0 41           ; If )
	JUMP @Readline_2            ; Deal with depth and spacing

	STOREX8 R0 R2 R3            ; Append to String
	ADDUI R3 R3 1               ; Increment Size
	JUMP @Readline_loop         ; Keep Reading

	;; Deal with Line comments
:Readline_0
	FGETC                       ; Get another Byte
	CMPSKIPI.NE R0 13           ; Deal with CR
	LOADUI R0 10                ; Convert to LF

	CMPSKIPI.NE R0 10           ; If LF
	JUMP @Readline_loop         ; Resume

	JUMP @Readline_0            ; Otherwise Keep Looping

	;; Deal with strings
:Readline_string
	STOREX8 R0 R2 R3            ; Append to String
	ADDUI R3 R3 1               ; Increment Size
	FGETC                       ; Get a Byte

	CMPSKIPI.NE R0 13           ; Deal with CR
	LOADUI R0 10                ; Convert to LF

	CMPSKIPI.NE R13 0           ; Don't display unless TTY
	FPUTC                       ; Display the Char we just pressed

	CMPSKIPI.E R0 34            ; Look for double quote
	JUMP @Readline_string       ; Keep looping until then

	STOREX8 R0 R2 R3            ; Append to String
	ADDUI R3 R3 1               ; Increment Size
	JUMP @Readline_loop         ; Resume

	;; Deal with Whitespace and Control Chars
:Readline_1
	CMPSKIPI.NE R4 0            ; IF Depth 0
	JUMP @Readline_done         ; We made it to the end

	LOADUI R0 32                ; Otherwise convert to SPACE
	STOREX8 R0 R2 R3            ; Append to String
	ADDUI R3 R3 1               ; Increment Size
	JUMP @Readline_loop         ; Keep Looping

	;; Deal with ()
:Readline_2
	CMPSKIPI.NE R0 40           ; If (
	ADDUI R4 R4 1               ; Increment Depth

	CMPSKIPI.NE R0 41           ; If )
	SUBUI R4 R4 1               ; Decrement Depth

	STOREX8 R5 R2 R3            ; Put in leading SPACE
	ADDUI R3 R3 1               ; Increment Size
	STOREX8 R0 R2 R3            ; Put in Char
	ADDUI R3 R3 1               ; Increment Size
	STOREX8 R5 R2 R3            ; Put in Trailing SPACE
	ADDUI R3 R3 1               ; Increment Size

	JUMP @Readline_loop         ; Resume

	;; Clean up
:Readline_done
	ADDUI R0 R3 4               ; Pad with 4 NULLs
	CALLI R15 @malloc           ; Correct Malloc
	MOVE R1 R3                  ; Put Size in R1
	POPR R5 R15                 ; Restore R5
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	RET R15


;; Write_Int
;; Writes desired integer to desired IO
;; Recieves Integer in R0 and IO in R1
;; Returns Nothing
:Max_Decimal
	'3B9ACA00'

:Write_Int
	PUSHR R0 R15                ; Preserve R0
	PUSHR R1 R15                ; Preserve R1
	PUSHR R2 R15                ; Preserve R2
	PUSHR R3 R15                ; Preserve R3
	PUSHR R4 R15                ; Preserve R4
	PUSHR R5 R15                ; Preserve R5
	MOVE R3 R0                  ; Move Integer out of the way

	JUMP.Z R3 @Write_Int_ZERO   ; Deal with Special case of ZERO
	JUMP.P R3 @Write_Int_Positive
	LOADUI R0 45                ; Using -
	FPUTC                       ; Display leading -
	NOT R3 R3                   ; Flip into positive
	ADDUI R3 R3 1               ; Adjust twos

:Write_Int_Positive
	LOADR R2 @Max_Decimal       ; Starting from the Top
	LOADUI R5 10                ; We move down by 10
	FALSE R4                    ; Flag leading Zeros

:Write_Int_0
	DIVIDE R0 R3 R3 R2          ; Break off top 10
	CMPSKIPI.E R0 0             ; If Not Zero
	TRUE R4                     ; Flip the Flag

	JUMP.Z R4 @Write_Int_1      ; Skip leading Zeros
	ADDUI R0 R0 48              ; Shift into ASCII
	FPUTC                       ; Print Top

:Write_Int_1
	DIV R2 R2 R5                ; Look at next 10
	CMPSKIPI.E R2 0             ; If we reached the bottom STOP
	JUMP @Write_Int_0           ; Otherwise keep looping

:Write_Int_done
	;; Cleanup
	POPR R5 R15                 ; Restore R5
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15

:Write_Int_ZERO
	LOADUI R0 48                ; Using Zero
	FPUTC                       ; Display
	JUMP @Write_Int_done        ; Be done



;; Print_String
;; Prints the string pointed in R0 to IO in R1
;; Recieves string pointer in R0 and IO in R1
;; Returns nothing
:Print_String
	PUSHR R0 R15                ; Protect R0
	PUSHR R2 R15                ; Protect R2
	MOVE R2 R0                  ; Get pointer out of the way

:Print_String_loop
	LOADU8 R0 R2 0              ; Get Char
	CMPSKIPI.NE R0 0            ; If NULL
	JUMP @Print_String_done     ; Call it done
	FPUTC                       ; Otherwise write the Char
	ADDUI R2 R2 1               ; Increment to next Char
	JUMP @Print_String_loop     ; And Keep looping

:Print_String_done
	POPR R2 R15                 ; Restore R2
	POPR R0 R15                 ; Restore R0
	RET R15


;; writeobj
;; Outputs to the IO in R12
;; Recieves a Cell list in R0
;; Returns nothing
:writeobj
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	COPY R3 R0                  ; Protect HEAD
	LOAD32 R2 R0 0              ; Load HEAD->Type
	COPY R1 R12                 ; Using desired output

	CMPSKIPI.NE R2 4            ; If INT
	JUMP @writeobj_INT          ; Print it and be done

	CMPSKIPI.NE R2 8            ; If SYM
	JUMP @writeobj_SYM          ; Print its string

	CMPSKIPI.NE R2 16           ; If CONS
	JUMP @writeobj_CONS         ; Print it all recursively

	CMPSKIPI.NE R2 32           ; If PROC
	JUMP @writeobj_PROC         ; Print Label

	CMPSKIPI.NE R2 64           ; If PRIMOP
	JUMP @writeobj_PRIMOP       ; Print Label

	CMPSKIPI.NE R2 128          ; If CHAR
	JUMP @writeobj_CHAR         ; Print the Char

	CMPSKIPI.NE R2 256          ; If STRING
	JUMP @writeobj_STRING       ; Print the String

	;; What the hell is that???
	LOADUI R0 $writeobj_Error
	FALSE R1
	CALLI R15 @Print_String
	HALT

:writeobj_Error
	"What the fuck was that?"

:writeobj_INT
	LOAD32 R0 R0 4              ; Get HEAD->CAR
	CALLI R15 @Write_Int        ; Write it output
	JUMP @writeobj_done         ; Be done

:writeobj_CONS
	LOADUI R0 40                ; Using (
	FPUTC                       ; Write to desired output

:writeobj_CONS_0
	LOAD32 R0 R3 4              ; Get HEAD->CAR
	CALLI R15 @writeobj         ; Recurse on HEAD->CAR

	LOAD32 R3 R3 8              ; Set HEAD to HEAD->CDR
	LOADUI R0 $NIL              ; Using NIL
	CMPJUMPI.E R0 R3 @writeobj_CONS_1

	LOAD32 R0 R3 0              ; Get HEAD->type
	CMPSKIPI.E R0 16            ; if Not CONS
	JUMP @writeobj_CONS_2       ; Deal with inner case

	LOADUI R0 32                ; Using SPACE
	FPUTC                       ; Write out desired space
	JUMP @writeobj_CONS_0       ; Keep looping

	;; Deal with case of op->cdr == nil
:writeobj_CONS_1
	LOADUI R0 41                ; Using )
	FPUTC                       ; Write to desired output
	JUMP @writeobj_done         ; Be Done

:writeobj_CONS_2
	COPY R0 R3                  ; Using HEAD
	CALLI R15 @writeobj         ; Recurse
	LOADUI R0 41                ; Using )
	FPUTC                       ; Write to desired output
	JUMP @writeobj_done         ; Be Done

:writeobj_SYM
	LOAD32 R0 R3 4              ; Get HEAD->CAR
	CALLI R15 @Print_String     ; Write it to output
	JUMP @writeobj_done         ; Be Done

:PRIMOP_String
	"#<PRIMOP>"

:writeobj_PRIMOP
	LOADUI R0 $PRIMOP_String    ; Using the desired string
	CALLI R15 @Print_String     ; Write it to output
	JUMP @writeobj_done         ; Be Done

:PROC_String
	"#<PROC>"

:writeobj_PROC
	LOADUI R0 $PROC_String      ; Using the desired string
	CALLI R15 @Print_String     ; Write it to output
	JUMP @writeobj_done         ; Be Done

:writeobj_STRING
	LOAD32 R0 R3 4              ; Get HEAD->CAR
	CALLI R15 @Print_String     ; Write it to output
	JUMP @writeobj_done         ; Be Done

:writeobj_CHAR
	LOADU8 R0 R3 7              ; Using bottom 8 bits of HEAD->CAR
	FPUTC                       ; We write our desired output

:writeobj_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; strcmp
;; A simple string compare function
;; Recieves string pointers in R0 and R1
;; Returns result of comparision in R0
:strcmp
	;; Preserve registers
	PUSHR R2 R15
	PUSHR R3 R15
	PUSHR R4 R15
	;; Setup registers
	MOVE R2 R0
	MOVE R3 R1
	LOADUI R4 0
:cmpbyte
	LOADXU8 R0 R2 R4            ; Get a byte of our first string
	LOADXU8 R1 R3 R4            ; Get a byte of our second string
	ADDUI R4 R4 1               ; Prep for next loop
	CMP R1 R0 R1                ; Compare the bytes
	CMPSKIPI.E R0 0             ; Stop if byte is NULL
	JUMP.E R1 @cmpbyte          ; Loop if bytes are equal
;; Done
	MOVE R0 R1                  ; Prepare for return
	;; Restore registers
	POPR R4 R15
	POPR R3 R15
	POPR R2 R15
	RET R15


;; findsym
;; Attempts to find a symbol in a CONS list
;; Recieves a string in R0
;; Returns Cell or NIL in R0
:findsym
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	COPY R3 R0                  ; Protect String
	LOADR R2 @all_symbols       ; Get all_symbols

:findsym_loop
	LOADUI R0 $NIL              ; Using NIL
	CMPSKIP.NE R0 R2            ; Check if we reached the end
	JUMP @findsym_done          ; Use NIL as our result

	LOAD32 R0 R2 4              ; Get symlist->CAR
	LOAD32 R0 R0 4              ; Get symlist->CAR->CAR
	COPY R1 R3                  ; Prepare string to find
	CALLI R15 @strcmp           ; See if we have a match
	JUMP.E R0 @findsym_found    ; We have a match

	LOAD32 R2 R2 8              ; symlist = symlist->CDR
	JUMP @findsym_loop          ; Keep looping

:findsym_found
	MOVE R0 R2                  ; We want symlist as our result

:findsym_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; intern
;; Either find symbol or make it
;; Recieves string pointer in R0
;; Returns a Cell pointer in R0
:intern
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2

	COPY R1 R0                  ; Protect String
	CALLI R15 @findsym          ; Lookup Symbol

	CMPSKIPI.NE R0 $NIL         ; Determine if Symbol was found
	JUMP @intern_found          ; And if so, use it

	MOVE R0 R1                  ; Using our string
	CALLI R15 @make_sym         ; Make a SYM
	COPY R2 R0                  ; Protect Cell

	LOADR32 R1 @all_symbols     ; Get all_symbols
	CALLI R15 @make_cons        ; CONS together
	STORER32 R0 @all_symbols    ; Update all_symbols
	MOVE R0 R2                  ; Restore Cell
	JUMP @intern_done           ; R0 has our result

:intern_found
	LOAD32 R0 R0 4              ; Use op->CAR as our result

:intern_done
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; extend
;; CONS up symbols with an environment
;; Recieves an environment in R0, symbol in R1 and Value in R2
;; Returns a CONS of CONS in R0
:extend
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3

	SWAP R2 R0                  ; Protect the env until we need it
	SWAP R0 R1                  ; Put Symbol and Value in Correct Order
	CALLI R15 @make_cons        ; Make inner CONS
	MOVE R1 R2                  ; Get env now that we need it
	CALLI R15 @make_cons        ; Make outter CONS

	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; multiple_extend
;; Recieves an environment in R0, symbol in R1 and Values in R2
;; Returns an extended environment in R0
:multiple_extend
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	PUSHR R5 R15                ; Protect R5
	LOADUI R5 $NIL              ; We will need NIL

:multiple_extend_0
	CMPJUMPI.E R1 R5 @multiple_extend_done
	LOAD32 R3 R1 8              ; Protect SYMS->CDR
	LOAD32 R4 R2 8              ; Protect VALS->CDR
	LOAD32 R1 R1 4              ; Using SYMS->CAR
	LOAD32 R2 R2 4              ; Using VALS->CAR
	CALLI R15 @extend           ; Extend Environment
	MOVE R1 R3                  ; USING SYMS->CDR
	MOVE R2 R4                  ; VALS->CDR
	JUMP @multiple_extend_0     ; Iterate until fully extended

:multiple_extend_done
	POPR R5 R15                 ; Restore R5
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; extend_env
;; Recieves a Symbol in R0, a Value in R1 and an environment pointer in R2
;; Returns Value in R0 after extending top
:extend_env
	PUSHR R1 R15                ; Protect Val
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	CALLI R15 @make_cons        ; Make a cons of SYM and VAL
	MOVE R3 R0                  ; Put safely out of way
	LOAD32 R0 R2 4              ; Using ENV->CAR
	LOAD32 R1 R2 8              ; And ENV->CDR
	CALLI R15 @make_cons        ; Make a cons of old environment
	STORE32 R0 R2 8             ; SET ENV->CDR to old environment
	STORE32 R3 R2 4             ; SET ENV->CAR to new CONS
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore Val
	COPY R0 R1                  ; Return Val
	RET R15


;; assoc
;; Recieves a Key in R0 and an alist in R1
;; Returns Value if Found or NIL in R0
:assoc
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	LOADUI R4 $NIL              ; Using NIL
	LOAD32 R0 R0 4              ; Using KEY->CAR

:assoc_0
	CMPJUMPI.E R1 R4 @assoc_done
	LOAD32 R2 R1 4              ; ALIST->CAR
	LOAD32 R3 R2 4              ; ALIST->CAR->CAR
	LOAD32 R3 R3 4              ; ALIST->CAR->CAR->CAR
	LOAD32 R1 R1 8              ; ALIST = ALIST->CDR
	CMPSKIP.E R0 R3             ; If ALIST->CAR->CAR->CAR != KEY->CAR
	JUMP @assoc_0               ; Iterate using ALIST->CDR

	;; Found KEY
	MOVE R4 R2                  ; Set ALIST->CAR as our return value

:assoc_done
	MOVE R0 R4                  ; Use whatever in R4 as our return
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; evlis
;; Recieves Expressions in R0 and an Environment in R1
;; Returns the result of Evaluation of those Expressions
;; in respect to the given Environment in R0
:evlis
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3

	COPY R3 R1                  ; Protect ENV
	LOAD32 R2 R0 4              ; Protect EXPRS->CAR
	LOAD32 R0 R0 8              ; Using EXPRS->CDR
	CALLI R15 @evlis            ; Recursively Call self Down Expressions
	SWAP R0 R2                  ; Using EXPRS->CDR
	MOVE R1 R3                  ; Restore ENV
	CALLI R15 @eval             ; EVAL
	MOVE R1 R2                  ; Using result of EVAL and EVLIS
	CALLI R15 @make_cons        ; Make a CONS of it all

	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; progn
;; Recieves Expressions in R0 and an Environment in R1
;; Returns the result of Evaluation of those Expressions
;; in respect to the given Environment in R0
:progn
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL

:progn_0
	LOAD32 R2 R0 8              ; Protect EXPS->CDR
	LOAD32 R0 R0 4              ; Using EXPS->CAR
	CALLI R15 @eval             ; EVAL
	CMPSKIP.E R2 R3             ; If EXPS->CDR NOT NIL
	MOVE R0 R2                  ; Use EXPS->CDR for next loop
	JUMP.Z R2 @progn_0          ; Keep looping if EXPS->CDR isn't NIL

	;; Finally broke out of loop
	;; Desired result is in R0
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; Apply
;; Recieves a Procedure in R0 and Values in R1
;; Applies the procedure to the values and returns the result in R0
:apply
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOAD32 R3 R0 0              ; Get PROC->TYPE

	;; Deal with PRIMOPs
	CMPSKIPI.E R3 64            ; If Not PRIMOP
	JUMP @apply_0               ; Check NEXT
	LOAD32 R3 R0 4              ; Using PROC->CAR
	MOVE R0 R1                  ; Apply to VALs
	CALL R3 R15                 ; Call PROC->CAR with VALs
	JUMP @apply_done            ; Simply Pass the results

	;; Deal with Procedures
:apply_0
	CMPSKIPI.E R3 32            ; If Not PROC
	JUMP @apply_1               ; Abort with FIRE

	MOVE R2 R1                  ; Protect VALUE and put in future correct place
	MOVE R3 R0                  ; Protect PROC
	LOAD32 R0 R3 12             ; Get PROC->ENV
	LOAD32 R1 R0 8              ; Get PROC->ENV->CDR
	LOAD32 R0 R0 4              ; Get PROC->ENV->CAR
	CALLI R15 @make_cons        ; ENV = MAKE_CONS(PROC->ENV->CAR, PROC->ENV->CDR)

	LOAD32 R1 R3 4              ; Get PROC->CAR
	CALLI R15 @multiple_extend  ; R0 = MULTIPLE_EXTEND(ENV, PROC->CAR, VALS)

	MOVE R1 R0                  ; Put Extended_Env in the right place
	LOAD32 R0 R3 8              ; Get PROC->CDR
	CALLI R15 @progn            ; PROGN(PROC->CDR, R0)
	JUMP @apply_done            ; Simply Pass the results

	;; Deal with unknown shit
:apply_1
	LOADUI R0 $apply_error      ; Using designated Error Message
	FALSE R1                    ; Using TTY
	CALLI R15 @Print_String     ; Write Message
	HALT                        ; And bring the FIRE

:apply_error
	"Bad argument to apply"

	;; Clean up and return
:apply_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; evcond
;; Recieves an Expression in R0 and an Environment in R1
;; Walks down conditions until true one is found and return
;; Desired expression's result in R0
;; if none of the conditions are true, and the result of
;; the COND is undefined
:evcond
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	LOADUI R4 $TEE              ; Using TEE

	;; Truth Evaluation
:evcond_0
	LOAD32 R3 R0 8              ; Protect EXP->CDR
	LOAD32 R2 R0 4              ; Protect EXP->CAR
	LOAD32 R0 R2 4              ; Using EXP->CAR->CAR
	CALLI R15 @eval             ; EVAL
	CMPJUMPI.E R0 R4 @evcond_1  ; Its true !

	MOVE R0 R3                  ; Using EXP->CDR
	CALLI R15 @evcond           ; Recurse
	JUMP @evcond_done           ; Bail with just NIL

	;;  Expression Evaluation
:evcond_1
	LOAD32 R0 R2 8              ; Get EXP->CAR->CDR
	LOAD32 R0 R0 4              ; Using EXP->CAR->CDR->CAR
	CALLI R15 @eval             ; EVAL

	;; Clean up and return
:evcond_done
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; eval
;; Recieves an Expression in R0 and an Environment in R1
;; Evaluates the expression in the given environment and returns
;; The result in R0
:eval
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	LOAD32 R4 R0 0              ; Get EXP->TYPE

	;; Deal with special case of Integers
	CMPSKIPI.NE R4 4            ; If EXP->TYPE is Integer
	JUMP @eval_done             ; Simply return what was given

	;; Deal with special case of Symbols
	CMPSKIPI.E R4 8             ; If EXP->TYPE is NOT Symbol
	JUMP @eval_cons             ; Move onto next Case

	CALLI R15 @process_sym      ; process the symbol
	JUMP @eval_done             ; Return it

	;; Deal with special cases of CONS
:eval_cons
	CMPSKIPI.E R4 16            ; If EXP->TYPE is NOT CONS
	JUMP @eval_proc             ; Move onto next Case

	CALLI R15 @process_cons     ; Deal with all CONS
	JUMP @eval_done             ; Simply return the result

:eval_proc
	CMPSKIPI.E R4 32            ; If EXP->TYPE is NOT PROC
	JUMP @eval_primop           ; Move onto next Case

	JUMP @eval_done

:eval_primop
	CMPSKIPI.E R4 64            ; If EXP->TYPE is NOT PRIMOP
	JUMP @eval_char             ; Move onto next Case

:eval_char
	CMPSKIPI.E R4 128           ; If EXP->TYPE is NOT CHAR
	JUMP @eval_string           ; Move onto next Case
	JUMP @eval_done

:eval_string
	CMPSKIPI.E R4 256           ; If EXP->TYPE is NOT STRING
	JUMP @eval_error            ; Move onto next Case
	JUMP @eval_done

:eval_error
	LOADUI R0 $eval_error_Message ; Use a specific message to aid debugging
	FALSE R1                    ; Written to TTY
	CALLI R15 @Print_String     ; Write NOW
	HALT

:eval_error_Message
	"EVAL Recieved unknown Object"

	;; Result must be in R0 by this point
	;; Simply Clean up and return result in R0
:eval_done
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; process_sym
;; Recieves Expression in R0 and an Environment in R1
;; Returns symbol in R0
:process_sym
	CALLI R15 @assoc            ; ASSOC to get tmp
	CMPSKIPI.NE R0 $NIL         ; If NIL is returned
	JUMP @process_bad_Symbol    ; Burn with FIRE

	LOAD32 R0 R0 8              ; Return tmp->CDR
	RET R15

:process_bad_Symbol
	LOADUI R0 $sym_unbound      ; Using the designated Error message
	FALSE R1                    ; Using TTY
	CALLI R15 @Print_String     ; Written for the user
	HALT                        ; Simply toss the rest into the fire

:sym_unbound
	"Unbound symbol"


;; process_if
;; Recieves Expression in R0 and an Environment in R1
;; Returns the evaluation of the expression if true in R0
;; Or the evaluation of the CDR of the expression
:process_if
	PUSHR R2 R15                ; Protect R2

	LOAD32 R2 R0 8              ; Protect EXP->CDR
	LOAD32 R0 R2 4              ; Using EXP->CDR->CAR
	CALLI R15 @eval             ; Recurse to get truth
	CMPSKIPI.NE R0 $NIL         ; If Result was NOT NIL
	LOAD32 R2 R2 8              ; Update to EXP->CDR->CDR
	LOAD32 R0 R2 8              ; Get EXP->CDR->CDR
	LOAD32 R0 R0 4              ; Using EXP->CDR->CDR->CAR
	CALLI R15 @eval             ; Recurse to get result

	POPR R2 R15                 ; Restore R2
	RET R15


;; process_setb
;; Recieves Expression in R0 and an Environment in R1
;; Sets the desired variable to desired value/type
;; Returns the value/type in R0
:process_setb
	PUSHR R2 R15                ; Protect R2
	LOAD32 R2 R0 8              ; Protect EXP->CDR
	LOAD32 R0 R2 8              ; Get EXP->CDR->CDR
	LOAD32 R0 R0 4              ; Using EXP->CDR->CDR->CAR
	CALLI R15 @eval             ; Recurse to get New value
	SWAP R0 R2                  ; Protect New Value
	LOAD32 R0 R0 4              ; Using EXP->CDR->CAR
	CALLI R15 @assoc            ; Get the associated Symbol
	STORE32 R2 R0 8             ; SET Pair->CDR to New Value
	MOVE R0 R2                  ; Using New Value
	POPR R2 R15                 ; Restore R2
	RET R15


;; process_let
;; Recieves Expression in R0 and an Environment in R1
;; Creates lexical closure and evaluates inside of it
;; Returns the value/type in R0
:process_let
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	PUSHR R5 R15                ; Protect R5
	LOADUI R4 $NIL              ; Get NIL
	MOVE R3 R1                  ; Get ENV out of the way
	MOVE R2 R0                  ; Protect EXP
	LOAD32 R5 R2 8              ; Get EXP->CDR
	LOAD32 R5 R5 4              ; LETS = EXP->CDR->CAR

:process_let_0
	CMPJUMPI.E R5 R4 @process_let_1
	LOAD32 R0 R5 4              ; Get LETS->CAR
	LOAD32 R0 R0 8              ; Get LETS->CAR->CDR
	LOAD32 R0 R0 4              ; Get LETS->CAR->CDR->CAR
	COPY R1 R3                  ; Using ENV
	CALLI R15 @eval             ; CELL = EVAL(LETS->CAR->CDR->CAR, ENV)

	MOVE R1 R0                  ; Put CELL in the right place
	LOAD32 R0 R5 4              ; Get LETS->CAR
	LOAD32 R0 R0 4              ; Get LETS->CAR->CAR
	CALLI R15 @make_cons        ; CELL = MAKE_CONS(LETS->CAR->CAR, CELL)

	COPY R1 R3                  ; Using ENV
	CALLI R15 @make_cons        ; CELL = MAKE_CONS(CELL, ENV)
	MOVE R3 R0                  ; ENV = CELL

	LOAD32 R5 R5 8              ; LETS = LETS->CDR
	JUMP @process_let_0         ; Iterate through bindings

:process_let_1
	MOVE R1 R3                  ; Using ENV
	LOAD32 R0 R2 8              ; Get EXP->CDR
	LOAD32 R0 R0 8              ; Using EXP->CDR->CDR
	CALLI R15 @progn            ; Process inside of Closure

	;; Cleanup
	POPR R5 R15                 ; Restore R5
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15

;; process_cons
;; Recieves Expression in R0 and an Environment in R1
;; Returns the evaluation of whatever special used or
;; The application of the evaluation in R0
:process_cons
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4

	LOAD32 R4 R0 4              ; Using EXP->CAR
	LOADUI R3 $s_if             ; Using s_if
	CMPJUMPI.NE R4 R3 @process_cons_cond

	CALLI R15 @process_if       ; deal with special case of If statements
	JUMP @process_cons_done     ; Return it

:process_cons_cond
	LOADUI R3 $s_cond           ; Using s_cond
	CMPJUMPI.NE R4 R3 @process_cons_begin

	;; Deal with special case of COND statements
	LOAD32 R0 R0 8              ; Using EXP->CDR
	CALLI R15 @evcond           ; EVCOND
	JUMP @process_cons_done     ; Simply use it's result

:process_cons_begin
	LOADUI R3 $s_begin          ; Using s_begin
	CMPJUMPI.NE R4 R3 @process_cons_lambda

	;; Deal with special case of BEGIN statements
	LOAD32 R0 R0 8              ; Using EXP->CDR
	CALLI R15 @progn            ; PROGN
	JUMP @process_cons_done     ; Simply use it's result

:process_cons_lambda
	LOADUI R3 $s_lambda         ; Using s_lambda
	CMPJUMPI.NE R4 R3 @process_cons_quote

	;; Deal with special case of lambda statements
	MOVE R2 R1                  ; Put ENV in the right place
	LOAD32 R1 R0 8              ; Get EXP->CDR
	LOAD32 R0 R1 4              ; Using EXP->CDR->CAR
	LOAD32 R1 R1 8              ; Using EXP->CDR->CDR
	CALLI R15 @make_proc        ; MAKE_PROC
	JUMP @process_cons_done     ; Simply return its result

:process_cons_quote
	LOADUI R3 $s_quote          ; Using s_quote
	CMPJUMPI.NE R4 R3 @process_cons_define

	;; Deal with special case of quote statements
	LOAD32 R0 R0 8              ; Get EXP->CDR
	LOAD32 R0 R0 4              ; Using EXP->CDR->CAR
	JUMP @process_cons_done     ; Simply use it as the result

:process_cons_define
	LOADUI R3 $s_define         ; Using s_define
	CMPJUMPI.NE R4 R3 @process_cons_set

	;; Deal with special case of Define statements
	LOAD32 R2 R0 8              ; Using EXP->CDR
	LOAD32 R0 R2 8              ; Get EXP->CDR->CDR
	LOAD32 R0 R0 4              ; Using EXP->CDR->CDR->CAR
	CALLI R15 @eval             ; Recurse to figure out what it is
	SWAP R2 R1                  ; Put Environment in the right place
	SWAP R1 R0                  ; Put Evaluation in the right place
	LOAD32 R0 R0 4              ; Using EXP->CDR->CAR
	CALLI R15 @extend_env       ; EXTEND_ENV
	JUMP @process_cons_done     ; Simply use what was returned

:process_cons_set
	LOADUI R3 $s_setb           ; Using s_setb
	CMPJUMPI.NE R4 R3 @process_cons_let

	CALLI R15 @process_setb     ; Deal with special case of SET statements
	JUMP @process_cons_done     ; Simply Return Result

:process_cons_let
	LOADUI R3 $s_let            ; Using s_let
	CMPJUMPI.NE R4 R3 @process_cons_apply

	CALLI R15 @process_let      ; Deal with special case of LET statements
	JUMP @process_cons_done     ; Simply Return Result

:process_cons_apply
	;; Deal with the last option for a CONS, APPLY
	LOAD32 R2 R0 4              ; Protect EXP->CAR
	LOAD32 R0 R0 8              ; Using EXP->CDR
	CALLI R15 @evlis            ; EVLIS
	SWAP R0 R2                  ; Protect EVLIS result
	CALLI R15 @eval             ; Recurse to figure out what to APPLY
	MOVE R1 R2                  ; Put EVLIS result in right place
	CALLI R15 @apply            ; Apply what was found to the EVLIS result

:process_cons_done
	POPR R4 R15                 ; Restore R2
	POPR R3 R15                 ; Restore R2
	POPR R2 R15                 ; Restore R2
	RET R15


;; prim_apply
;; Recieves arglist in R0
;; Returns result of applying ARGS->CAR to ARGS->CDR->CAR
:prim_apply_String
	"apply"
:prim_apply
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1

	LOAD32 R1 R0 8              ; Get ARGS->CDR
	LOAD32 R1 R1 4              ; Get ARGS->CDR->CAR
	LOAD32 R0 R0 4              ; Get ARGS->CAR
	CALLI R15 @apply            ; Use backing function

	;; Cleanup
	POPR R1 R15                 ; Restore R1
	RET R15


;; nullp
;; Recieves a CELL in R0
;; Returns NIL if not NIL or TEE if NIL
:nullp_String
	"null?"
:nullp
	PUSHR R1 R15                ; Protect R1
	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOADUI R1 $NIL              ; Using NIL
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	LOADUI R1 $TEE              ; Return TEE
	MOVE R0 R1                  ; Put result in correct register
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_sum
;; Recieves a list in R0
;; Adds all values and returns a Cell with result in R0
:prim_sum_String
	"+"
:prim_sum
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL
	FALSE R2                    ; Initialize our SUM at 0

:prim_sum_0
	CMPJUMPI.E R0 R3 @prim_sum_done
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R1 4              ; Get ARGS->CAR->CAR
	LOAD32 R0 R0 8              ; Set ARGS to ARGS->CDR
	ADD R2 R2 R1                ; sum = sum + value
	JUMP @prim_sum_0            ; Go to next list item

:prim_sum_done
	MOVE R0 R2                  ; Put SUM in right spot
	CALLI R15 @make_int         ; Get our Cell
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_sub
;; Recieves a list in R0
;; Subtracts all of the values and returns a Cell with the result in R0
:prim_sub_String
	"-"
:prim_sub
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL
	LOAD32 R2 R0 4              ; Get ARGS->CAR
	LOAD32 R2 R2 4              ; Using ARGS->CAR->CAR as starting SUM
	LOAD32 R0 R0 8              ; Using ARGS->CDR as args

:prim_sub_0
	CMPJUMPI.E R0 R3 @prim_sub_done
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R1 4              ; Get ARGS->CAR->CAR
	LOAD32 R0 R0 8              ; Set ARGS to ARGS->CDR
	SUB R2 R2 R1                ; sum = sum - value
	JUMP @prim_sub_0            ; Go to next list item

:prim_sub_done
	MOVE R0 R2                  ; Put SUM in right spot
	CALLI R15 @make_int         ; Get our Cell
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_prod
;; Recieves a list in R0
;; Multiplies all of the values and returns a Cell with the result in R0
:prim_prod_String
	"*"
:prim_prod
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL
	LOADUI R2 1                 ; Initialize our Product at 1

:prim_prod_0
	CMPJUMPI.E R0 R3 @prim_prod_done
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R1 4              ; Get ARGS->CAR->CAR
	LOAD32 R0 R0 8              ; Set ARGS to ARGS->CDR
	MUL R2 R2 R1                ; sum = sum + value
	JUMP @prim_prod_0           ; Go to next list item

:prim_prod_done
	MOVE R0 R2                  ; Put SUM in right spot
	CALLI R15 @make_int         ; Get our Cell
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_div
;; Recieves a list in R0
;; Divides all of the values and returns a Cell with the result in R0
:prim_div_String
	"/"
:prim_div
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL
	LOAD32 R2 R0 4              ; Get ARGS->CAR
	LOAD32 R2 R2 4              ; Using ARGS->CAR->CAR as starting SUM
	LOAD32 R0 R0 8              ; Using ARGS->CDR as args

:prim_div_0
	CMPJUMPI.E R0 R3 @prim_div_done
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R1 4              ; Get ARGS->CAR->CAR
	LOAD32 R0 R0 8              ; Set ARGS to ARGS->CDR
	DIV R2 R2 R1                ; sum = sum - value
	JUMP @prim_div_0            ; Go to next list item

:prim_div_done
	MOVE R0 R2                  ; Put result in right spot
	CALLI R15 @make_int         ; Get our Cell
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_mod
;; Recieves a list in R0
;; Remainders all of the values and returns a Cell with the result in R0
:prim_mod_String
	"mod"
:prim_mod
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL
	LOAD32 R2 R0 4              ; Get ARGS->CAR
	LOAD32 R2 R2 4              ; Using ARGS->CAR->CAR as starting SUM
	LOAD32 R0 R0 8              ; Using ARGS->CDR as args

:prim_mod_0
	CMPJUMPI.E R0 R3 @prim_mod_done
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R1 4              ; Get ARGS->CAR->CAR
	LOAD32 R0 R0 8              ; Set ARGS to ARGS->CDR
	MOD R2 R2 R1                ; sum = sum - value
	JUMP @prim_mod_0            ; Go to next list item

:prim_mod_done
	MOVE R0 R2                  ; Put result in right spot
	CALLI R15 @make_int         ; Get our Cell
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_and
;; Recieves a list in R0
;; ANDs all of the values and returns a Cell with the result in R0
:prim_and_String
	"and"
:prim_and
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	LOADUI R4 $TEE              ; Using TEE
	LOADUI R3 $NIL              ; Using NIL

:prim_and_0
	CMPJUMPI.E R0 R3 @prim_and_done
	LOAD32 R2 R0 4              ; Get ARGS->CAR
	CMPJUMPI.NE R2 R4 @prim_and_1
	LOAD32 R0 R0 8              ; Get ARGS->CDR
	JUMP @prim_and_0            ; Go to next list item

:prim_and_1
	COPY R2 R3                  ; Return NIL

:prim_and_done
	MOVE R0 R2                  ; Put result in correct location
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_or
;; Recieves a list in R0
;; ORs all of the values and returns a Cell with the result in R0
:prim_or_String
	"or"
:prim_or
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	LOADUI R4 $TEE              ; Using TEE
	LOADUI R3 $NIL              ; Using NIL

:prim_or_0
	CMPJUMPI.E R0 R3 @prim_or_1
	LOAD32 R2 R0 4              ; Get ARGS->CAR
	CMPJUMPI.E R2 R4 @prim_or_done
	LOAD32 R0 R0 8              ; Get ARGS->CDR
	JUMP @prim_or_0             ; Go to next list item

:prim_or_1
	COPY R2 R3                  ; Couldn't find a true

:prim_or_done
	MOVE R0 R2                  ; Put result in correct location
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_not
;; Recieves a list in R0
;; NOTs first of the values and returns a Cell with the result in R0
:prim_not_String
	"not"
:prim_not
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	LOAD32 R0 R0 4              ; Get ARGS->CAR
	CMPSKIPI.E R0 $TEE          ; If not TEE
	JUMP @prim_not_0            ; Return TEE

	LOADUI R0 $NIL              ; Otherwise return NIL
	JUMP @prim_not_done         ; Return our NIL

:prim_not_0
	LOADUI R0 $TEE              ; Make TEE

:prim_not_done
	RET R15


;; prim_numgt
;; Recieves a list in R0
;; Compares values and returns a Cell with the result in R0
:prim_numgt_String
	">"
:prim_numgt
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL
	LOAD32 R2 R0 4              ; Get ARGS->CAR
	LOAD32 R2 R2 4              ; Using ARGS->CAR->CAR as starting Value
	LOAD32 R0 R0 8              ; Using ARGS->CDR as args

:prim_numgt_0
	CMPJUMPI.E R0 R3 @prim_numgt_1
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R1 4              ; Get ARGS->CAR->CAR
	LOAD32 R0 R0 8              ; Set ARGS to ARGS->CDR
	CMPJUMPI.LE R2 R1 @prim_numgt_2
	MOVE R2 R1                  ; Prepare for next loop
	JUMP @prim_numgt_0          ; Go to next list item

:prim_numgt_1
	LOADUI R0 $TEE              ; Return TEE
	JUMP @prim_numgt_done       ; Be done

:prim_numgt_2
	LOADUI R0 $NIL              ; Return NIL

:prim_numgt_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_numge
;; Recieves a list in R0
;; Compares values and returns a Cell with the result in R0
:prim_numge_String
	">="
:prim_numge
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL
	LOAD32 R2 R0 4              ; Get ARGS->CAR
	LOAD32 R2 R2 4              ; Using ARGS->CAR->CAR as starting Value
	LOAD32 R0 R0 8              ; Using ARGS->CDR as args

:prim_numge_0
	CMPJUMPI.E R0 R3 @prim_numge_1
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R1 4              ; Get ARGS->CAR->CAR
	LOAD32 R0 R0 8              ; Set ARGS to ARGS->CDR
	CMPJUMPI.L R2 R1 @prim_numge_2
	MOVE R2 R1                  ; Prepare for next loop
	JUMP @prim_numge_0          ; Go to next list item

:prim_numge_1
	LOADUI R0 $TEE              ; Return TEE
	JUMP @prim_numge_done       ; Be done

:prim_numge_2
	LOADUI R0 $NIL              ; Return NIL

:prim_numge_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_numeq
;; Recieves a list in R0
;; Compares values and returns a Cell with the result in R0
:prim_numeq_String
	"="
:prim_numeq
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL
	LOAD32 R2 R0 4              ; Get ARGS->CAR
	LOAD32 R2 R2 4              ; Using ARGS->CAR->CAR as starting Value
	LOAD32 R0 R0 8              ; Using ARGS->CDR as args

:prim_numeq_0
	CMPJUMPI.E R0 R3 @prim_numeq_1
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R1 4              ; Get ARGS->CAR->CAR
	LOAD32 R0 R0 8              ; Set ARGS to ARGS->CDR
	CMPJUMPI.NE R2 R1 @prim_numeq_2
	MOVE R2 R1                  ; Prepare for next loop
	JUMP @prim_numeq_0          ; Go to next list item

:prim_numeq_1
	LOADUI R0 $TEE              ; Return TEE
	JUMP @prim_numge_done       ; Be done

:prim_numeq_2
	LOADUI R0 $NIL              ; Return NIL

:prim_numeq_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_numle
;; Recieves a list in R0
;; Compares values and returns a Cell with the result in R0
:prim_numle_String
	"<="
:prim_numle
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL
	LOAD32 R2 R0 4              ; Get ARGS->CAR
	LOAD32 R2 R2 4              ; Using ARGS->CAR->CAR as starting Value
	LOAD32 R0 R0 8              ; Using ARGS->CDR as args

:prim_numle_0
	CMPJUMPI.E R0 R3 @prim_numle_1
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R1 4              ; Get ARGS->CAR->CAR
	LOAD32 R0 R0 8              ; Set ARGS to ARGS->CDR
	CMPJUMPI.G R2 R1 @prim_numle_2
	MOVE R2 R1                  ; Prepare for next loop
	JUMP @prim_numle_0          ; Go to next list item

:prim_numle_1
	LOADUI R0 $TEE              ; Return TEE
	JUMP @prim_numle_done       ; Be done

:prim_numle_2
	LOADUI R0 $NIL              ; Return NIL

:prim_numle_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_numlt
;; Recieves a list in R0
;; Compares values and returns a Cell with the result in R0
:prim_numlt_String
	"<"
:prim_numlt
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADUI R3 $NIL              ; Using NIL
	LOAD32 R2 R0 4              ; Get ARGS->CAR
	LOAD32 R2 R2 4              ; Using ARGS->CAR->CAR as starting Value
	LOAD32 R0 R0 8              ; Using ARGS->CDR as args

:prim_numlt_0
	CMPJUMPI.E R0 R3 @prim_numlt_1
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R1 4              ; Get ARGS->CAR->CAR
	LOAD32 R0 R0 8              ; Set ARGS to ARGS->CDR
	CMPJUMPI.GE R2 R1 @prim_numlt_2
	MOVE R2 R1                  ; Prepare for next loop
	JUMP @prim_numlt_0          ; Go to next list item

:prim_numlt_1
	LOADUI R0 $TEE              ; Return TEE
	JUMP @prim_numlt_done       ; Be done

:prim_numlt_2
	LOADUI R0 $NIL              ; Return NIL

:prim_numlt_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_listp
;; Recieves a list in R0
;; Compares values and returns a Cell with the result in R0
:prim_listp_String
	"list?"
:prim_listp
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOAD32 R0 R0 0              ; Get ARGS->CAR->TYPE
	CMPSKIPI.NE R0 16           ; If CONS
	JUMP @prim_listp_0          ; Return TEE

	LOADUI R0 $NIL              ; Otherwise return NIL
	JUMP @prim_listp_done       ; Return our NIL

:prim_listp_0
	LOADUI R0 $TEE              ; Make TEE

:prim_listp_done
	RET R15


;; prim_charp
;; Recieves argslist in R0
;; Returns #t if CHAR else NIL
:prim_charp_String
	"char?"
:prim_charp
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOAD32 R0 R0 0              ; Get ARGS->CAR->TYPE
	CMPSKIPI.NE R0 128          ; If CHAR
	JUMP @prim_charp_0          ; Return TEE

	LOADUI R0 $NIL              ; Otherwise return NIL
	JUMP @prim_charp_done

:prim_charp_0
	LOADUI R0 $TEE              ; Make TEE

:prim_charp_done
	RET R15


;; prim_numberp
;; Recieves argslist in R0
;; Returns #t if NUMBER else NIL
:prim_numberp_String
	"number?"
:prim_numberp
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOAD32 R0 R0 0              ; Get ARGS->CAR->TYPE
	CMPSKIPI.NE R0 4            ; If NUMBER
	JUMP @prim_numberp_0        ; Return TEE

	LOADUI R0 $NIL              ; Otherwise return NIL
	JUMP @prim_numberp_done

:prim_numberp_0
	LOADUI R0 $TEE              ; Make TEE

:prim_numberp_done
	RET R15


;; prim_symbolp
;; Recieves argslist in R0
;; Returns #t if SYMBOL else NIL
:prim_symbolp_String
	"symbol?"
:prim_symbolp
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOAD32 R0 R0 0              ; Get ARGS->CAR->TYPE
	CMPSKIPI.NE R0 8            ; If SYMBOL
	JUMP @prim_symbolp_0        ; Return TEE

	LOADUI R0 $NIL              ; Otherwise return NIL
	JUMP @prim_symbolp_done

:prim_symbolp_0
	LOADUI R0 $TEE              ; Make TEE

:prim_symbolp_done
	RET R15


;; prim_stringp
;; Recieves argslist in R0
;; Returns #t if CHAR else NIL
:prim_stringp_String
	"string?"
:prim_stringp
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOAD32 R0 R0 0              ; Get ARGS->CAR->TYPE
	CMPSKIPI.NE R0 256          ; If CHAR
	JUMP @prim_stringp_0        ; Return TEE

	LOADUI R0 $NIL              ; Otherwise return NIL
	JUMP @prim_stringp_done

:prim_stringp_0
	LOADUI R0 $TEE              ; Make TEE

:prim_stringp_done
	RET R15


;; prim_output
;; Recieves argslist in R0
;; Outputs to whatever is specified in R12 and returns TEE
:prim_output
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	LOADUI R4 $NIL              ; Using NIL
	COPY R1 R12                 ; Set to use desired output

:prim_output_0
	CMPJUMPI.E R0 R4 @prim_output_done
	LOAD32 R3 R0 4              ; Get ARGS->CAR
	LOAD32 R2 R3 0              ; Get ARGS->CAR->TYPE
	SWAP R0 R3                  ; Protect ARGS

	CMPSKIPI.NE R2 4            ; If INT
	CALLI R15 @prim_output_INT  ; Print the value

	CMPSKIPI.NE R2 8            ; If SYM
	CALLI R15 @prim_output_SYM  ; Print the string

	CMPSKIPI.NE R2 16           ; If CONS
	CALLI R15 @prim_output      ; Recurse

	CMPSKIPI.NE R2 128          ; If CHAR
	CALLI R15 @prim_output_CHAR ; Just print the last Char

	LOAD32 R0 R3 8              ; Get ARGS->CDR
	JUMP @prim_output_0         ; Loop until we hit NIL

:prim_output_done
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	LOADUI R0 $TEE              ; Return TEE
	RET R15


;; prim_output_INT
;; Recieves an INT CELL in R0 and desired Output in R1
;; Outputs value and returns
:prim_output_INT
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	LOAD32 R0 R0 4              ; Get ARG->CAR
	CALLI R15 @Write_Int        ; Write it
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; prim_output_SYM
;; Recieves a SYM CELL in R0 and desired Output in R1
;; Outputs string and returns
:prim_output_SYM
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	LOAD32 R0 R0 4              ; Get ARG->CAR
	CALLI R15 @Print_String     ; Print the string
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; prim_output_CHAR
;; Recieves an CHAR CELL in R0 and desired Output in R1
;; Outputs Last CHAR and returns
:prim_output_CHAR
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	LOADU8 R0 R0 7              ; Get ARG->CAR [bottom 8 bits]
	FPUTC                       ; Display desired CHAR
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; prim_stringeq
;; Recieves a list in R0
;; Compares strings and returns a Cell with the result in R0
:prim_stringeq_String
	"string=?"
:prim_stringeq
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	LOADUI R3 $NIL              ; Using NIL
	LOAD32 R1 R0 4              ; Get ARGS->CAR
	LOAD32 R4 R1 4              ; Using ARGS->CAR->CAR as TEMP
	LOAD32 R2 R0 8              ; Using ARGS->CDR as args

:prim_stringeq_0
	CMPJUMPI.E R2 R3 @prim_stringeq_1
	LOAD32 R0 R2 4              ; Get ARGS->CAR
	LOAD32 R0 R0 4              ; Get ARGS->CAR->CAR
	COPY R1 R4                  ; Restore TEMP for string comparison
	CALLI R15 @strcmp           ; Compare the strings
	JUMP.NE R0 @prim_stringeq_2 ; Stop if not equal
	LOAD32 R2 R2 8              ; Set ARGS to ARGS->CDR
	JUMP @prim_stringeq_0       ; Go to next list item

:prim_stringeq_1
	LOADUI R0 $TEE              ; Return TEE
	JUMP @prim_stringeq_done    ; Be done

:prim_stringeq_2
	LOADUI R0 $NIL              ; Return NIL

:prim_stringeq_done
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_display
;; Recieves argslist in R0
;; Outputs to TTY R12 and returns TEE
:prim_display_String
	"display"
:prim_display
	CALLI R15 @prim_output
	RET R15


;; prim_write
;; Recieves argslist in R0
;; Write to Tape_02 and returns TEE
:prim_write_String
	"write"
:prim_write
	LOADUI R12 0x1101           ; Write to Tape_02
	CALLI R15 @prim_output      ; Use shared prim_output
	FALSE R12                   ; Revert to TTY
	RET R15


;; prim_freecell
;; Recieves either NIL or a list in R0
;; If NIL displays header, otherwise just returns number of free cells in R0
:prim_freecell_String
	"free_mem"
:prim_freecell
	PUSHR R1 R15                ; Protect R1
	CMPSKIPI.E R0 $NIL          ; If NOT NIL
	JUMP @prim_freecell_0       ; Skip message

	LOADUI R0 $prim_freecell_Message
	COPY R1 R12                 ; Using Selected Output
	CALLI R15 @Print_String     ; Display our header

:prim_freecell_0
	CALLI R15 @cells_remaining  ; Get number of remaining Cells
	CALLI R15 @make_int         ; Convert integer in R0 to a Cell

:prim_freecell_done
	POPR R1 R15                 ; Restore R1
	RET R15

:prim_freecell_Message
	"Remaining Cells: "


;; prim_integer_to_char
;; Recieves a list in R0
;; Converts INT to CHAR
:prim_integer_to_char_String
	"integer->char"
:prim_integer_to_char
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	LOADUI R2 128               ; Using Type CHAR
	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R0 0              ; Get ARGS->CAR->TYPE
	CMPSKIPI.NE R1 4            ; If Type INT
	STORE32 R2 R0 0             ; Update ARGS->CAR->TYPE

	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_char_to_integer
;; Recieves a list in R0
;; Converts CHAR to INT
:prim_char_to_integer_String
	"char->integer"
:prim_char_to_integer
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	LOADUI R2 4                 ; Using Type INT
	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R0 0              ; Get ARGS->CAR->TYPE
	CMPSKIPI.NE R1 128          ; If Type CHAR
	STORE32 R2 R0 0             ; Update ARGS->CAR->TYPE

	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; string_to_list
;; Recieves a pointer to string in R0
;; Returns a list of chars
:string_to_list
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	MOVE R1 R0                  ; Put string safely out of the way
	LOAD8 R0 R1 0               ; Get string[0]
	JUMP.Z R0 @string_to_list_null
	CALLI R15 @make_char        ; Make seperate CHAR
	SWAP R0 R1                  ; Protect RESULT
	ADDUI R0 R0 1               ; Increment to next iteration
	CALLI R15 @string_to_list   ; Recurse down STRING
	SWAP R0 R1                  ; Put RESULT and TAIL in right spot
	CALLI R15 @make_cons        ; Combine into a Cons
	JUMP @string_to_list_done   ; And simply return result

:string_to_list_null
	LOADUI R0 $NIL              ; Nil terminate list

:string_to_list_done
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_string_to_list
;; Recieves a pointer to a CONS whose CAR should be a STRING
;; Returns a list of CHARs in R0
:prim_string_to_list_String
	"string->list"
:prim_string_to_list
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	PUSHR R1 R15                ; Protect R1

	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOAD32 R1 R0 0              ; Get ARGS->CAR->TYPE
	CMPSKIPI.E R1 256           ; If Not Type STRING
	JUMP @prim_string_to_list_fail

	LOAD32 R0 R0 4              ; Get ARGS->CAR->STRING
	CALLI R15 @string_to_list   ; Convert to List
	JUMP @prim_string_to_list_done

:prim_string_to_list_fail
	LOADUI R0 $NIL              ; Nil terminate list

:prim_string_to_list_done
	POPR R1 R15                 ; Restore R1
	RET R15


;; list_to_string
;; Recieves an index in R0, a String pointer in R1
;; And a list of arguments in R2
;; Alters only R0
:list_to_string
	CMPSKIPI.NE R2 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4

:list_to_string_0
	CMPSKIPI.NE R2 $NIL         ; If NIL Expression
	JUMP @list_to_string_done   ; We are done
	LOAD32 R4 R2 4              ; Get ARGS->CAR
	LOAD32 R3 R4 0              ; Get ARGS->CAR->TYPE

	CMPSKIPI.NE R3 128          ; If Type CHAR
	CALLI R15 @list_to_string_CHAR ; Process

	;; Guess CONS
	SWAP R2 R4                  ; Put i->CAR in i's spot
	CMPSKIPI.NE R3 16           ; If Type CONS
	CALLI R15 @list_to_string   ; Recurse
	SWAP R2 R4                  ; Undo the Guess

	;; Everything else just iterate
	LOAD32 R2 R2 8              ; i = i->CDR
	JUMP @list_to_string_0      ; Lets go again

:list_to_string_CHAR
	LOAD32 R3 R4 4              ; Get ARGS->CAR->VALUE
	STOREX8 R3 R0 R1            ; STRING[INDEX] = i->CAR->VALUE
	ADDUI R0 R0 1               ; INDEX = INDEX + 1
	RET R15                     ; Get back in there

:list_to_string_done
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_list_to_string
;; Recieves a list in R0
;; Returns a String CELL in R0
:prim_list_to_string_String
	"list->string"
:prim_list_to_string
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out

	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2

	MOVE R2 R0                  ; Put Args in correct location and Zero R0
	CALLI R15 @malloc           ; Get where space is free
	MOVE R1 R0                  ; Put String pointer in correct location and Zero R0
	CALLI R15 @list_to_string   ; Call backing function
	ADDUI R0 R0 1               ; NULL Terminate string
	CALLI R15 @malloc           ; Correct malloc

	CALLI R15 @make_string      ; Use pointer to make our string CELL
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_halt
;; Simply HALTS
:prim_halt_String
	"HALT"
:prim_halt
	LOADUI R0 0x1101            ; Clean up after ourselves
	FCLOSE                      ; Close our write tape
	HALT


;; prim_list
;; Simply returns the argument list passed to it in R0
:prim_list_String
	"list"
:prim_list
	RET R15


;; prim_cons
;; Recieves an arglist in R0 and returns a CONS in R0
:prim_cons_String
	"cons"
:prim_cons
	PUSHR R1 R15                ; Protect R1
	LOAD32 R1 R0 8              ; Get ARGS->CDR
	LOAD32 R1 R1 4              ; Use ARGS->CDR->CAR
	LOAD32 R0 R0 4              ; Use ARGS->CAR
	CALLI R15 @make_cons        ; MAKE_CONS
	POPR R1 R15                 ; Restore R1
	RET R15


;; prim_car
;; Recieves an arglist in R0 and returns the CAR in R0
:prim_car_String
	"car"
:prim_car
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOAD32 R0 R0 4              ; Using ARGS->CAR->CAR
	RET R15


;; prim_cdr
;; Recieves an arglist in R0 and returns the CDR in R0
:prim_cdr_String
	"cdr"
:prim_cdr
	CMPSKIPI.NE R0 $NIL         ; If NIL Expression
	RET R15                     ; Just get the Hell out
	LOAD32 R0 R0 4              ; Get ARGS->CAR
	LOAD32 R0 R0 8              ; Using ARGS->CAR->CDR
	RET R15


;; spinup
;; Recieves a symbol in R0 and a primitive in R1
;; Returns nothing but CONS both to all_symbols and top_env
:spinup
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3

	COPY R3 R0                  ; Protect SYM
	MOVE R2 R1                  ; Put PRIM in right Spot
	LOADR R1 @all_symbols       ; Get ALL_SYMBOLS
	CALLI R15 @make_cons        ; MAKE_CONS
	STORER R0 @all_symbols      ; Update ALL_SYMBOLS
	MOVE R1 R3                  ; Restore SYM
	LOADR R0 @top_env           ; Get TOP_ENV
	CALLI R15 @extend           ; EXTEND
	STORER R0 @top_env          ; Update TOP_ENV

	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


	;; Special symbols
;; NIL Object
:NIL
	'00000008'                  ; A Symbol
	&NIL_String                 ; Pointer to string
	'00000000'                  ; NUL CDR
	'00000000'                  ; NUL ENV

:NIL_String
	"nil"


;; TEE Object
:TEE
	'00000008'                  ; A Symbol
	&TEE_String                 ; Pointer to string
	'00000000'                  ; NUL CDR
	'00000000'                  ; NUL ENV

:TEE_String
	"#t"


;; Quote Object
:s_quote
	'00000008'                  ; A Symbol
	&s_quote_String             ; Pointer to string
	'00000000'                  ; NUL CDR
	'00000000'                  ; NUL ENV

:s_quote_String
	"quote"


;; IF Object
:s_if
	'00000008'                  ; A Symbol
	&s_if_String                ; Pointer to string
	'00000000'                  ; NUL CDR
	'00000000'                  ; NUL ENV

:s_if_String
	"if"


;; COND Object
:s_cond
	'00000008'                  ; A Symbol
	&s_cond_String              ; Pointer to string
	'00000000'                  ; NUL CDR
	'00000000'                  ; NUL ENV

:s_cond_String
	"cond"


;; Lambda Object
:s_lambda
	'00000008'                  ; A Symbol
	&s_lambda_String            ; Pointer to string
	'00000000'                  ; NUL CDR
	'00000000'                  ; NUL ENV

:s_lambda_String
	"lambda"


;; Define Object
:s_define
	'00000008'                  ; A Symbol
	&s_define_String            ; Pointer to string
	'00000000'                  ; NUL CDR
	'00000000'                  ; NUL ENV

:s_define_String
	"define"


;; SET Object
:s_setb
	'00000008'                  ; A Symbol
	&s_setb_String              ; Pointer to string
	'00000000'                  ; NUL CDR
	'00000000'                  ; NUL ENV

:s_setb_String
	"set!"

;; LET Object
:s_let
	'00000008'                  ; A Symbol
	&s_let_String               ; Pointer to string
	'00000000'                  ; NUL CDR
	'00000000'                  ; NUL ENV

:s_let_String
	"let"

;; Begin Object
:s_begin
	'00000008'                  ; A Symbol
	&s_begin_String             ; Pointer to string
	'00000000'                  ; NUL CDR
	'00000000'                  ; NUL ENV

:s_begin_String
	"begin"


	;; Globals of interest
:all_symbols
	&all_symbols_init

:all_symbols_init
	'00000010'                  ; A CONS
	&NIL                        ; Pointer to NIL
	&NIL                        ; Pointer to NIL
	'00000000'                  ; NULL


:top_env
	&top_env_init_1

:top_env_init_0
	'00000010'                  ; A CONS
	&NIL                        ; Pointer to NIL
	&NIL                        ; Pointer to NIL
	'00000000'                  ; NULL

:top_env_init_1
	'00000010'                  ; A CONS
	&top_env_init_0             ; Pointer to CONS of NIL
	&NIL                        ; Pointer to NIL
	'00000000'                  ; NULL


:free_cells
	NOP                         ; Start with NULL


;; Global init function
;; Recieves nothing
;; Returns nothing
;; sets up all_symbols and top_env
:init_sl3
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1

	;; Add Eval Specials
	LOADUI R0 $TEE              ; Get TEE
	COPY R1 R0                  ; Duplicate TEE
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $s_quote          ; Get s_quote
	COPY R1 R0                  ; Duplicate s_quote
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $s_if             ; Get s_if
	COPY R1 R0                  ; Duplicate s_if
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $s_cond           ; Get s_cond
	COPY R1 R0                  ; Duplicate s_cond
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $s_lambda         ; Get s_lambda
	COPY R1 R0                  ; Duplicate s_lambda
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $s_define         ; Get s_define
	COPY R1 R0                  ; Duplicate s_define
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $s_setb           ; Get s_setb
	COPY R1 R0                  ; Duplicate s_setb
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $s_let            ; Get s_let
	COPY R1 R0                  ; Duplicate s_let
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $s_begin          ; Get s_begin
	COPY R1 R0                  ; Duplicate s_if
	CALLI R15 @spinup           ; SPINUP

	;; Add Primitive Specials
	LOADUI R0 $prim_apply       ; Using PRIM_APPLY
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_apply_String ; Using PRIM_APPLY_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $nullp            ; Using NULLP
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $nullp_String     ; Using NULLP_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_sum         ; Using PRIM_SUM
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_sum_String  ; Using PRIM_SUM_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_sub         ; Using PRIM_SUB
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_sub_String  ; Using PRIM_SUB_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_prod        ; Using PRIM_PROD
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_prod_String ; Using PRIM_PROD_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_div         ; Using PRIM_DIV
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_div_String  ; Using PRIM_DIV_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_mod         ; Using PRIM_MOD
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_mod_String  ; Using PRIM_MOD_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_and         ; Using PRIM_AND
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_and_String  ; Using PRIM_AND_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_or          ; Using PRIM_OR
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_or_String   ; Using PRIM_OR_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_not         ; Using PRIM_NOT
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_not_String  ; Using PRIM_NOT_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_numgt       ; Using PRIM_NUMGT
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_numgt_String ; Using PRIM_NUMGT_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_numge       ; Using PRIM_NUMGE
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_numge_String ; Using PRIM_NUMGE_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_numeq       ; Using PRIM_NUMEQ
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_numeq_String ; Using PRIM_NUMEQ_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_numle       ; Using PRIM_NUMLE
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_numle_String ; Using PRIM_NUMLE_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_numlt       ; Using PRIM_NUMLT
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_numlt_String ; Using PRIM_NUMLT_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_listp       ; Using PRIM_LISTP
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_listp_String ; Using PRIM_LISTP_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_charp       ; Using PRIM_CHARP
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_charp_String ; Using PRIM_CHARP_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_numberp     ; Using PRIM_NUMBERP
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_numberp_String ; Using PRIM_NUMBERP_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_symbolp     ; Using PRIM_SYMBOLP
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_symbolp_String ; Using PRIM_SYMBOLP_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_stringp     ; Using PRIM_STRINGP
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_stringp_String ; Using PRIM_STRINGP_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_display     ; Using PRIM_DISPLAY
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_display_String ; Using PRIM_DISPLAY_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_write       ; Using PRIM_WRITE
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_write_String ; Using PRIM_WRITE_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_freecell    ; Using PRIM_FREECELL
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_freecell_String ; Using PRIM_FREECELL_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_integer_to_char ; Using PRIM_INTEGER_TO_CHAR
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_integer_to_char_String ; Using PRIM_INTEGER_TO_CHAR_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_char_to_integer ; Using PRIM_CHAR_TO_INTEGER
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_char_to_integer_String ; Using PRIM_CHAR_TO_INTEGER_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_string_to_list ; Using PRIM_STRING_TO_LIST
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_string_to_list_String ; Using PRIM_STRING_TO_LIST_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_list_to_string ; Using PRIM_LIST_TO_STRING
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_list_to_string_String ; Using PRIM_LIST_TO_STRING_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_halt        ; Using PRIM_HALT
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_halt_String ; Using PRIM_HALT_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_list        ; Using PRIM_list
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_list_String ; Using PRIM_LIST_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_stringeq    ; Using PRIM_STRINGEQ
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_stringeq_String ; Using PRIM_STRINGEQ_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_cons        ; Using PRIM_CONS
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_cons_String ; Using PRIM_CONS_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_car         ; Using PRIM_CAR
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_car_String  ; Using PRIM_CAR_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	LOADUI R0 $prim_cdr         ; Using PRIM_CDR
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_cdr_String  ; Using PRIM_CDR_STRING
	CALLI R15 @make_sym         ; MAKE_SYM
	CALLI R15 @spinup           ; SPINUP

	;; Clean up
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; Left_to_take
;; The number of cells_remaining
:left_to_take
	NOP

;; cells_remaining
;; Recieves nothing and returns number of remaining cells in R0
:cells_remaining
	LOADR R0 @left_to_take      ; Get number of cells left
	RET R15


;; update_remaining
;; Recieves nothing
;; Returns nothing
;; Updates left_to_take via counting
:update_remaining
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1

	LOADR R0 @free_cells        ; Get FREE_CELLS
	FALSE R1                    ; Set Count to 0

:update_remaining_0
	JUMP.Z R0 @update_remaining_done
	ADDUI R1 R1 1               ; Increment by 1
	LOAD32 R0 R0 8              ; get I->CDR
	JUMP @update_remaining_0    ; Keep looping til NULL

:update_remaining_done
	STORER R1 @left_to_take     ; update left_to_take
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; gc_block_start
:gc_block_start
	&Start_CONS

;; top_allocated
:top_allocated
	'000FFFF0'


;; insert_ordered
;; Recieves a cell and a list of cells in R0 and R1
;; Inserts cell into the list from lowest to highest
;; Returns resulting list in R0
:insert_ordered
	CMPSKIPI.NE R1 0            ; If List is NULL
	RET R15                     ; Just return CELL
	CMPJUMPI.GE R0 R1 @insert_ordered_0
	STORE32 R1 R0 8             ; Set I->CDR to LIST
	RET R15                     ; Simply return I

:insert_ordered_0
	PUSHR R1 R15                ; Protect List from recursion
	LOAD32 R1 R1 8              ; Using LIST->CDR
	CALLI R15 @insert_ordered   ; Recurse
	POPR R1 R15                 ; Restore LIST
	STORE32 R0 R1 8             ; Set LIST->CDR to the result of recursion
	MOVE R0 R1                  ; Prepare for return
	RET R15


;; reclaim_marked
;; Recieves nothing
;; Returns nothing
;; Reclaims and updates free_cells
:reclaim_marked
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADR R3 @gc_block_start    ; Using GC_BLOCK_START
	LOADR R2 @top_allocated     ; Using TOP_ALLOCATED

:reclaim_marked_0
	CMPJUMPI.LE R2 R3 @reclaim_marked_done
	LOAD32 R1 R2 0              ; Get I->TYPE
	ANDI R1 R1 2                ; AND with MARKED
	JUMP.Z R1 @reclaim_marked_1 ; Deal with MARKED CELLS or jump on NULL

	;; Deal with Marked
	LOADUI R0 1                 ; Using FREE
	STORE32 R0 R2 0             ; Set I->TYPE to FREE
	FALSE R0                    ; USING NULL
	STORE32 R0 R2 4             ; SET I->CAR to NULL
	STORE32 R0 R2 12            ; SET I->ENV to NULL
	COPY R0 R2                  ; Prepare for INSERT_ORDERED
	LOADR R1 @free_cells        ; Get FREE_CELLS
	CALLI R15 @insert_ordered   ; Get New FREE_CELLS Pointer
	STORER R0 @free_cells       ; Update FREE_CELLS to I

	;; Deal with unmarked
:reclaim_marked_1
	SUBUI R2 R2 16              ; Decrement I by the size of a CELL
	JUMP @reclaim_marked_0      ; Iterate on next CELL

:reclaim_marked_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; mark_all_cells
;; Recieves nothing
;; Returns nothing
;; Marks all unfree cells
:mark_all_cells
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADR R0 @gc_block_start    ; Using GC_BLOCK_START
	LOADR R1 @top_allocated     ; Using TOP_ALLOCATED

:mark_all_cells_0
	CMPJUMPI.GE R0 R1 @mark_all_cells_done
	LOAD32 R2 R0 0              ; Get I->TYPE
	CMPSKIPI.NE R2 1            ; If NOT FREE
	JUMP @mark_all_cells_1      ; Move onto the Next

	;; Mark non-free cell
	ORI R2 R2 2                 ; Add MARK
	STORE32 R2 R0 0             ; Write out MARK

:mark_all_cells_1
	ADDUI R0 R0 16              ; Increment I by the size of a CELL
	JUMP @mark_all_cells_0      ; Iterate on next CELL

:mark_all_cells_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; unmark_cells
;; Recieves a List in R0 and R1 and a Count in R2
;; Returns nothing
;; Unmarks all connected Cells
:unmark_cells
	CMPSKIPI.LE R2 2            ; If Greater than 1
	RET R15                     ; Just return
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	LOADUI R4 2                 ; GET MARKED
	NOT R4 R4                   ; Use ~MARKED

:unmark_cells_0
	JUMP.Z R0 @unmark_cells_done
	CMPSKIP.NE R0 R1            ; If LIST == STOP
	ADDUI R2 R2 1               ; Increment Count
	LOAD32 R3 R0 0              ; Get I->TYPE
	AND R3 R3 R4                ; Remove MARK
	STORE32 R3 R0 0             ; Store the cleaned type

	;; Deal with CONS
	CMPSKIPI.NE R3 16           ; If A CONS
	JUMP @unmark_cells_cons     ; Deal with it

	;; Deal with PROC
	CMPSKIPI.NE R3 32           ; If A PROC
	JUMP @unmark_cells_proc     ; Deal with it

	;; Everything else
	JUMP @unmark_cells_1        ; Move onto NEXT

:unmark_cells_proc
	LOAD32 R3 R0 12            ; Using list->ENV
	CMPSKIPI.NE R3 0            ; If NULL
	JUMP @unmark_cells_cons     ; Skip
	SWAP R0 R3                  ; Protect list
	CALLI R15 @unmark_cells     ; Recurse until the ends
	SWAP R0 R3                  ; Put list back

:unmark_cells_cons
	LOAD32 R3 R0 4              ; Using list->CAR
	SWAP R0 R3                  ; Protect list
	CALLI R15 @unmark_cells     ; Recurse until the ends
	SWAP R0 R3                  ; Put list back

:unmark_cells_1
	LOAD32 R0 R0 8              ; Get list->CDR
	JUMP @unmark_cells_0        ; Keep going down list

:unmark_cells_done
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; relocate_cell
;; Recieves a current, target and List in R0, R1 and R2
;; Returns nothing
;; Relocate all references to a cell and walks down list
:relocate_cell
	PUSHR R3 R15                ; Protect R3

:relocate_cell_0
	JUMP.Z R2 @relocate_cell_done

	;; Fix CAR References
	LOAD32 R3 R2 4              ; Get LIST->CAR
	CMPSKIP.NE R0 R3            ; If match with Current
	STORE32 R1 R2 4             ; Fix LIST->CAR

	;; Fix CDR References
	LOAD32 R3 R2 8              ; Get LIST->CDR
	CMPSKIP.NE R0 R3            ; If match with Current
	STORE32 R1 R2 8             ; Fix LIST->CDR

	;; Fix ENV References
	LOAD32 R3 R2 12             ; Get LIST->ENV
	CMPSKIP.NE R0 R3            ; If match with Current
	STORE32 R1 R2 12            ; Fix LIST->ENV

	LOAD32 R3 R2 0              ; Get LIST->TYPE

	;; Deal with CONS
	CMPSKIPI.NE R3 16           ; If A CONS
	JUMP @relocate_cell_proc    ; Deal with it

	;; Deal with PROC
	CMPSKIPI.NE R3 32           ; If A PROC
	JUMP @relocate_cell_proc    ; Deal with it

	;; Everything else
	JUMP @relocate_cell_1       ; Move onto NEXT

:relocate_cell_proc
	PUSHR R2 R15                ; Protect LIST
	LOAD32 R2 R2 4              ; Using list->CAR
	CALLI R15 @relocate_cell    ; Recurse until the ends
	POPR R2 R15                 ; Restore LIST

:relocate_cell_1
	LOAD32 R2 R2 8              ; Get list->CDR
	JUMP @relocate_cell_0       ; Keep going down list

:relocate_cell_done
	POPR R3 R15                 ; Restore R3
	RET R15


;; compact
;; Recieves a List in R0
;; Returns nothing
;; Finds cells to relocate and has all references updated
:compact
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2

:compact_0
	JUMP.Z R0 @compact_done

	LOAD32 R2 R0 0              ; Get LIST->TYPE
	CMPSKIPI.NE R2 1            ; If LIST->TYPE == FREE
	JUMP @compact_1             ; Not worth relocating

	LOADR R1 @free_cells        ; Get FREE_CELLS
	CMPJUMPI.LE R0 R1 @compact_1 ; Don't bother to relocate if Low

	;; Found a better place for cell
	SWAP R0 R1                  ; Get LIST out of the way
	CALLI R15 @pop_cons         ; Get our New location
	SWAP R0 R1                  ; Put in correct order

	;; Update temp to LIST
	LOAD32 R2 R0 0              ; Get LIST->TYPE
	STORE32 R2 R1 0             ; Set TEMP->TYPE
	LOAD32 R2 R0 4              ; GET LIST->CAR
	STORE32 R2 R1 4             ; Set TEMP->CAR
	LOAD32 R2 R0 8              ; GET LIST->CDR
	STORE32 R2 R1 8             ; Set TEMP->CDR
	LOAD32 R2 R0 12             ; GET LIST->ENV
	STORE32 R2 R1 12            ; Set TEMP->ENV

	;; Fix Reference in Symbols list
	LOADR R2 @all_symbols
	CALLI R15 @relocate_cell

	;; Fix References in Environment list
	LOADR R2 @top_env
	CALLI R15 @relocate_cell

	LOAD32 R2 R0 0              ; Get LIST->TYPE

:compact_1
	;; Deal with CONS
	CMPSKIPI.NE R2 16           ; If A CONS
	JUMP @compact_proc          ; Deal with it

	;; Deal with PROC
	CMPSKIPI.NE R2 32           ; If A PROC
	JUMP @compact_proc          ; Deal with it

	;; Everything else
	JUMP @compact_2             ; Move onto NEXT

:compact_proc
	PUSHR R0 R15                ; Protect LIST
	LOAD32 R0 R0 4              ; Using list->CAR
	CALLI R15 @compact          ; Recurse until the ends
	POPR R0 R15                 ; Restore LIST

:compact_2
	LOAD32 R0 R0 8              ; Get list->CDR
	JUMP @compact_0             ; Keep going down list

:compact_done
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; garbage_collect
;; Recieves nothing
;; Returns nothing
;; The Core of Garbage Collection
:garbage_collect
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	CALLI R15 @mark_all_cells   ; MARK_ALL_CELLS
	LOADR R0 @all_symbols       ; Using ALL_SYMBOLS
	COPY R1 R0                  ; Using it as STOP
	FALSE R2                    ; Setting Counter to 0
	CALLI R15 @unmark_cells     ; UNMARK ALL_SYMBOLS
	LOADR R0 @top_env           ; Using TOP_ENV
	COPY R1 R0                  ; Using it as STOP
	FALSE R2                    ; Setting Counter to 0
	CALLI R15 @unmark_cells     ; UNMARK TOP_ENV
	CALLI R15 @reclaim_marked   ; RECLAIM_MARKED
	CALLI R15 @update_remaining ; Fix the Count
	LOADR R0 @all_symbols       ; Using Symbols list
	CALLI R15 @compact          ; Compact
	LOADR R0 @top_env           ; Using TOP_ENV
	CALLI R15 @compact          ; Compact
	FALSE R0                    ; Using NULL
	STORER R0 @top_allocated    ; Clear TOP_ALLOCATED
	POPR R2 R15                 ; Restore R
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; garbage_init
;; Recieves nothing
;; Returns nothing
;; Initializes Garbage Heap
:garbage_init
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	LOADR R0 @gc_block_start    ; Get Starting Offset
	ANDI R0 R0 0xF              ; We only need the buttom 4 Bits
	LOADR R1 @top_allocated     ; Get End Address
	ADD R1 R1 R0                ; Add the Offset
	SUBUI R1 R1 16              ; Shift Back Down
	STORER R1 @top_allocated    ; Update Block End
	CALLI R15 @mark_all_cells   ; MARK_ALL_CELLS
	CALLI R15 @reclaim_marked   ; RECLAIM_MARKED
	CALLI R15 @update_remaining ; Fix the Count
	FALSE R0                    ; Using NULL
	STORER R0 @top_allocated    ; Clear TOP_ALLOCATED
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; pop_cons
;; Recieves nothing
;; Returns a Free CONS in R0
;; Updates left_to_take
:pop_cons
	PUSHR R1 R15                ; Protect R1
	LOADR R0 @free_cells        ; Get First Free Cell
	JUMP.Z R0 @pop_cons_error   ; If NULL BURN with FIRE
	LOAD32 R1 R0 8              ; Get I->CDR
	STORER R1 @free_cells       ; Update FREE_CELLS
	FALSE R1                    ; Using NULL
	STORE32 R1 R0 8             ; SET I->CDR to NULL
	LOADR R1 @top_allocated     ; Get top allocation
	CMPSKIP.LE R0 R1            ; Skip if I <= TOP_ALLOCATED
	STORER R0 @top_allocated    ; Update TOP_ALLOCATED to new highest allocation
	LOADR R1 @left_to_take      ; Get LEFT_TO_TAKE
	SUBUI R1 R1 1               ; Decrement by 1
	STORER R1 @left_to_take     ; Update LEFT_TO_TAKE
	POPR R1 R15                 ; Restore R1
	RET R15

:pop_cons_error
	LOADUI R0 $pop_cons_Message ; Using Message
	FALSE R1                    ; Using TTY
	CALLI R15 @Print_String     ; Display ERROR
	HALT                        ; Burn with FIRE

:pop_cons_Message
	"OOOPS we ran out of cells"


;; make_int
;; Recieves an Integer in R0
;; Returns a CELL in R0
:make_int
	PUSHR R1 R15                ; Protect R1
	MOVE R1 R0                  ; Protect Integer
	CALLI R15 @pop_cons         ; Get a CELL
	STORE32 R1 R0 4             ; Set C->CAR
	LOADUI R1 4                 ; Using INT
	STORE32 R1 R0 0             ; Set C->TYPE
	POPR R1 R15                 ; Restore R1
	RET R15


;; make_char
;; Recieves a CHAR in R0
;; Returns a CELL in R0
:make_char
	PUSHR R1 R15                ; Protect R1
	MOVE R1 R0                  ; Protect Integer
	CALLI R15 @pop_cons         ; Get a CELL
	STORE32 R1 R0 4             ; Set C->CAR
	LOADUI R1 128               ; Using CHAR
	STORE32 R1 R0 0             ; Set C->TYPE
	POPR R1 R15                 ; Restore R1
	RET R15


;; make_string
;; Recieves a string pointer in R0
;; Returns a CELL in R0
:make_string
	PUSHR R1 R15                ; Protect R1
	MOVE R1 R0                  ; Protect Integer
	CALLI R15 @pop_cons         ; Get a CELL
	STORE32 R1 R0 4             ; Set C->CAR
	LOADUI R1 256               ; Using STRING
	STORE32 R1 R0 0             ; Set C->TYPE
	POPR R1 R15                 ; Restore R1
	RET R15


;; make_sym
;; Recieves a string pointer in R0
;; Returns a Cell in R0
:make_sym
	PUSHR R1 R15                ; Protect R1
	MOVE R1 R0                  ; Protect String Pointer
	CALLI R15 @pop_cons         ; Get a CELL
	STORE32 R1 R0 4             ; Set C->CAR
	LOADUI R1 8                 ; Using SYM
	STORE32 R1 R0 0             ; Set C->TYPE
	POPR R1 R15                 ; Restore R1
	RET R15


;; make_cons
;; Recieves a Cell in R0 and R1
;; Returns a combined Cell in R0
:make_cons
	PUSHR R2 R15                ; Protect R2
	MOVE R2 R0                  ; Protect CELL A
	CALLI R15 @pop_cons         ; Get a CELL
	STORE32 R2 R0 4             ; Set C->CAR
	STORE32 R1 R0 8             ; SET C->CDR
	LOADUI R2 16                ; Using CONS
	STORE32 R2 R0 0             ; Set C->TYPE
	POPR R2 R15                 ; Restore R2
	RET R15


;; make_proc
;; Recieves Cells in R0, R1 and R2
;; Returns a combined Cell in R0
:make_proc
	PUSHR R3 R15                ; Protect R3
	MOVE R3 R0                  ; Protect CELL
	CALLI R15 @pop_cons         ; Get a CELL
	STORE32 R3 R0 4             ; Set C->CAR
	STORE32 R1 R0 8             ; Set C->CDR
	STORE32 R2 R0 12            ; Set C->ENV
	LOADUI R3 32                ; Using PROC
	STORE32 R3 R0 0             ; Set C->TYPE
	POPR R3 R15                 ; Restore R3
	RET R15


;; make_prim
;; Recieves pointer to function in R0
;; Returns a Cell in R0
:make_prim
	PUSHR R1 R15                ; Protect R1
	MOVE R1 R0                  ; Protect Function Pointer
	CALLI R15 @pop_cons         ; Get a CELL
	STORE32 R1 R0 4             ; Set C->CAR
	LOADUI R1 64                ; Using PRIMOP
	STORE32 R1 R0 0             ; Set C->TYPE
	POPR R1 R15                 ; Restore R1
	RET R15


;; CONS starts at the end of the program
:Start_CONS
