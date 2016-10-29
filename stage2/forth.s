	;; Memory Space
	;;  0 -> 1MB code -> Heap space [Heap pointer with malloc function]
	;; 1MB -> 1.5MB Stack space 1 (Value Stack) [Pointed at by R14]
	;; 1.5MB+ Stack space 2 (Return Stack) [Pointed at by R15]
	;;
	;; DICTIONARY ENTRY (HEADER)
	;; 0 -> Link (pointer to previous)
	;; 4 -> Text (pointer to name string)
	;; 8 -> Flags (Entry's flags)
	;; 12+ -> Definition
	;;
	;; Other allocated registers
	;; Next pointer [R13]
	;; Current pointer [R12]
	;; Address of NEXT [R11]

	;; Start function
	;; Loads contents of tape_01
	;; Starts interface until Halted
:start
	LOADUI R15 1				; Since 1MB can't fit in 16 bits
	SL0I R15 20				; 1 shifted 20 bits should do the trick
	LOADUI R14 3				; Since 1.5MB can't fit into 16 bits
	SL0I R14 19				; 3 shifted 19 bits should do the trick
	LOADUI R11 $NEXT			; Get Address of Next
	CALLI R15 @cold_start
	HALT

;; NEXT function
;; increments to next instruction
;; Jumps to updated current
;; Affects only Next and current
:NEXT
	LOAD R12 R13 0				; Get Address stored which is pointed at by next
	ADDUI R13 R13 4			; Increment Next
	JSR_COROUTINE R12			; Jump to next thing

;; Some Forth primatives

;; Drop
:Drop_Text
"DROP"
:Drop_Entry
	NOP						; No previous link elements
	&Drop_Text					; Pointer to Name
	NOP						; Flags
	POPR R0 R14				; Drop Top of stack
	JSR_COROUTINE R11			; NEXT

;; SWAP
:Swap_Text
"SWAP"
:Swap_Entry
	&Drop_Entry				; Pointer to Drop
	&Swap_Text					; Pointer to Name
	NOP						; Flags
	POPR R0 R14
	POPR R1 R14
	PUSHR R0 R14
	PUSHR R1 R14
	JSR_COROUTINE R11			; NEXT

;; DUP
:Dup_Text
"DUP"
:Dup_Entry
	&Swap_Entry				; Pointer to Swap
	&Dup_Text					; Pointer to Name
	NOP						; Flags
	LOAD R0 R14 0				; Get top of stack
	PUSHR R0 R14				; Push copy onto it
	JSR_COROUTINE R11			; NEXT

;; OVER
:Over_Text
"OVER"
:Over_Entry
	&Dup_Entry					; Pointer to DUP
	&Over_Text					; Pointer to Name
	NOP						; Flags
	LOAD R0 R14 -4				; Get second from Top of stack
	PUSHR R0 R14				; Push it onto top of stack
	JSR_COROUTINE R11			; NEXT

;; ROT
:Rot_Text
"ROT"
:Rot_Entry
	&Over_Entry				; Pointer to Over
	&Rot_Text					; Pointer to Name
	NOP						; Flags
	POPR R0 R14
	POPR R1 R14
	POPR R2 R14
	PUSHR R1 R14
	PUSHR R0 R14
	PUSHR R2 R14
	JSR_COROUTINE R11			; NEXT

;; -ROT
:-Rot_Text
"-ROT"
:-Rot_Entry
	&Rot_Entry					; Pointer to ROT
	&-Rot_Text					; Pointer to Name
	NOP						; Flags
	POPR R0 R14
	POPR R1 R14
	POPR R2 R14
	PUSHR R0 R14
	PUSHR R2 R14
	PUSHR R1 R14
	JSR_COROUTINE R11			; NEXT

;; 2DROP
:2Drop_Text
"2DROP"
:2Drop_Entry
	&-Rot_Entry				; Pointer to -ROT
	&2Drop_Text				; Pointer to Name
	NOP						; Flags
	POPR R0 R14
	POPR R0 R14
	JSR_COROUTINE R11			; NEXT

;; 2DUP
:2Dup_Text
"2DUP"
:2Dup_Entry
	&2Drop_Entry				; Pointer to 2Drop
	&2Dup_Text					; Pointer to Name
	NOP						; Flags
	LOAD R0 R14 0				; Get top of stack
	LOAD R1 R14 -4				; Get second on stack
	PUSHR R1 R14
	PUSHR R0 R14
	JSR_COROUTINE R11			; NEXT

;; 2SWAP
:2Swap_Text
"2Swap"
:2Swap_Entry
	&2Dup_Entry				; Pointer to 2Dup
	&2Swap_Text				; Pointer to Name
	NOP						; Flags
	POPR R0 R14
	POPR R1 R14
	POPR R2 R14
	POPR R3 R14
	PUSHR R1 R14
	PUSHR R0 R14
	PUSHR R3 R14
	PUSHR R2 R14
	JSR_COROUTINE R11			; NEXT


;; ?DUP
:QDup_Text
"?DUP"
:QDup_Entry
	&2Swap_Entry				; Pointer to 2Swap
	&QDup_Text					; Pointer to Name
	NOP						; Flags
	LOAD R0 R14 0				; Get Top of stack
	CMPSKIPI.E R0 0				; Skip if Zero
	PUSHR R0 R14				; Duplicate value
	JSR_COROUTINE R11			; NEXT

;; +
:Add_Text
"+"
:Add_Entry
	&QDup_Entry				; Pointer to ?Dup
	&Add_Text					; Pointer to Name
	NOP						; Flags
	POPR R0 R14				; Get top of stack
	POPR R1 R14				; Get second item on Stack
	ADD R0 R0 R1				; Perform the addition
	PUSHR R0 R14				; Store the result
	JSR_COROUTINE R11			; NEXT

;; -
:Sub_Text
"-"
:Sub_Entry
	&Add_Entry					; Pointer to +
	&Sub_Text					; Pointer to Name
	NOP						; Flags
	POPR R0 R14
	POPR R1 R14
	SUB R0 R0 R1
	PUSHR R0 R14
	JSR_COROUTINE R11			; NEXT

;; MUL
:MUL_Text
"*"
:MUL_Entry
	&Sub_Entry					; Pointer to -
	&MUL_Text					; Pointer to Name
	NOP						; Flags
	POPR R0 R14
	POPR R1 R14
	MUL R0 R0 R1
	PUSHR R0 R14
	JSR_COROUTINE R11			; NEXT

;; MULH
:MULH_Text
"MULH"
:MULH_Entry
	&MUL_Entry					; Pointer to *
	&MULH_Text					; Pointer to Name
	NOP						; Flags
	POPR R0 R14
	POPR R1 R14
	MULH R0 R0 R1
	PUSHR R0 R14
	JSR_COROUTINE R11			; NEXT

;; /
:DIV_Text
"/"
:DIV_Entry
	&MULH_Entry					; Pointer to MULH
	&DIV_Text						; Pointer to Name
	NOP							; Flags
	POPR R0 R14
	POPR R1 R14
	DIV R0 R0 R1
	PUSHR R0 R14
	JSR_COROUTINE R11				; NEXT

;; %
:MOD_Text
"%"
:MOD_Entry
	&DIV_Entry					; Pointer to /
	&MOD_Text					; Pointer to Name
	NOP						; Flags
	POPR R0 R14
	POPR R1 R14
	MOD R0 R0 R1
	PUSHR R0 R14
	JSR_COROUTINE R11			; NEXT

;; =
:Equal_Text
"="
:Equal_Entry
	&MOD_Entry					; Pointer to %
	&Equal_Text				; Pointer to Name
	NOP						; Flags
	POPR R1 R14
	POPR R2 R14
	TRUE R0					; Assume comparision is false
	
	JSR_COROUTINE R11			; NEXT


:cold_start
	;;
