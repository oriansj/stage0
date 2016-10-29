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
	;; Forth STATE [R10]
	;; Forth LATEST (Pointer to last defined function) [R9]
	;; Forth HERE (Pointer to next free byte in HEAP) [R8]

	;; Start function
	;; Loads contents of tape_01
	;; Starts interface until Halted
:start
	LOADUI R15 1                ; Since 1MB can't fit in 16 bits
	SL0I R15 20                 ; 1 shifted 20 bits should do the trick
	LOADUI R14 3                ; Since 1.5MB can't fit into 16 bits
	SL0I R14 19                 ; 3 shifted 19 bits should do the trick
	LOADUI R11 $NEXT            ; Get Address of Next
	CALLI R15 @cold_start
	HALT

;; EXIT function
;; Pops Return stack
;; And jumps to NEXT
:EXIT
	POPR R13 R15

;; NEXT function
;; increments to next instruction
;; Jumps to updated current
;; Affects only Next and current
:NEXT
	LOAD R12 R13 0              ; Get Address stored which is pointed at by next
	ADDUI R13 R13 4             ; Increment Next
	JSR_COROUTINE R12           ; Jump to next thing

;; Some Forth primatives

;; Drop
:Drop_Text
"DROP"
:Drop_Entry
	NOP                         ; No previous link elements
	&Drop_Text                  ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Drop Top of stack
	JSR_COROUTINE R11           ; NEXT

;; SWAP
:Swap_Text
"SWAP"
:Swap_Entry
	&Drop_Entry                 ; Pointer to Drop
	&Swap_Text                  ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14
	POPR R1 R14
	PUSHR R0 R14
	PUSHR R1 R14
	JSR_COROUTINE R11           ; NEXT

;; DUP
:Dup_Text
"DUP"
:Dup_Entry
	&Swap_Entry                 ; Pointer to Swap
	&Dup_Text                   ; Pointer to Name
	NOP                         ; Flags
	LOAD R0 R14 0               ; Get top of stack
	PUSHR R0 R14                ; Push copy onto it
	JSR_COROUTINE R11           ; NEXT

;; OVER
:Over_Text
"OVER"
:Over_Entry
	&Dup_Entry                  ; Pointer to DUP
	&Over_Text                  ; Pointer to Name
	NOP                         ; Flags
	LOAD R0 R14 -4              ; Get second from Top of stack
	PUSHR R0 R14                ; Push it onto top of stack
	JSR_COROUTINE R11           ; NEXT

;; ROT
:Rot_Text
"ROT"
:Rot_Entry
	&Over_Entry                 ; Pointer to Over
	&Rot_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14
	POPR R1 R14
	POPR R2 R14
	PUSHR R1 R14
	PUSHR R0 R14
	PUSHR R2 R14
	JSR_COROUTINE R11           ; NEXT

;; -ROT
:-Rot_Text
"-ROT"
:-Rot_Entry
	&Rot_Entry                  ; Pointer to ROT
	&-Rot_Text                  ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14
	POPR R1 R14
	POPR R2 R14
	PUSHR R0 R14
	PUSHR R2 R14
	PUSHR R1 R14
	JSR_COROUTINE R11           ; NEXT

;; 2DROP
:2Drop_Text
"2DROP"
:2Drop_Entry
	&-Rot_Entry                 ; Pointer to -ROT
	&2Drop_Text                 ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14
	POPR R0 R14
	JSR_COROUTINE R11           ; NEXT

;; 2DUP
:2Dup_Text
"2DUP"
:2Dup_Entry
	&2Drop_Entry                ; Pointer to 2Drop
	&2Dup_Text                  ; Pointer to Name
	NOP                         ; Flags
	LOAD R0 R14 0               ; Get top of stack
	LOAD R1 R14 -4              ; Get second on stack
	PUSHR R1 R14
	PUSHR R0 R14
	JSR_COROUTINE R11           ; NEXT

;; 2SWAP
:2Swap_Text
"2Swap"
:2Swap_Entry
	&2Dup_Entry                 ; Pointer to 2Dup
	&2Swap_Text                 ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14
	POPR R1 R14
	POPR R2 R14
	POPR R3 R14
	PUSHR R1 R14
	PUSHR R0 R14
	PUSHR R3 R14
	PUSHR R2 R14
	JSR_COROUTINE R11           ; NEXT


;; ?DUP
:QDup_Text
"?DUP"
:QDup_Entry
	&2Swap_Entry                ; Pointer to 2Swap
	&QDup_Text                  ; Pointer to Name
	NOP                         ; Flags
	LOAD R0 R14 0               ; Get Top of stack
	CMPSKIPI.E R0 0             ; Skip if Zero
	PUSHR R0 R14                ; Duplicate value
	JSR_COROUTINE R11           ; NEXT

;; +
:Add_Text
"+"
:Add_Entry
	&QDup_Entry                 ; Pointer to ?Dup
	&Add_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of stack
	POPR R1 R14                 ; Get second item on Stack
	ADD R0 R0 R1                ; Perform the addition
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; -
:Sub_Text
"-"
:Sub_Entry
	&Add_Entry                  ; Pointer to +
	&Sub_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of stack
	POPR R1 R14                 ; Get second item on Stack
	SUB R0 R0 R1                ; Perform the subtraction
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; MUL
:MUL_Text
"*"
:MUL_Entry
	&Sub_Entry                  ; Pointer to -
	&MUL_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of stack
	POPR R1 R14                 ; Get second item on Stack
	MUL R0 R0 R1                ; Perform the multiplication and keep bottom half
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; MULH
:MULH_Text
"MULH"
:MULH_Entry
	&MUL_Entry                  ; Pointer to *
	&MULH_Text                  ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of stack
	POPR R1 R14                 ; Get second item on Stack
	MULH R0 R0 R1               ; Perform multiplcation and keep top half
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; /
:DIV_Text
"/"
:DIV_Entry
	&MULH_Entry                 ; Pointer to MULH
	&DIV_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of stack
	POPR R1 R14                 ; Get second item on Stack
	DIV R0 R0 R1                ; Perform division and keep top half
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; %
:MOD_Text
"%"
:MOD_Entry
	&DIV_Entry                  ; Pointer to /
	&MOD_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of stack
	POPR R1 R14                 ; Get second item on Stack
	MOD R0 R0 R1                ; Perform division and keep remainder
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; =
:Equal_Text
"="
:Equal_Entry
	&MOD_Entry                  ; Pointer to %
	&Equal_Text                 ; Pointer to Name
	NOP                         ; Flags
	POPR R1 R14                 ; Get top of stack
	POPR R2 R14                 ; Get second item on Stack
	FALSE R0                    ; Assume comparision is True
	CMPSKIP.E R1 R2             ; Check if they are equal and skip if they are
	TRUE R0                     ; Looks like our assumption was wrong
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; !=
:NEqual_Text
"!="
:NEqual_Entry
	&Equal_Entry                ; Pointer to =
	&NEqual_Text                ; Pointer to Name
	NOP                         ; Flags
	POPR R1 R14                 ; Get top of stack
	POPR R2 R14                 ; Get second item on Stack
	FALSE R0                    ; Assume comparision is True
	CMPSKIP.NE R1 R2            ; Check if they are not equal and skip if they are
	TRUE R0                     ; Looks like our assumption was wrong
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; <
:Less_Text
"<"
:Less_Entry
	&NEqual_Entry               ; Pointer to !=
	&Less_Text                  ; Pointer to Name
	NOP                         ; Flags
	POPR R1 R14                 ; Get top of stack
	POPR R2 R14                 ; Get second item on Stack
	FALSE R0                    ; Assume comparision is True
	CMPSKIP.L R1 R2             ; Check if less than and skip if they are
	TRUE R0                     ; Looks like our assumption was wrong
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; <=
:LEqual_Text
"<="
:LEqual_Entry
	&Less_Entry                 ; Pointer to <
	&LEqual_Text                ; Pointer to Name
	NOP                         ; Flags
	POPR R1 R14                 ; Get top of stack
	POPR R2 R14                 ; Get second item on Stack
	FALSE R0                    ; Assume comparision is True
	CMPSKIP.LE R1 R2            ; Check if they are less than or equal and skip if they are
	TRUE R0                     ; Looks like our assumption was wrong
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;;  >
:Greater_Text
">"
:Greater_Entry
	&LEqual_Entry               ; Pointer to <=
	&Greater_Text               ; Pointer to Name
	NOP                         ; Flags
	POPR R1 R14                 ; Get top of stack
	POPR R2 R14                 ; Get second item on Stack
	FALSE R0                    ; Assume comparision is True
	CMPSKIP.G R1 R2             ; Check if greater and skip if they are
	TRUE R0                     ; Looks like our assumption was wrong
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;;  >=
:GEqual_Text
">="
:GEqual_Entry
	&Greater_Entry              ; Pointer to >
	&GEqual_Text                ; Pointer to Name
	NOP                         ; Flags
	POPR R1 R14                 ; Get top of stack
	POPR R2 R14                 ; Get second item on Stack
	FALSE R0                    ; Assume comparision is True
	CMPSKIP.GE R1 R2            ; Check if they are equal and skip if they are
	TRUE R0                     ; Looks like our assumption was wrong
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; AND
:AND_Text
"AND"
:AND_Entry
	&GEqual_Entry               ; Pointer to >=
	&AND_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of stack
	POPR R1 R14                 ; Get second item on Stack
	AND R0 R0 R1                ; Perform AND
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; OR
:OR_Text
"OR"
:OR_Entry
	&AND_Entry                  ; Pointer to AND
	&OR_Text                    ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of stack
	POPR R1 R14                 ; Get second item on Stack
	OR R0 R0 R1                 ; Perform OR
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; XOR
:XOR_Text
"XOR"
:XOR_Entry
	&OR_Entry                   ; Pointer to OR
	&XOR_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of stack
	POPR R1 R14                 ; Get second item on Stack
	XOR R0 R0 R1                ; Perform XOR
	PUSHR R0 R14                ; Store the result
	JSR_COROUTINE R11           ; NEXT

;; NOT
:NOT_Text
"NOT"
:NOT_Entry
	&XOR_Entry                  ; Pointer to XOR
	&NOT_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of stack
	NOT R0 R0                   ; Bit flip it
	PUSHR R0 R14                ; Store it back onto stack
	JSR_COROUTINE R11           ; NEXT

;; LIT
:LIT_Text
"LIT"
:LIT_Entry
	&NOT_Entry                  ; Pointer to NOT
	&LIT_Text                   ; Pointer to Name
	NOP                         ; Flags
	LOAD R0 R11 0               ; Get contents of NEXT
	ADDUI R11 R11 4             ; Increment NEXT
	PUSHR R0 R14                ; Put immediate onto stack
	JSR_COROUTINE R11           ; NEXT

;; Memory manipulation instructions

;; STORE
:Store_Text
"!"
:Store_Entry
	&LIT_Entry                  ; Pointer to LIT
	&Store_Text                 ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Destination
	POPR R1 R14                 ; Contents
	STORE R1 R0 0               ; Write out
	JSR_COROUTINE R11           ; NEXT

;; FETCH
:Fetch_Text
"@"
:Fetch_Entry
	&Store_Entry                ; Pointer to Store
	&Fetch_Text                 ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Source address
	LOAD R0 R0 0                ; Get Contents
	PUSHR R0 R14                ; Push Contents
	JSR_COROUTINE R11           ; NEXT

;; ADDSTORE
:AStore_Text
"+!"
:AStore_Entry
	&Fetch_Entry                ; Pointer to Fetch
	&AStore_Text                ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Destination
	POPR R1 R14                 ; How much to add
	LOAD R2 R0 0                ; Get contents of address
	ADD R1 R1 R2                ; Combine
	STORE R1 R0 0               ; Write out
	JSR_COROUTINE R11           ; NEXT

;; SUBSTORE
:SStore_Text
"-!"
:SStore_Entry
	&AStore_Entry               ; Pointer to ADDSTORE
	&SStore_Text                ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Destination
	POPR R1 R14                 ; How much to sub
	LOAD R2 R0 0                ; Get contents of address
	SUB R1 R2 R1                ; Subtract
	STORE R1 R0 0               ; Write out
	JSR_COROUTINE R11           ; NEXT

;; STOREBYTE
:SByte_Text
"C!"
:SByte_Entry
	&SStore_Entry               ; Pointer to SUBSTORE
	&SByte_Text                 ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Destination
	POPR R1 R14                 ; Contents
	STORE8 R1 R0 0              ; Write out
	JSR_COROUTINE R11           ; NEXT

;; FETCHBYTE
:FByte_Text
"C@"
:FByte_Entry
	&SByte_Entry                ; Pointer to STOREBYTE
	&FByte_Text                 ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Source address
	LOADU8 R0 R0 0              ; Get Contents
	PUSHR R0 R14                ; Push Contents
	JSR_COROUTINE R11           ; NEXT

;; CMOVE
:CMove_Text
"CMOVE"
:CMove_Entry
	&FByte_Entry                ; Pointer to FETCHBYTE
	&CMove_Text                 ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get number of bytes to Move
	POPR R1 R14                 ; Where to put the result
	POPR R2 R14                 ; Where it is coming from
	FALSE R4                    ; Prepare for Zeroing

:Cmove_Main
	CMPSKIPI.GE R0 4            ; Loop if we have 4 or more bytes to move
	JUMP @Cmove_Slow            ; Otherwise slowly move bytes
	LOAD R3 R2 0                ; Get 4 Bytes
	STORE R4 R2 0               ; Overwrite that memory with Zeros
	STORE R3 R1 0               ; Store them at the destination
	ADDUI R1 R1 4               ; Increment Source by 4
	ADDUI R2 R2 4               ; Increment Destination by 4
	SUBI R0 R0 4                ; Decrement number of bytes to move by 4
	JUMP @Cmove_Main            ; Loop more

:Cmove_Slow
	CMPSKIPI.G R0 0             ; While number of bytes is greater than 0
	JUMP @Cmove_Done            ; Otherwise be done
	LOADU8 R3 R2 0              ; Get 4 Bytes
	STORE8 R4 R2 0              ; Overwrite that memory with Zeros
	STORE8 R3 R1 0              ; Store them at the destination
	ADDUI R1 R1 1               ; Increment Source by 1
	ADDUI R2 R2 1               ; Increment Destination by 1
	SUBI R0 R0 1                ; Decrement number of bytes to move by 1
	JUMP @Cmove_Slow            ; Loop more

:Cmove_Done
	JSR_COROUTINE R11           ; NEXT

;; Global variables

;; STATE
:State_Text
"STATE"
:State_Entry
	&CMove_Entry                ; Pointer to CMOVE
	&State_Text                 ; Pointer to Name
	NOP                         ; Flags
	PUSHR R10 R14               ; Put STATE onto stack
	JSR_COROUTINE R11           ; NEXT

;; LATEST
:Latest_Text
"LATEST"
:Latest_Entry
	&State_Entry                ; Pointer to STATE
	&Latest_Text                ; Pointer to Name
	NOP                         ; Flags
	PUSHR R9 R14                ; Put LATEST onto stack
	JSR_COROUTINE R11           ; NEXT

;; HERE
:Here_Text
"HERE"
:Here_Entry
	&Latest_Entry               ; Pointer to LATEST
	&Here_Text                  ; Pointer to Name
	NOP                         ; Flags
	PUSHR R8 R14                ; Put HERE onto stack
	JSR_COROUTINE R11           ; NEXT

;; Return Stack functions

;; >R
:TOR_Text
">R"
:TOR_Entry
	&Here_Entry                 ; Pointer to HERE
	&TOR_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R14                 ; Get top of Parameter stack
	PUSHR R0 R15                ; Shove it onto return stack
	JSR_COROUTINE R11           ; NEXT

;; R>
:FROMR_Text
"R>"
:FROMR_Entry
	&TOR_Entry                  ; Pointer to >R
	&FROMR_Text                 ; Pointer to Name
	NOP                         ; Flags
	POPR R0 R15                 ; Get top of Return stack
	PUSHR R0 R14                ; Shove it onto parameter stack
	JSR_COROUTINE R11           ; NEXT

;; RSP@
:RSPFetch_Text
"RSP@"
:RSPFetch_Entry
	&FROMR_Entry                ; Pointer to R>
	&RSPFetch_Text              ; Pointer to Name
	NOP                         ; Flags
	PUSHR R14 R15               ; Push Return stack pointer onto Parameter stack
	JSR_COROUTINE R11           ; NEXT

;; RSP!
:RSPStore_Text
"RSP!"
:RSPStore_Entry
	&RSPFetch_Entry             ; Pointer to RSP@
	&ore_Text                   ; Pointer to Name
	NOP                         ; Flags
	POPR R15 R14                ; Replace Return stack pointer from parameter stack
	JSR_COROUTINE R11           ; NEXT

	;; Parameter stack operations

;; DSP@
:DSPFetch_Text
"DSP@"
:DSPFetch_Entry
	&RSPStore_Entry             ; Pointer to RSP!
	&DSPFetch_Text              ; Pointer to Name
	NOP                         ; Flags
	PUSHR R14 R14               ; Push current parameter pointer onto parameter stack
	JSR_COROUTINE R11           ; NEXT

;; DSP!
:DSPStore_Text
"DSP!"
:DSPStore_Entry
	&DSPFetch_Entry             ; Pointer to DSP@
	&DSPStore_Text              ; Pointer to Name
	NOP                         ; Flags
	POPR R14 R14                ; Replace parameter stack pointer from parameter stack
	JSR_COROUTINE R11           ; NEXT

:cold_start
	;;
