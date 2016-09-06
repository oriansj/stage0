:start
	;; We will be using R13 for storage of Head
	;; We will be using R14 for our condition codes
	LOADUI R15 $stack           ; Put stack at end of program

	;; Main program
	;; Reads contents of Tape_01 and applies all Definitions
	;; Writes results to Tape_02
;; Accepts no arguments and HALTS when done
:main
	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	FALSE R0                    ; Head is NULL
	LOADUI R0 0x1100            ; Read Tape_01
	FALSE R14                   ; We haven't yet reached EOF
:main_0
	CALLI R15 @Tokenize_Line    ; Call Tokenize_Line
	JUMP.Z R14 @main_0          ; Until we reach EOF

	;; Done reading File
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE


	CALLI R15 @Identify_Macros  ; Tag all nodes that are macros
	CALLI R15 @Line_Macro       ; Apply macros down nodes
	CALLI R15 @Process_String   ; Convert string values to Hex16
	CALLI R15 @Eval_Immediates  ; Convert numbers to hex
	CALLI R15 @Preserve_Other   ; Ensure labels/Pointers aren't lost
	CALLI R15 @Print_Hex        ; Write Nodes to Tape_02
	HALT                        ; We are Done


;; Primative malloc function
;; Recieves number of bytes to allocate in R0
;; Returns pointer to block of that size in R0
;; Returns to whatever called it
:malloc
	;; Preserve registers
	PUSHR R1 R15
	;; Get current malloc pointer
	LOADR R1 @malloc_pointer
	;; Deal with special case
	CMPSKIP.NE R1 0             ; If Zero set to our start of heap space
	LOADUI R1 0x4000

	;; update malloc pointer
	SWAP R0 R1
	ADD R1 R0 R1
	STORER R1 @malloc_pointer

;; Done
	;; Restore registers
	POPR R1 R15
	RET R15
;; Our static value for malloc pointer
:malloc_pointer
	NOP


	;; Tokenize_Line function
	;; Recieves pointer to Head in R0 and desired input in R1
	;; Alters R14 when EOF Reached
	;; Returns to whatever called it
:Tokenize_Line
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	PUSHR R3 R15
	PUSHR R4 R15

	;; Initialize
	MOVE R4 R0                  ; Get Head pointer out of the way
:Tokenize_Line_0
	FGETC                       ; Get a Char

	;; Deal with lines comments starting with #
	CMPSKIP.NE R0 35
	JUMP @Purge_Line_Comment

	;; Deal with Line comments starting with ;
	CMPSKIP.NE R0 59
	JUMP @Purge_Line_Comment

	;; Deal with Tab
	CMPSKIP.NE R0 9
	JUMP @Tokenize_Line_0       ; Throw away byte and try again

	;; Deal with New line
	CMPSKIP.NE R0 10
	JUMP @Tokenize_Line_0       ; Throw away byte and try again

	;; Deal with space characters
	CMPSKIP.NE R0 32
	JUMP @Tokenize_Line_0       ; Throw away byte and try again

	;; Flag if reached EOF
	CMPSKIP.GE R0 0
	TRUE R14

	;; Stop if EOF
	CMPSKIP.GE R0 0
	JUMP @Tokenize_Line_Done

	;; Allocate a new Node
	MOVE R2 R0					; Get Char out the way
	LOADUI R0 16				; Allocate 16 Bytes
	CALLI R15 @malloc			; Get address of new Node
	SWAP R2 R0					; Store Pointer in R2

	;; Deal with Strings wrapped in "
	CMPSKIP.NE R0 34
	JUMP @Store_String

	;; Deal with Strings wrapped in '
	CMPSKIP.NE R0 39
	JUMP @Store_String

	;; Everything else is an atom store it
	CALLI R15 @Store_Atom

:Tokenize_Line_Done
	CALLI R15 @Add_Token        ; Append new token to Head

	;; Restore registers
	POPR R4 R15
	POPR R3 R15
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15

	;; Return since we are done
	RET R15


;; Purge_Line_Comment Function
;; Recieves char in R0 and desired input in R1
;; Modifies R0
;; Returns to Tokenize_Line as if the entire line
;; Comment never existed
:Purge_Line_Comment
	FGETC                       ; Get another Char
	CMPSKIP.E R0 10             ; Stop When LF is reached
	JUMP @Purge_Line_Comment    ; Otherwise keep looping
	JUMP @Tokenize_Line_0       ; Return as if this never happened


	;; Store_String function
	;; Recieves Char in R0, desired input in R1
	;; And node pointer in R2

;; Where we are putting the start of our stack
:stack
