;; Readline function
;; Recieves Pointer to node in R0
;; And Input in R1
;; Allocates Text segment on Heap
;; Sets node's pointer to Text segment
;; Sets R14 to True if EOF reached
;; Requires a malloc function to exist
;; Returns to whatever called it
:Readline
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	PUSHR R3 R15
	PUSHR R4 R15
	;; Initialize
	MOVE R4 R0
	FALSE R0                    ; Get where space is free
	CALLI R15 @malloc
	MOVE R2 R0
	FALSE R3
:Readline_0
	FGETC                       ; Read a Char

	;; Flag if reached EOF
	CMPSKIPI.GE R0 0
	TRUE R14

	;; Stop if EOF
	CMPSKIPI.GE R0 0
	JUMP @Readline_2

	;; Handle Backspace
	CMPSKIPI.E R0 127
	JUMP @Readline_1

	;; Move back 1 character if R3 > 0
	CMPSKIPI.LE R3 0
	SUBUI R3 R3 1

	;; Hopefully they keep typing
	JUMP @Readline_0

:Readline_1
	;; Replace all CR with LF
	CMPSKIPI.NE R0 13
	LOADUI R0 10

	;; Store the Byte
	STOREX8 R0 R2 R3

	;; Prep for next loop
	ADDUI R3 R3 1

	;; Check for EOL
	CMPSKIPI.NE R0 10
	JUMP @Readline_2

	;; Otherwise loop
	JUMP @Readline_0

:Readline_2
	;; Set Text pointer
	CMPSKIPI.E R3 0             ; Don't bother for Empty strings
	STORE32 R2 R4 8
	;; Correct Malloc
	MOVE R0 R3                  ; Ensure actually allocates exactly
	CALLI R15 @malloc           ; the amount of space required
	;; Restore Registers
	POPR R4 R15
	POPR R3 R15
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	RET R15
