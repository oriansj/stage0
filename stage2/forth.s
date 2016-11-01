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
	;; IO source [R7]
	;;
	;; Constants to make note of:
	;; F_IMMED 0x2
	;; F_HIDDEN 0x1
	;;
	;; Modes to make note of:
	;; COMPILING 0x1
	;; INTERPRETING 0x0

	;; Start function
	;; Loads contents of tape_01
	;; Starts interface until Halted
:start
	LOADR R15 @RETURN_BASE      ; Load Base of Return Stack
	LOADR R14 @PARAMETER_BASE   ; Load Base of Parameter Stack
	LOADUI R11 $NEXT            ; Get Address of Next
	FALSE R10                   ; Current state is Interpreting
	LOADUI R9 $Interpret_Entry  ; Get Address of last defined function
	LOADUI R8 $HEAP             ; Get Address of HEAP
	LOADUI R0 0x1100            ; Need number to engage tape_01
	FOPEN_READ                  ; Load Tape_01 for Reading
	MOVE R7 R0                  ; Make Tape_01 Default IO
	LOADUI R13 $Cold_Start      ; Intialize via QUIT
	JSR_COROUTINE R11           ; NEXT
	HALT                        ; If anything ever returns to here HALT

:Cold_Start
	&Quit_Code

:RETURN_BASE
'00040000'

:STRING_BASE
'00050000'

:PARAMETER_BASE
'00060000'

;; EXIT function
;; Pops Return stack
;; And jumps to NEXT
:EXIT_Text
"EXIT"
:EXIT_Entry
	NOP                         ; No previous link elements
	&EXIT_Text                  ; Pointer to name
	NOP                         ; Flags
	&EXIT_Code
:EXIT_Code
	POPR R13 R15

;; NEXT function
;; increments to next instruction
;; Jumps to updated current
;; Affects only Next and current
:NEXT
	COPY R12 R13                ; Preserve pointer
	ADDUI R13 R13 4             ; Increment Next
	LOAD R12 R12 0              ; Get contents pointed at by R12
	LOAD R0 R12 0               ; Get Code word target
	JSR_COROUTINE R0            ; Jump to Code word

;; DOCOL Function
;; The Interpreter for DO COLON
;; Jumps to NEXT
:DOCOL
	PUSHR R13 R15               ; Push NEXT onto Return Stack
	ADDUI R13 R12 4             ; Update NEXT to point to the instruction after itself
	JUMP @NEXT                  ; Use NEXT

;; Some Forth primatives

;; Drop
:Drop_Text
"DROP"
:Drop_Entry
	&EXIT_Entry                 ; Pointer to EXIT
	&Drop_Text                  ; Pointer to Name
	NOP                         ; Flags
	&Drop_Code                  ; Where assembly is Stored
:Drop_Code
	POPR R0 R14                 ; Drop Top of stack
	JSR_COROUTINE R11           ; NEXT

;; SWAP
:Swap_Text
"SWAP"
:Swap_Entry
	&Drop_Entry                 ; Pointer to Drop
	&Swap_Text                  ; Pointer to Name
	NOP                         ; Flags
	&Swap_Code                  ; Where assembly is Stored
:Swap_Code
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
	&Dup_Code                   ; Where assembly is Stored
:Dup_Code
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
	&Over_Code                  ; Where assembly is Stored
:Over_Code
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
	&Rot_Code                   ; Where assembly is Stored
:Rot_Code
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
	&-Rot_Code                  ; Where assembly is Stored
:-Rot_Code
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
	&2Drop_Code                 ; Where assembly is Stored
:2Drop_Code
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
	&2Dup_Code                  ; Where assembly is Stored
:2Dup_Code
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
	&2Swap_Code                 ; Where assembly is Stored
:2Swap_Code
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
	&QDup_Code                  ; Where assembly is Stored
:QDup_Code
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
	&Add_Code                   ; Where assembly is Stored
:Add_Code
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
	&Sub_Code                   ; Where assembly is Stored
:Sub_Code
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
	&MUL_Code                   ; Where assembly is Stored
:MUL_Code
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
	&MULH_Code                  ; Where assembly is Stored
:MULH_Code
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
	&DIV_Code                   ; Where assembly is Stored
:DIV_Code
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
	&MOD_Code                   ; Where assembly is Stored
:MOD_Code
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
	&Equal_Code                 ; Where assembly is Stored
:Equal_Code
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
	&NEqual_Code                ; Where assembly is Stored
:NEqual_Code
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
	&Less_Code                  ; Where assembly is Stored
:Less_Code
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
	&LEqual_Code                ; Where assembly is Stored
:LEqual_Code
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
	&Greater_Code               ; Where assembly is Stored
:Greater_Code
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
	&GEqual_Code                ; Where assembly is Stored
:GEqual_Code
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
	&AND_Code                   ; Where assembly is Stored
:AND_Code
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
	&OR_Code                    ; Where assembly is Stored
:OR_Code
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
	&XOR_Code                   ; Where assembly is Stored
:XOR_Code
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
	&NOT_Code                   ; Where assembly is Stored
:NOT_Code
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
	&LIT_Code                   ; Where assembly is Stored
:LIT_Code
	LOAD R0 R13 0               ; Get contents of NEXT
	ADDUI R13 R13 4             ; Increment NEXT
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
	&Store_Code                 ; Where assembly is Stored
:Store_Code
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
	&Fetch_Code                 ; Where assembly is Stored
:Fetch_Code
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
	&AStore_Code                ; Where assembly is Stored
:AStore_Code
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
	&SStore_Code                ; Where assembly is Stored
:SStore_Code
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
	&SByte_Code                 ; Where assembly is Stored
:SByte_Code
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
	&FByte_Code                 ; Where assembly is Stored
:FByte_Code
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
	&CMove_Code                 ; Where assembly is Stored
:CMove_Code
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
	&State_Code                 ; Where assembly is Stored
:State_Code
	PUSHR R10 R14               ; Put STATE onto stack
	JSR_COROUTINE R11           ; NEXT

;; LATEST
:Latest_Text
"LATEST"
:Latest_Entry
	&State_Entry                ; Pointer to STATE
	&Latest_Text                ; Pointer to Name
	NOP                         ; Flags
	&Latest_Code                ; Where assembly is Stored
:Latest_Code
	PUSHR R9 R14                ; Put LATEST onto stack
	JSR_COROUTINE R11           ; NEXT

;; HERE
:Here_Text
"HERE"
:Here_Entry
	&Latest_Entry               ; Pointer to LATEST
	&Here_Text                  ; Pointer to Name
	NOP                         ; Flags
	&Here_Code                  ; Where assembly is Stored
:Here_Code
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
	&TOR_Code                   ; Where assembly is Stored
:TOR_Code
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
	&FROMR_Code                 ; Where assembly is Stored
:FROMR_Code
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
	&RSPFetch_Code              ; Where assembly is Stored
:RSPFetch_Code
	PUSHR R14 R15               ; Push Return stack pointer onto Parameter stack
	JSR_COROUTINE R11           ; NEXT

;; RSP!
:RSPStore_Text
"RSP!"
:RSPStore_Entry
	&RSPFetch_Entry             ; Pointer to RSP@
	&RSPStore_Text              ; Pointer to Name
	NOP                         ; Flags
	&RSPStore_Code              ; Where assembly is Stored
:RSPStore_Code
	POPR R15 R14                ; Replace Return stack pointer from parameter stack
	JSR_COROUTINE R11           ; NEXT

;; Clear out the return stack
:RETURN_CLEAR
	&RETURN_CODE
:RETURN_CODE
	LOADR R1 @RETURN_BASE       ; Get Base of Return Stack
	CMPJUMPI.LE R15 R1 @RETURN_Done ; If Return stack is empty skip clearing

:Clear_Return
	POPR R0 R15                 ; Remove entry from Return Stack
	CMPSKIP.LE R15 R1           ; While Return stack isn't empty
	JUMP @Clear_Return          ; Keep looping to clear it out
:RETURN_Done
	MOVE R15 R1                 ; Ensure underflow is corrected
	JSR_COROUTINE R11           ; NEXT

	;; Parameter stack operations

;; DSP@
:DSPFetch_Text
"DSP@"
:DSPFetch_Entry
	&RSPStore_Entry             ; Pointer to RSP!
	&DSPFetch_Text              ; Pointer to Name
	NOP                         ; Flags
	&DSPFetch_Code              ; Where assembly is Stored
:DSPFetch_Code
	PUSHR R14 R14               ; Push current parameter pointer onto parameter stack
	JSR_COROUTINE R11           ; NEXT

;; DSP!
:DSPStore_Text
"DSP!"
:DSPStore_Entry
	&DSPFetch_Entry             ; Pointer to DSP@
	&DSPStore_Text              ; Pointer to Name
	NOP                         ; Flags
	&DSPStore_Code              ; Where assembly is Stored
:DSPStore_Code
	POPR R14 R14                ; Replace parameter stack pointer from parameter stack
	JSR_COROUTINE R11           ; NEXT

;; Input and output

;; KEY
:Key_Text
"KEY"
:Key_Entry
	&DSPStore_Entry             ; Pointer to DSP!
	&Key_Text                   ; Pointer to Name
	NOP                         ; Flags
	&Key_Code                   ; Where assembly is Stored
:Key_Code
	COPY R1 R7                  ; Using designated IO
	FGETC                       ; Get a byte
	PUSHR R0 R14                ; And push it onto the stack
	JSR_COROUTINE R11           ; NEXT

;; EMIT
:Emit_Text
"EMIT"
:Emit_Entry
	&Key_Entry                  ; Pointer to Key
	&Emit_Text                  ; Pointer to Name
	NOP                         ; Flags
	&Emit_Code                  ; Where assembly is Stored
:Emit_Code
	POPR R0 R14                 ; Get value off the parameter stack
	ANDI R0 R0 0xFF             ; Ensure only bottom Byte
	COPY R1 R7                  ; Using designated IO
	FPUTC                       ; Write out the byte
	JSR_COROUTINE R11           ; NEXT

;; WORD
:Word_Text
"WORD"
:Word_Entry
	&Emit_Entry                 ; Pointer to Emit
	&Word_Text                  ; Pointer to Name
	NOP                         ; Flags
	&Word_Code                  ; Where assembly is Stored
:Word_Code
	CALLI R15 @Word_Direct      ; Trick for direct calls
	JSR_COROUTINE R11           ; NEXT

:Word_Direct
	COPY R1 R7                  ; Using designated IO
	FALSE R2                    ; Starting at index 0
	LOADR R4 @STRING_BASE       ; Use the STRING_BASE instead

:Word_Start
	FGETC                       ; Read a byte
	CMPSKIPI.NE R1 0            ; Don't output unless TTY
	FPUTC                       ; Make it visible
	CMPSKIPI.NE R0 9            ; If Tab
	JUMP @Word_Start            ; Get another byte

	CMPSKIPI.NE R0 32           ; If space
	JUMP @Word_Start            ; Get another byte

:Word_Main
	CMPSKIPI.NE R0 4            ; If EOF
	JUMP @cold_done             ; Stop processing

	CMPSKIPI.G R0 0             ; If ERROR
	JUMP @cold_done             ; Stop processing

	CMPSKIPI.NE R0 9            ; If Tab
	JUMP @Word_Done             ; Be done

	CMPSKIPI.NE R0 10           ; If LF
	JUMP @Word_Done             ; Be done

	CMPSKIPI.NE R0 32           ; If space
	JUMP @Word_Done             ; Be done

	CMPSKIPI.NE R0 92           ; If comment
	JUMP @Word_Comment          ; Purge it and be done

	STOREX8 R0 R4 R2            ; Store byte onto HEAP
	ADDUI R2 R2 1               ; Increment index
	FGETC                       ; Read a byte
	CMPSKIPI.NE R0 13           ; IF CR
	LOADUI R0 10                ; Convert to LF
	CMPSKIPI.NE R1 0            ; Don't output unless TTY
	FPUTC                       ; Make it visible
	JUMP @Word_Main             ; Keep looping

:Word_Comment
	FGETC                       ; Get another byte
	CMPSKIPI.NE R0 13           ; If CR
	LOADUI R0 10                ; Convert to LF
	CMPSKIPI.NE R1 0            ; Don't output unless TTY
	FPUTC                       ; Make it visible
	CMPSKIPI.NE R0 4            ; IF EOF
	JUMP @Word_Done             ; Be done
	CMPSKIPI.G R0 0             ; If ERROR
	JUMP @cold_done             ; Stop processing
	CMPSKIPI.NE R0 10           ; IF Line Feed
	JUMP @Word_Done             ; Be done
	JUMP @Word_Comment          ; Otherwise keep looping

:Word_Done
	PUSHR R4 R14                ; Push pointer to string on parameter stack
	PUSHR R2 R14                ; Push number of bytes in length onto stack
	ADDUI R2 R2 4               ; Add a null to end of string
	ANDI R2 R2 -4               ; Rounded up the next for or to Zero
	ADD R4 R4 R2                ; Update pointer
	STORER R4 @STRING_BASE      ; Save its value
	RET R15

;; NUMBER
:Number_Text
"NUMBER"
:Number_Entry
	&Word_Entry                 ; Pointer to Word
	&Number_Text                ; Pointer to Name
	NOP                         ; Flags
	&Number_Code                ; Where assembly is Stored
:Number_Code
	CALLI R15 @Number_Direct    ; Trick for direct access
	JSR_COROUTINE R11           ; NEXT

:Number_Direct
	POPR R1 R14                 ; Get pointer to string for parsing
	FALSE R2                    ; Set Negate flag to false
	FALSE R3                    ; Set index to Zero
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
	LOADU8 R0 R1 0               ; Get a byte
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

:numerate_string_done
	CMPSKIPI.E R2 0             ; If Negate flag has been set
	NEG R3 R3                   ; Make the number negative
	PUSHR R3 R14                ; Store result
	RET R15                     ; Return to whoever called it

;; strcmp
:Strcmp_Text
"STRCMP"
:Strcmp_Entry
	&Number_Entry               ; Pointer to NUMBER
	&Strcmp_Text                ; Pointer to Name
	NOP                         ; Flags
	&Strcmp_Code                ; Where assembly is Stored
:Strcmp_Code
	CALLI R15 @Strcmp_Direct    ; Trick to allow direct calls
	JSR_COROUTINE R11           ; NEXT
:Strcmp_Direct
	POPR R2 R14                 ; Load pointer to string1
	POPR R3 R14                 ; Load pointer to string2
	LOADUI R4 0                 ; Starting at index 0
:cmpbyte
	LOADXU8 R0 R2 R4            ; Get a byte of our first string
	LOADXU8 R1 R3 R4            ; Get a byte of our second string
	ADDUI R4 R4 1               ; Prep for next loop
	CMP R1 R0 R1                ; Compare the bytes
	CMPSKIPI.E R0 0             ; Stop if byte is NULL
	JUMP.E R1 @cmpbyte          ; Loop if bytes are equal
	PUSHR R1 R14                ; Store the comparision result
	RET R15                     ; Return to whoever called it

;; FIND
:Find_Text
"FIND"
:Find_Entry
	&Strcmp_Entry               ; Pointer to STRCMP
	&Find_Text                  ; Pointer to Name
	NOP                         ; Flags
	&Find_Code                  ; Where assembly is Stored
:Find_Code
	CALLI R15 @Find_Direct      ; Allow Direct access
	JSR_COROUTINE R11           ; NEXT

:Find_Direct
	POPR R0 R14                 ; Get pointer to String to find
	COPY R3 R9                  ; Copy LATEST

:Find_Loop
	LOAD R1 R3 4                ; Get Pointer to string
	PUSHR R3 R14                ; Protect Node pointer
	PUSHR R0 R14                ; Protect FIND string
	PUSHR R0 R14                ; Prepare for CALL
	PUSHR R1 R14                ; Prepare for CALL
	CALLI R15 @Strcmp_Direct    ; Perform direct call
	POPR R1 R14                 ; Get return value
	POPR R0 R14                 ; Restore FIND string pointer
	POPR R3 R14                 ; Restore Node pointer
	JUMP.E R1 @Find_Done        ; If find was successful
	LOAD R3 R3 0                ; Otherwise get next pointer
	JUMP.NZ R3 @Find_Loop       ; If Not NULL keep looping

:Find_Done
	PUSHR R3 R14                ; Push pointer or Zero onto parameter stack
	RET R15                     ; Return to whoever called you

;; >CFA
:TCFA_Text
">CFA"
:TCFA_Entry
	&Find_Entry                 ; Pointer to Find
	&TCFA_Text                  ; Pointer to Name
	NOP                         ; Flags
	&TCFA_Code                  ; Where assembly is Stored
:TCFA_Code
	POPR R0 R14                 ; Get Node pointer
	ADDUI R0 R0 12              ; Move to CFA
	PUSHR R0 R14                ; Push the result
	JSR_COROUTINE R11           ; NEXT

;; >DFA
:TDFA_Text
">DFA"
:TDFA_Entry
	&TCFA_Entry                 ; Pointer to >CFA
	&TDFA_Text                  ; Pointer to Name
	NOP                         ; Flags
	&TDFA_Code                  ; Where assembly is Stored
:TDFA_Code
	POPR R0 R14                 ; Get Node pointer
	ADDUI R0 R0 16              ; Move to DFA
	PUSHR R0 R14                ; Push the result
	JSR_COROUTINE R11           ; NEXT

;; CREATE
:Create_Text
"CREATE"
:Create_Entry
	&TDFA_Entry                 ; Pointer to >DFA
	&Create_Text                ; Pointer to Name
	NOP                         ; Flags
	&Create_Code                ; Where assembly is Stored
:Create_Code
	COPY R0 R8                  ; Preserve HERE for next LATEST
	PUSHR R9 R8                 ; Store LATEST onto HEAP
	POPR R1 R14                 ; Get pointer to string
	PUSHR R1 R8                 ; Store string pointer onto HEAP
	FALSE R1                    ; Prepare NOP for Flag
	PUSHR R1 R8                 ; Push NOP Flag
	MOVE R0 R9                  ; Set LATEST
	JSR_COROUTINE R11           ; NEXT

;; DEFINE
:Define_Text
":"
:Define_Entry
	&Create_Entry               ; Pointer to Create
	&Define_Text                ; Pointer to Name
	NOP                         ; Flags
	&Define_Code                ; Where assembly is Stored
:Define_Code
	CALLI R15 @Word_Direct      ; Get Word
	COPY R0 R8                  ; Preserve HERE for next LATEST
	PUSHR R9 R8                 ; Store LATEST onto HEAP
	POPR R1 R14                 ; Get rid of string length
	POPR R1 R14                 ; Get pointer to string
	PUSHR R1 R8                 ; Store string pointer onto HEAP
	LOADUI R1 1                 ; Prepare HIDDEN for Flag
	PUSHR R1 R8                 ; Push HIDDEN Flag
	LOADUI R1 $DOCOL            ; Get address of DOCOL
	PUSHR R1 R8                 ; Push DOCOL Address onto HEAP
	MOVE R9 R0                  ; Set LATEST
	LOADUI R10 1                ; Set STATE to Compile Mode
	JSR_COROUTINE R11           ; NEXT

;; COMA
:Comma_Text
","
:Comma_Entry
	&Define_Entry               ; Pointer to DEFINE
	&Comma_Text                 ; Pointer to Name
	NOP                         ; Flags
	&Comma_Code                 ; Where assembly is Stored
:Comma_Code
	POPR R0 R14                 ; Get top of parameter stack
	PUSHR R0 R8                 ; Push onto HEAP and increment HEAP pointer
	JSR_COROUTINE R11           ; NEXT

;; [
:LBRAC_Text
"["
:LBRAC_Entry
	&Comma_Entry                ; Pointer to Comma
	&LBRAC_Text                 ; Pointer to Name
	'00000002'                  ; Flags [F_IMMED]
	&LBRAC_Code                 ; Where assembly is Stored
:LBRAC_Code
	FALSE R10                   ; Set STATE to Interpret Mode
	JSR_COROUTINE R11           ; NEXT

;; ]
:RBRAC_Text
"]"
:RBRACK_Entry
	&LBRAC_Entry                ; Pointer to LBRAC
	&RBRAC_Text                 ; Pointer to Name
	NOP                         ; Flags
	&RBRACK_Code                ; Where assembly is Stored
:RBRACK_Code
	LOADUI R10 1                ; Set State to Compile Mode
	JSR_COROUTINE R11           ; NEXT

;; ;
:SEMICOLON_Text
";"
:SEMICOLON_Entry
	&RBRACK_Entry               ; Pointer to RBRAC
	&SEMICOLON_Text             ; Pointer to Name
	'00000002'                  ; Flags [F_IMMED]
	&SEMICOLON_Code             ; Where assembly is Stored
:SEMICOLON_Code
	LOADUI R0 $EXIT_Entry       ; Get EXIT Pointer
	ADDUI R0 R0 12              ; Adjust pointer
	PUSHR R0 R8                 ; Push EXIT onto HEAP and increment HEAP pointer
	FALSE R0                    ; Prep NULL for Flag
	STORE R0 R9 8               ; Set Flag
	FALSE R10                   ; Set State to Interpret Mode
	JSR_COROUTINE R11           ; NEXT

;; Branching

;; BRANCH
:Branch_Text
"BRANCH"
:Branch_Entry
	&SEMICOLON_Entry            ; Pointer to Semicolon
	&Branch_Text                ; Pointer to Name
	NOP                         ; Flags
:Branch
	&Branch_Code                ; Where assembly is Stored
:Branch_Code
	LOAD R0 R13 0               ; Get Contents of NEXT
	ADD R13 R13 R0              ; Update NEXT with offset
	JSR_COROUTINE R11           ; NEXT

;; 0BRANCH
:0Branch_Text
"0BRANCH"
:0Branch_Entry
	&Branch_Entry               ; Pointer to Branch
	&0Branch_Text               ; Pointer to Name
	NOP                         ; Flags
	&0Branch_Code               ; Where assembly is Stored
:0Branch_Code
	POPR R1 R14                 ; Get value off parameter stack
	LOADUI R0 4                 ; Default offset of 4
	CMPSKIPI.NE R1 0            ; If not Zero use default offset
	LOAD R0 R13 0               ; Otherwise use Contents of NEXT
	ADD R13 R13 R0              ; Set NEXT to NEXT plus the offset
	JSR_COROUTINE R11           ; NEXT

;; Interaction Commands

;; QUIT
:Quit_Text
"QUIT"
:Quit_Entry
	&0Branch_Entry              ; Pointer to 0Branch
	&Quit_Text                  ; Pointer to Name
	NOP                         ; Flags
:Quit_Code
	&DOCOL                      ; Use DOCOL
	&RETURN_CLEAR               ; Clear the return stack
	&Interpret_Loop             ; INTERPRET
	&Branch                     ; Loop forever
	'FFFFFFF4'                  ; -12


;; INTERPRET
:Interpret_Text
"INTERPRET"
:Interpret_Entry
	&Quit_Entry                 ; Pointer to QUIT
	&Interpret_Text             ; Pointer to Name
	NOP                         ; Flags
:Interpret_Loop
	&Interpret_Code             ; Where assembly is Stored
:Interpret_Code
	CALLI R15 @Word_Direct      ; Get the Word
	POPR R0 R14                 ; Remove Length
	POPR R0 R14                 ; Remove Pointer
	PUSHR R0 R14                ; Protect Pointer
	PUSHR R0 R14                ; Put Pointer
	CALLI R15 @Find_Direct      ; Try to Find it
	POPR R0 R14                 ; Get result of Search
	JUMP.Z R0 @Interpret_Literal ; Since it wasn't found assume it is a literal

;; Found Node
	POPR R1 R14                 ; Clean up unneed stack
	LOAD R1 R0 8                ; Get Flags of found node
	ANDI R1 R1 0x2              ; Check if F_IMMED is set
	JUMP.Z R1 @Interpret_Compile ; Its not immediate so I might have to compile

:Interpret_Execute
	ADDUI R12 R0 12             ; Point to codeword
	LOAD R1 R0 12               ; Get where to jump
	JSR_COROUTINE R1            ; EXECUTE Directly

:Interpret_Compile
	ANDI R1 R10 1               ; Check if we are in compile mode
	JUMP.Z R1 @Interpret_Execute ; If not execute the node
	ADDUI R0 R0 12              ; Adjust pointer to body of Node
	PUSHR R0 R8                 ; Append to HEAP
	JSR_COROUTINE R11           ; NEXT

:Interpret_Literal
	CALLI R15 @Number_Direct    ; Attempt to process string as number
	ANDI R0 R10 1               ; Check if we are in compile mode
	CMPSKIPI.NE R0 0            ; If not compiling
	JSR_COROUTINE R11           ; Simply leave on stack and NEXT

	LOADUI R0 $LIT_Entry        ; Get address of LIT
	ADDUI R0 R0 12              ; Adjust to point to direct code
	PUSHR R0 R8                 ; Append pointer to HEAP
	POPR R0 R14                 ; Get Immediate value
	PUSHR R0 R8                 ; Append Immediate to HEAP
	JSR_COROUTINE R11           ; NEXT

;; Cold done function
;; Reads Tape_01 until EOF
;; Then switches into TTY Mode
:cold_done
	;; IF TTY Recieves EOF call it quits
	CMPSKIPI.NE R7 0            ; Check if TTY
	HALT                        ; User is done

	;; Prep TTY
	FALSE R7                    ; Set TTY ID
	LOADUI R13 $Cold_Start      ; Prepare to return to QUIT LOOP
	JSR_COROUTINE R11           ; NEXT

;; Where our HEAP Starts
:HEAP
