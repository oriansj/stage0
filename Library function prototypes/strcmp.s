	# We will be using R0 and R1 to pass values to the function
	# R15 will be used as the stack pointer
:start
	LOADUI R0 @string
	COPY R1 R0
	LOADUI R2 33
	LOADUI R3 44
	LOADUI R4 55
	LOADUI R15 0x600
	CALLI R15 @strcmp
	HALT
:string
	HALT
	NOP

;;  Our simple string compare function
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
	LOADXU8 R0 R2 R4			; Get a byte of our first string
	LOADXU8 R1 R3 R4			; Get a byte of our second string
	ADDUI R4 R4 1				; Prep for next loop
	CMP R1 R0 R1				; Compare the bytes
	CMPSKIP.E R0 0				; Stop if byte is NULL
	JUMP.E R1 @cmpbyte			; Loop if bytes are equal
;; Done
	MOVE R0 R1					; Prepare for return
	;; Restore registers
	POPR R4 R15
	POPR R3 R15
	POPR R2 R15
	RET R15
