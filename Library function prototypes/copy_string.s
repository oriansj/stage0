	# We will be using R0 and R1 to pass values to the function
	# R15 will be used as the stack pointer
:start
	LOADUI R0 @string
	LOADUI R1 0x100
	LOADUI R2 33
	LOADUI R3 44
	LOADUI R4 55
	LOADUI R15 0x600
	CALLI R15 @copy_string
	HALT
:string
	HALT
	HALT
	NOP

;;  Our simple string copy function
:copy_string
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	PUSHR R3 R15
	;; Setup registers
	MOVE R2 R1
	MOVE R1 R0
	LOADUI R3 0
:copy_byte
	LOADXU8 R0 R1 R3			; Get the byte
	STOREX8 R0 R2 R3			; Store the byte
	ADDUI R3 R3 1				; Prep for next loop
	JUMP.NZ R0 @copy_byte	; Stop if byte is NULL
;; Done
	;; Restore registers
	POPR R3 R15
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	RET R15
