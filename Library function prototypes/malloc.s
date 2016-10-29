	# We will be using R0 request a number of bytes
	# The pointer to the block of that size is to be
	# passed back in R0, for simplicity sake
	# R15 will be used as the stack pointer
:start
	LOADUI R15 @stack
	LOADUI R0 22                ; Allocate 22 bytes
	CALLI R15 @malloc
	LOADUI R0 42                ; Allocate 42 bytes
	CALLI R15 @malloc
	HALT

;;  Our simple malloc function
:malloc
	;; Preserve registers
	PUSHR R1 R15
	;; Get current malloc pointer
	LOADR R1 @malloc_pointer
	;; Deal with special case
	CMPSKIPI.NE R1 0            ; If Zero set to our start of heap space
	LOADUI R1 0x600

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

;; Start stack at end of instructions
:stack
