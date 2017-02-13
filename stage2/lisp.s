	;; A simple lisp with a precise garbage collector for cells
	;; Cells are in the following form:
	;; Type (0), CAR (4), CDR (8), ENV (12)
	;; Each being the length of a register [32bits]
	;;
	;; Type maps to the following values
	;; FREE = 1, MARKED = (1 << 1),INT = (1 << 2),SYM = (1 << 3),
	;; CONS = (1 << 4),PROC = (1 << 5),PRIMOP = (1 << 6),ASCII = (1 << 7)

	;; CONS space: End of program -> 1.5MB (0x180000)
	;; HEAP space: 1.5MB -> 1.75MB (0x1C0000)
	;; STACK space: 1.75MB -> End of Memory (2MB (0x200000))

;; Start function
:start
	LOADR R15 @stack_start      ; Put stack after CONS and HEAP
	;; We will be using R14 for our condition codes
	;; We will be using R13 for which Input we will be using
	;; We will be using R12 for which Output we will be using

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

:stack_start
	'001C0000'

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

	LOAD32 R1 R0 4              ; Get CAR
	LOADU8 R2 R1 0              ; Get first Char

	CMPSKIPI.E R2 39            ; If Not Quote Char
	JUMP @atom_integer          ; Move to next type

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
;; Starting at 64KB
:malloc_pointer
	'00180000'


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
	FALSE R1                    ; Using TTY
	FPUTC                       ; Display the Char we just pressed
	COPY R1 R13                 ; Set desired IO

	CMPSKIPI.G R0 4             ; If EOF
	CALLI R15 @Switch_Input     ; Do the correct thing

	CMPSKIP.E R1 R13            ; If IO source changed
	JUMP @Readline_done         ; We finished

	CMPSKIPI.G R0 32            ; If SPACE or below
	JUMP @Readline_1

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
	CMPSKIPI.NE R0 10           ; If LF
	JUMP @Readline_loop         ; Resume

	JUMP @Readline_0            ; Otherwise Keep Looping

	;; Deal with Whitespace and Control Chars
:Readline_1
	CMPSKIPI.NE R4 0            ; IF Depth 0
	JUMP @Readline_done         ; We made it to the end

	LOADUI R0 32                ; Otherwise convert to SPACE
	STOREX8 R0 R2 R3            ; Append to String
	ADDUI R3 R3 1               ; Increment Size

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
	LOADR R2 @Max_Decimal       ; Starting from the Top
	LOADUI R5 10                ; We move down by 10
	FALSE R4                    ; Flag leading Zeros

:Write_Int_0
	DIVIDE R0 R3 R3 R2          ; Break off top 10
	CMPSKIPI.NE R0 0            ; If Not Zero
	TRUE R4                     ; Flip the Flag

	ADDUI R0 R0 48              ; Shift into ASCII
	CMPSKIPI.NE R0 48           ; If top was Zero
	CMPSKIPI.NE R4 0            ; Don't print leading Zeros
	FPUTC                       ; Print Top

	DIV R2 R2 R5                ; Look at next 10
	CMPSKIPI.E R2 0             ; If we reached the bottom STOP
	JUMP @Write_Int_0           ; Otherwise keep looping

	;; Cleanup
	LOADUI R0 10                ; Append Newline
	FPUTC                       ; Print it
	POPR R5 R15                 ; Restore R5
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


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

	CMPSKIPI.NE R2 128          ; If ASCII
	JUMP @writeobj_ASCII        ; Print the Char

	;; What the hell is that???
	HALT

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

	LOAD32 R0 R3 8              ; Get HEAD->CDR
	LOADUI R3 $NIL              ; Using NIL
	CMPSKIP.NE R0 R3            ; If NIL
	JUMP @writeobj_CONS_1       ; Break out of loop
	CALLI R15 @writeobj         ; Recurse on HEAD->CDR

:writeobj_CONS_1
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

:writeobj_ASCII
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
;; Returns a CONS of CONS in R0, Clears R1 and R2
:extend
	PUSHR R0 R15                ; Protect the env until we need it
	MOVE R0 R1                  ; Prepare Symbol for call
	MOVE R1 R2                  ; Prepare value for call and Clear R2
	CALLI R15 @make_cons        ; Make inner CONS
	POPR R1 R15                 ; Get env now that we need it
	CALLI R15 @make_cons        ; Make outter CONS
	FALSE R1                    ; Clear R1
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


;; extend_top
;; Recieves a Symbol in R0 and a Value in R1
;; Returns Value in R0 after extending top
:extend_top
	PUSHR R1 R15                ; Protect Val
	PUSHR R2 R15                ; Protect R2
	CALLI R15 @make_cons        ; Make a cons of SYM and VAL
	LOADR32 R2 @top_env         ; Get TOP_ENV
	LOAD32 R1 R2 8              ; Using TOP_ENV->CDR
	CALLI R15 @make_cons        ; Make final CONS
	STORE32 R0 R2 8             ; TOP_ENV->CDR = CONS
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

:assoc_0
	CMPJUMPI.E R1 R4 @assoc_done
	LOAD32 R2 R1 4              ; ALIST->CAR
	LOAD32 R3 R2 4              ; ALIST->CAR->CAR
	LOAD32 R1 R1 8              ; ALIST = ALIST->CDR
	CMPSKIP.NE R0 R3            ; If ALIST->CAR->CAR != KEY
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
	LOAD32 R2 R0 8              ; Protect EXPRS->CDR
	LOAD32 R0 R0 4              ; Using EXPRS->CAR
	CALLI R15 @eval             ; EVAL
	SWAP R0 R2                  ; Using EXPRS->CDR
	MOVE R1 R3                  ; Restore ENV
	CALLI R15 @evlis            ; Recursively Call self Down Expressions
	MOVE R1 R2                  ; Using result of EVAL and EVLIS
	SWAP R1 R0                  ; Put in Proper Order
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

	LOAD32 R3 R0 8              ; Protect PROC->CDR
	MOVE R2 R1                  ; Put Values in right place
	LOAD32 R1 R0 4              ; Using PROC->CAR
	LOAD32 R0 R0 12             ; Using PROC->ENV
	CALLI R15 @multiple_extend  ; Multiple_extend
	MOVE R1 R0                  ; Put Extended_Env in the right place
	MOVE R0 R3                  ; Using PROC->CDR
	CALLI R15 @progn            ; PROGN
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
	MOVE R0 R3                  ; Prepare EXP->CDR
	CMPSKIPI.NE R0 $NIL         ; If EXP->CDR == NIL
	MOVE R4 R0                  ; Use NIL as our Return
	JUMP.NZ R0 @evcond_0        ; Keep looping until NIL or True
	MOVE R0 R4                  ; Put return in the right place
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

	CALLI R15 @assoc            ; ASSOC
	CMPSKIPI.NE R0 $NIL         ; If NIL is returned
	JUMP @eval_bad_Symbol       ; Burn with FIRE

	LOAD32 R0 R0 8              ; Using tmp->CDR
	JUMP @eval_done             ; Return it

:eval_bad_Symbol
	LOADUI R0 $eval_unbound     ; Using the designated Error message
	FALSE R1                    ; Using TTY
	CALLI R15 @Print_String     ; Written for the user
	HALT                        ; Simply toss the rest into the fire

:eval_unbound
	"Unbound symbol"

	;; Deal with special cases of CONS
:eval_cons
	CMPSKIPI.E R4 16            ; If EXP->TYPE is NOT CONS
	JUMP @eval_primop           ; Move onto next Case

	LOAD32 R4 R0 4              ; Using EXP->CAR
	LOADUI R3 $s_if             ; Using s_if
	CMPJUMPI.NE R4 R3 @eval_cons_cond

	;; deal with special case of If statements
	LOAD32 R3 R0 8              ; Protect EXP->CDR
	LOAD32 R0 R3 4              ; Using EXP->CDR->CAR
	CALLI R15 @eval             ; Recurse to get truth
	CMPSKIPI.E R0 $NIL          ; If Result was NOT NIL
	LOAD32 R3 R3 8              ; Update to EXP->CDR->CDR
	LOAD32 R0 R3 8              ; Get EXP->CDR->CDR
	LOAD32 R0 R0 4              ; Using EXP->CDR->CDR->CAR
	CALLI R15 @eval             ; Recurse to get result
	JUMP @eval_done             ; Return it

:eval_cons_cond
	LOADUI R3 $s_cond           ; Using s_cond
	CMPJUMPI.NE R4 R3 @eval_cons_begin

	;; Deal with special case of COND statements
	LOAD32 R0 R0 8              ; Using EXP->CDR
	CALLI R15 @evcond           ; EVCOND
	JUMP @eval_done             ; Simply use it's result

:eval_cons_begin
	LOADUI R3 $s_begin          ; Using s_begin
	CMPJUMPI.NE R4 R3 @eval_cons_lambda

	;; Deal with special case of BEGIN statements
	LOAD32 R0 R0 8              ; Using EXP->CDR
	CALLI R15 @progn            ; PROGN
	JUMP @eval_done             ; Simply use it's result

:eval_cons_lambda
	LOADUI R3 $s_lambda         ; Using s_lambda
	CMPJUMPI.NE R4 R3 @eval_cons_quote

	;; Deal with special case of lambda statements
	MOVE R2 R1                  ; Put ENV in the right place
	LOAD32 R1 R0 8              ; Get EXP->CDR
	LOAD32 R0 R1 4              ; Using EXP->CDR->CAR
	LOAD32 R1 R1 8              ; Using EXP->CDR->CDR
	CALLI R15 @make_proc        ; MAKE_PROC
	JUMP @eval_done             ; Simply return its result

:eval_cons_quote
	LOADUI R3 $s_quote          ; Using s_quote
	CMPJUMPI.NE R4 R3 @eval_cons_define

	;; Deal with special case of quote statements
	LOAD32 R0 R0 8              ; Get EXP->CDR
	LOAD32 R0 R0 4              ; Using EXP->CDR->CAR
	JUMP @eval_done             ; Simply use it as the result

:eval_cons_define
	LOADUI R3 $s_define         ; Using s_define
	CMPJUMPI.NE R4 R3 @eval_cons_set

	;; Deal with special case of Define statements
	LOAD32 R2 R0 8              ; Protect EXP->CDR
	LOAD32 R0 R2 8              ; Get EXP->CDR->CDR
	LOAD32 R0 R0 4              ; Using EXP->CDR->CDR->CAR
	CALLI R15 @eval             ; Recurse to figure out what it is
	MOVE R1 R0                  ; Put Result in the right place
	LOAD32 R0 R2 4              ; Using EXP->CDR->CAR
	CALLI R15 @extend_top       ; EXTEND_TOP
	JUMP @eval_done             ; Simply use what was returned

:eval_cons_set
	LOADUI R3 $s_setb           ; Using s_setb
	CMPJUMPI.NE R4 R3 @eval_cons_apply

	;; Deal with special case of SET statements
	LOAD32 R2 R0 8              ; Protect EXP->CDR
	LOAD32 R0 R2 8              ; Get EXP->CDR->CDR
	LOAD32 R0 R0 4              ; Using EXP->CDR->CDR->CAR
	CALLI R15 @eval             ; Recurse to get New value
	SWAP R0 R2                  ; Protect New Value
	LOAD32 R0 R0 4              ; Using EXP->CDR->CAR
	CALLI R15 @assoc            ; Get the associated Symbol
	STORE32 R2 R0 8             ; SET Pair->CDR to New Value
	MOVE R0 R2                  ; Using New Value
	JUMP @eval_done             ; Simply Return Result

:eval_cons_apply
	;; Deal with the last option for a CONS, APPLY
	LOAD32 R2 R0 4              ; Protect EXP->CAR
	LOAD32 R0 R0 8              ; Using EXP->CDR
	CALLI R15 @evlis            ; EVLIS
	SWAP R0 R2                  ; Protect EVLIS result
	CALLI R15 @eval             ; Recurse to figure out what to APPLY
	MOVE R1 R2                  ; Put EVLIS result in right place
	CALLI R15 @apply            ; Apply what was found to the EVLIS result
	JUMP @eval_done             ; Simply return the result

	;; Deal with everything else the same way
:eval_primop
:eval_proc
	;; The result for primops and procs are simply to return the Expression
	;; Which just so happens to already be in R0 so don't bother to do any
	;; More but we are leaving these labels in case we want to change it
	;; later or do something much more complicated.

	;; Result must be in R0 by this point
	;; Simply Clean up and return result in R0
:eval_done
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
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


	;; Currently unimplemented functions
;; prim_prod
;; prim_div
;; prim_mod
;; prim_and
;; prim_or
;; prim_not
;; prim_numgt
;; prim_numge
;; prim_numeq
;; prim_numle
;; prim_numlt
;; prim_listp
;; prim_display
;; prim_freecell
;; prim_ascii


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

	LOADUI R0 $s_begin          ; Get s_begin
	COPY R1 R0                  ; Duplicate s_if
	CALLI R15 @spinup           ; SPINUP

	;; Add Primitive Specials
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

	LOADUI R0 $prim_list        ; Using PRIM_list
	CALLI R15 @make_prim        ; MAKE_PRIM
	MOVE R1 R0                  ; Put Primitive in correct location
	LOADUI R0 $prim_list_String ; Using PRIM_LIST_STRING
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

;; gc_block_end
:gc_block_end
	'00160000'


;; reclaim_marked
;; Recieves nothing
;; Returns nothing
;; Reclaims and updates free_cells
:reclaim_marked
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	LOADR R0 @gc_block_start    ; Using GC_BLOCK_START
	LOADR R1 @gc_block_end      ; Using GC_BLOCK_END

:reclaim_marked_0
	CMPJUMPI.GE R0 R1 @reclaim_marked_done
	LOAD32 R2 R0 0              ; Get I->TYPE
	ANDI R2 R2 2                ; AND with MARKED
	JUMP.Z R2 @reclaim_marked_1 ; Deal with MARKED CELLS or jump on NULL

	;; Deal with Marked
	LOADUI R2 1                 ; Using FREE
	STORE32 R2 R0 0             ; Set I->TYPE to FREE
	FALSE R2                    ; USING NULL
	LOADR R3 @free_cells        ; Get FREE_CELLS
	STORE32 R2 R0 4             ; SET I->CAR to NULL
	STORE32 R3 R0 8             ; SET I->CDR to FREE_CELLS
	STORE32 R2 R0 12            ; SET I->ENV to NULL
	STORER R0 @free_cells       ; Update FREE_CELLS to I

	;; Deal with unmarked
:reclaim_marked_1
	ADDUI R0 R0 16              ; Increment I by the size of a CELL
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
	LOADR R1 @gc_block_end      ; Using GC_BLOCK_END

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
;; Recieves a List in R0
;; Returns nothing
;; Unmarks all connected Cells
:unmark_cells
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	LOADUI R2 2                 ; GET MARKED
	NOT R2 R2                   ; Use ~MARKED

:unmark_cells_0
	JUMP.Z R0 @unmark_cells_done
	LOAD32 R1 R0 0              ; Get I->TYPE
	AND R1 R1 R3                ; Remove MARK
	STORE32 R1 R0 0             ; Store the cleaned type

	;; Deal with CONS
	CMPSKIPI.NE R1 16           ; If A CONS
	JUMP @unmark_cells_proc     ; Deal with it

	;; Deal with PROC
	CMPSKIPI.NE R1 32           ; If A PROC
	JUMP @unmark_cells_proc     ; Deal with it

	;; Everything else
	JUMP @unmark_cells_1        ; Move onto NEXT

:unmark_cells_proc
	LOAD32 R2 R0 4              ; Using list->CAR
	SWAP R0 R2                  ; Protect list
	CALLI R15 @unmark_cells     ; Recurse until the ends
	SWAP R0 R2                  ; Put list back

:unmark_cells_1
	LOAD32 R0 R0 8              ; Get list->CDR
	JUMP @unmark_cells_0        ; Keep going down list

:unmark_cells_done
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; garbage_collect
;; Recieves nothing
;; Returns nothing
;; The Core of Garbage Collection
:garbage_collect
	PUSHR R0 R15                ; Protect R0
	CALLI R15 @mark_all_cells   ; MARK_ALL_CELLS
	LOADR R0 @all_symbols       ; Using ALL_SYMBOLS
	CALLI R15 @unmark_cells     ; UNMARK ALL_SYMBOLS
	LOADR R0 @top_env           ; Using TOP_ENV
	CALLI R15 @unmark_cells     ; UNMARK TOP_ENV
	CALLI R15 @reclaim_marked   ; RECLAIM_MARKED
	CALLI R15 @update_remaining ; Fix the Count
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
	LOADR R1 @gc_block_end      ; Get End Address
	ADD R1 R1 R0                ; Add the Offset
	SUBUI R1 R1 16              ; Shift Back Down
	STORER R1 @gc_block_end     ; Update Block End
	CALLI R15 @mark_all_cells   ; MARK_ALL_CELLS
	CALLI R15 @reclaim_marked   ; RECLAIM_MARKED
	CALLI R15 @update_remaining ; Fix the Count
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
