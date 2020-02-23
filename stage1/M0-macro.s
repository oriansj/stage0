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

:start
	;; We will be using R13 for storage of Head
	LOADUI R14 0x700            ; Our malloc pointer (Initialized)
	LOADUI R15 $stack           ; Put stack at end of program

;; Main program
;; Reads contents of Tape_01 and applies all Definitions
;; Writes results to Tape_02
;; Accepts no arguments and HALTS when done
:main
	CALLI R15 @Tokenize_Line    ; Call Tokenize_Line
	CALLI R15 @reverse_list     ; Reverse the list of tokens
	CALLI R15 @Identify_Macros  ; Tag all nodes that are macros
	CALLI R15 @Line_Macro       ; Apply macros down nodes
	CALLI R15 @Process_String   ; Convert string values to Hex16
	CALLI R15 @Eval_Immediates  ; Convert numbers to hex
	CALLI R15 @Preserve_Other   ; Ensure labels/Pointers aren't lost
	CALLI R15 @Print_Hex        ; Write Nodes to Tape_02
	HALT                        ; We are Done


;; Tokenize_Line function
;; Opens tape_01 and reads into a backwards linked list in R13
;; Returns to whatever called it
:Tokenize_Line
	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	FALSE R13                   ; Head is NULL
	MOVE R1 R0                  ; Read Tape_01

:Tokenize_Line_0
	FGETC                       ; Get a Char

	;; Deal with lines comments starting with #
	CMPSKIPI.NE R0 35
	JUMP @Purge_Line_Comment

	;; Deal with Line comments starting with ;
	CMPSKIPI.NE R0 59
	JUMP @Purge_Line_Comment

	;; Deal with Tab
	CMPSKIPI.NE R0 9
	JUMP @Tokenize_Line_0       ; Throw away byte and try again

	;; Deal with New line
	CMPSKIPI.NE R0 10
	JUMP @Tokenize_Line_0       ; Throw away byte and try again

	;; Deal with space characters
	CMPSKIPI.NE R0 32
	JUMP @Tokenize_Line_0       ; Throw away byte and try again

	;; Stop if EOF
	CMPSKIPI.GE R0 0
	JUMP @Tokenize_Line_Done

	;; Allocate a new Node
	COPY R2 R14                 ; Get address of new Node
	ADDUI R14 R14 16            ; Allocate 16 Bytes
	STORE32 R14 R2 8            ; Set Text pointer

	;; Deal with Strings wrapped in "
	CMPSKIPI.NE R0 34
	JUMP @Store_String

	;; Deal with Strings wrapped in '
	CMPSKIPI.NE R0 39
	JUMP @Store_String

	;; Everything else is an atom store it
	CALLI R15 @Store_Atom

:Tokenize_Line_1
	STORE32 R13 R2 0            ; Set p->next to head
	MOVE R13 R2                 ; Set head to p
	JUMP @Tokenize_Line_0       ; Keep getting tokens

:Tokenize_Line_Done
	;; Done reading File
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE
	RET R15


;; reverse_list Function
;; Reverses the list given in R13
:reverse_list
	;; Initialize
	COPY R0 R13                 ; Using R0 as head
	FALSE R1                    ; Using R1 as root
	                            ; Using R2 as next

:reverse_list_0
	JUMP.Z R0 @reverse_list_done ; Stop if NULL == head
	LOAD R2 R0 0                ; next = head->next
	STORE R1 R0 0               ; head->next = root
	MOVE R1 R0                  ; root = head
	MOVE R0 R2                  ; head = next
	JUMP @reverse_list_0        ; Keep looping

:reverse_list_done
	;; Clean up
	MOVE R13 R1                 ; Set token_list to root
	RET R15


;; Purge_Line_Comment Function
;; Receives char in R0 and desired input in R1
;; Modifies R0
;; Returns to Tokenize_Line as if the entire line
;; Comment never existed
:Purge_Line_Comment
	FGETC                       ; Get another Char
	CMPSKIPI.E R0 10            ; Stop When LF is reached
	JUMP @Purge_Line_Comment    ; Otherwise keep looping
	JUMP @Tokenize_Line_0       ; Return as if this never happened


;; Store_String function
;; Receives Char in R0, desired input in R1
;; And node pointer in R2
;; Modifies node Text to point to string and sets
;; Type to string.
:Store_String
	;; Initialize
	COPY R3 R0                  ; Copy Char for comparison

:Store_String_0
	STORE8 R0 R14 0             ; Store the Byte
	FGETC                       ; Get next Byte
	ADDUI R14 R14 1             ; Prep for next loop
	CMPJUMPI.NE R0 R3 @Store_String_0 ; Loop if matching not found

	;; Clean up
	ADDUI R14 R14 4             ; Correct Malloc
	LOADUI R0 2                 ; Using type string
	STORE32 R0 R2 4             ; Set node type
	JUMP @Tokenize_Line_1


;; Store_Atom function
;; Receives Char in R0, desired input in R1
;; And node pointer in R2
;; Modifies node Text to point to string
:Store_Atom
	STORE8 R0 R14 0             ; Store the Byte
	FGETC                       ; Get next Byte
	ADDUI R14 R14 1             ; Prep for next loop

	CMPSKIPI.NE R0 9            ; If char is Tab
	JUMP @Store_Atom_Done       ; Be done

	CMPSKIPI.NE R0 10           ; If char is LF
	JUMP @Store_Atom_Done       ; Be done

	CMPSKIPI.NE R0 32           ; If char is Space
	JUMP @Store_Atom_Done       ; Be done

	;; Otherwise loop
	JUMP @Store_Atom

:Store_Atom_Done
	;; Cleanup
	ADDUI R14 R14 1             ; Correct Malloc
	RET R15


;; strcmp function
;; Receives pointers to null terminated strings
;; In R0 and R1
;; Returns if they are equal in R0
;; Returns to whatever called it
:strcmp
	;; Preserve registers
	PUSHR R1 R15
	PUSHR R2 R15
	PUSHR R3 R15
	PUSHR R4 R15

	;; Setup registers
	MOVE R2 R0                  ; Put R0 in a safe place
	MOVE R3 R1                  ; Put R1 in a safe place
	FALSE R4                    ; Starting at index 0

:cmpbyte
	LOADXU8 R0 R2 R4            ; Get a byte of our first string
	LOADXU8 R1 R3 R4            ; Get a byte of our second string
	ADDUI R4 R4 1               ; Prep for next loop
	CMP R0 R0 R1                ; Compare the bytes
	CMPSKIPI.E R1 0             ; Stop if byte is NULL
	JUMP.E R0 @cmpbyte          ; Loop if bytes are equal

;; Done
	;; Restore registers
	POPR R4 R15
	POPR R3 R15
	POPR R2 R15
	POPR R1 R15
	RET R15


;; Identify_Macros Function
;; If the text stored in its Text segment matches
;; DEFINE, flag it and Collapse it down to a single Node
;; Loop until all nodes are checked
;; Return to whatever called it
:Identify_Macros
	;; Initializ
	LOADUI R1 $Identify_Macros_string
	COPY R2 R13                 ; i = head

	;; Main Loop
:Identify_Macros_0
	LOAD32 R0 R2 8              ; Get Pointer to Text
	CALLI R15 @strcmp
	JUMP.NE R0 @Identify_Macros_1

	;; It is a definition
	;; Set i->Type = macro
	LOADUI R0 1                 ; The Enum value for macro
	STORE32 R0 R2 4             ; Set node type

	;; Set i->Text = i->Next->Text
	LOAD32 R4 R2 0              ; Get Next
	LOAD32 R0 R4 8              ; Get Next->Text
	STORE32 R0 R2 8             ; Set i->Text = Next->Text

	;; Set i->Expression = i->next->next->Text
	LOAD32 R4 R4 0              ; Get Next->Next
	LOAD32 R0 R4 8              ; Get Next->Next->Text
	LOAD32 R3 R4 4              ; Get Next->Next->type
	CMPSKIPI.NE R3 2            ; If node is a string
	ADDUI R0 R0 1               ; Skip first char
	STORE32 R0 R2 12            ; Set Expression = Next->Next->Text

	;; Set i->Next = i->Next->Next->Next
	LOAD32 R4 R4 0              ; Get Next->Next->Next
	STORE32 R4 R2 0             ; Set i->Next = Next->Next->Next

:Identify_Macros_1
	LOAD32 R2 R2 0              ; Get node->next
	JUMP.NZ R2 @Identify_Macros_0 ; Loop if i not NULL
	RET R15

:Identify_Macros_string
"DEFINE"


;; Line_Macro Function
;; Receives a node pointer in R0
;; Causes macros to be applied
;; Returns to whatever called it
:Line_Macro
	;; Initialize
	COPY R0 R13                 ; Start with Head

	;; Main loop
:Line_Macro_0
	LOAD32 R3 R0 4              ; Load Node type
	LOAD32 R2 R0 12             ; Load Expression pointer
	LOAD32 R1 R0 8              ; Load Text pointer
	LOAD32 R0 R0 0              ; Load Next pointer
	CMPSKIPI.NE R3 1            ; If a macro
	CALLI R15 @setExpression    ; Apply to other nodes
	JUMP.NZ R0 @Line_Macro_0    ; If Next is Null Don't loop
	RET R15


;; setExpression Function
;; Receives a node pointer in R0
;; A string pointer to compare against in R1
;; A string pointer for replacement in R2
;; Doesn't modify any registers
;; Returns to whatever called it
:setExpression
	;; Preserve registers
	PUSHR R0 R15

	;; Initialize
	COPY R4 R0                  ; Use R4 for Node pointer

:setExpression_0
	LOAD32 R3 R4 4              ; Load type into R3
	CMPSKIPI.NE R3 1            ; Check if Macro
	JUMP @setExpression_1       ; Move to next if Macro
	LOAD32 R0 R4 8              ; Load Text pointer into R0 for Comparision
	CALLI R15 @strcmp           ; compare Text and Macro Text
	JUMP.NE R0 @setExpression_1 ; Move to next if not Match
	STORE32 R2 R4 12            ; Set node->Expression = Exp

:setExpression_1
	LOAD32 R4 R4 0              ; Load Next
	JUMP.NZ R4 @setExpression_0 ; Loop if next isn't NULL

:setExpression_Done
	;; Restore registers
	POPR R0 R15
	RET R15


;; Process_String Function
;; Receives a Node in R0
;; Doesn't modify registers
;; Returns back to whatever called it
:Process_String
	;; Initialize
	COPY R0 R13                 ; Start with Head

:Process_String_0
	;; Get node type
	LOAD32 R1 R0 4              ; Load Type
	CMPSKIPI.E R1 2             ; If not a string
	JUMP @Process_String_Done   ; Just go to next

	;; Its a string
	LOAD32 R1 R0 8              ; Get Text pointer
	LOAD8 R2 R1 0               ; Get first char of Text

	;; Deal with '
	CMPSKIPI.E R2 39            ; If char is not '
	JUMP @Process_String_1      ; Move to next label

	;; Simply use Hex strings as is
	ADDUI R1 R1 1               ; Move Text pointer by 1
	STORE32 R1 R0 12            ; Set expression to Text + 1
	JUMP @Process_String_Done   ; And move on

:Process_String_1
	;; Deal with (")
	CALLI R15 @Hexify_String

:Process_String_Done
	LOAD32 R0 R0 0              ; Load Next
	JUMP.NZ R0 @Process_String_0 ; If Next isn't NULL Recurse down list
	RET R15


;; Hexify_String Function
;; Receives a node pointer in R0
;; Converts Quoted text to Hex values
;; Pads values up to multiple of 4 bytes
;; Doesn't modify registers
;; Returns to whatever called it
:Hexify_String
	;; Preserve Registers
	PUSHR R0 R15

	;; Initialize
	MOVE R1 R0                  ; Move R0 out of the way
	STORE32 R14 R1 12           ; Set node expression pointer
	LOAD32 R1 R1 8              ; Load Text pointer into R2
	ADDUI R1 R1 1               ; SKip leading "

	;; Main Loop
:Hexify_String_0
	LOAD32 R0 R1 0              ; Load 4 bytes into R0 from Text
	ANDI R2 R0 0xFF             ; Preserve byte to check for NULL
	CALLI R15 @hex32            ; Convert to hex and store in Expression
	ADDUI R1 R1 4               ; Pointer Text pointer to next 4 bytes
	JUMP.NZ R2 @Hexify_String_0

	;; Done
	ADDUI R14 R14 1             ; Correct malloc value
	POPR R0 R15
	RET R15


;; hex32 functionality
;; Accepts 32bit value in R0
;; Require R14 to be the heap pointer
;; WILL ALTER R14 !
;; Returns to whatever called it
:hex32
	PUSHR R0 R15
	SR0I R0 16                  ; Do high word first
	CALLI R15 @hex16
	POPR R0 R15
:hex16
	PUSHR R0 R15
	SR0I R0 8                   ; Do high byte first
	CALLI R15 @hex8
	POPR R0 R15
:hex8
	PUSHR R0 R15
	SR0I R0 4                   ; Do high nybble first
	CALLI R15 @hex4
	POPR R0 R15
:hex4
	ANDI R0 R0 0xF              ; isolate nybble
	ADDUI R0 R0 48              ; convert to ascii
	CMPSKIPI.LE R0 57           ; If nybble was greater than '9'
	ADDUI R0 R0 7               ; Shift it into 'A' range of ascii
	STORE8 R0 R14 0             ; Store Hex Char
	ADDUI R14 R14 1             ; Increment address pointer
	RET R15                     ; Get next nybble or return if done


;; Eval_Immediates function
;; Receives a node in R0
;; Converts number into Hex
;; And write into Memory and fix pointer
:Eval_Immediates
	;; Initialize
	COPY R3 R13                 ; Start with Head

;; Process Text
:Eval_Immediates_0
	LOAD32 R2 R3 0              ; Load Node->Next
	LOAD32 R0 R3 12             ; Load Expression pointer
	JUMP.NZ R0 @Eval_Immediates_1 ; Don't do anything if Expression is set
	LOAD32 R0 R3 4              ; Load Node type
	JUMP.NZ R0 @Eval_Immediates_1 ; Don't do anything if Typed
	LOAD32 R0 R3 8              ; Load Text pointer
	LOAD8 R1 R0 0               ; Get first char of Text
	CALLI R15 @numerate_string  ; Convert to number in R0
	CMPSKIPI.E R1 48            ; Skip next comparision if '0'
	JUMP.Z R0 @Eval_Immediates_1 ; Don't do anything if string isn't a number
	STORE R14 R3 12             ; Preserve pointer to expression
	CALLI R15 @hex16            ; Shove our number into expression
	ADDUI R14 R14 1             ; Allocate enough space for a null

;; Handle looping
:Eval_Immediates_1
	MOVE R3 R2                  ; Prepare for next loop
	JUMP.NZ R3 @Eval_Immediates_0 ; And loop
	RET R15


;; numerate_string function
;; Receives pointer To string in R0
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
	JUMP.Z R0 @numerate_string_done ; If NULL Be done

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


;; Preserve_Other function
;; Sets Expression pointer to Text pointer value
;; For all unset nodes
:Preserve_Other
	;; Initialize
	COPY R0 R13                 ; Start with HEAD

;; Process Node
:Preserve_Other_0
	LOAD32 R2 R0 0              ; Load Node->Next
	LOAD32 R1 R0 4              ; Load Node type
	JUMP.NZ R1 @Preserve_Other_1 ; Don't do anything if Typed
	LOAD32 R1 R0 12             ; Load Expression pointer
	JUMP.NZ R1 @Preserve_Other_1 ; Don't do anything if Expression is set
	LOAD32 R1 R0 8              ; Load Text pointer
	STORE32 R1 R0 12            ; Set Expression pointer to Text pointer

;; Loop through nodes
:Preserve_Other_1
	MOVE R0 R2                  ; Prepare for next loop
	JUMP.NZ R0 @Preserve_Other_0
	RET R15


;; Print_Hex Function
;; Print all of the expressions
;; Starting with HEAD
:Print_Hex
	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE

	;; Initialize
	COPY R0 R13                 ; Start with HEAD
	LOADUI R1 0x1101            ; Write to Tape_02

:Print_Hex_0
	LOAD32 R2 R0 0              ; Load Node->Next
	LOAD32 R3 R0 4              ; Load Node type
	LOAD32 R0 R0 12             ; Load Expression pointer

	SUBI R3 R3 1                ; Check for Macros
	JUMP.Z R3 @Print_Hex_1      ; Don't print Macros
	CALLI R15 @Print_Line       ; Print the Expression

;; Loop down the nodes
:Print_Hex_1
	MOVE R0 R2                  ; Prepare for next loop
	JUMP.NZ R0 @Print_Hex_0     ; Keep looping if not NULL

	;; Done writing File
	LOADUI R0 0x1101            ; Close TAPE_01
	FCLOSE
	RET R15


;; Print_Line Function
;; Receives a pointer to a string in R0
;; And an interface in R1
;; Writes all Chars in string
;; Then writes a New line character to interface
:Print_Line
	;; Initialize
	MOVE R3 R0                  ; Get Pointer safely out of the way

:Print_Line_0
	LOADU8 R0 R3 0              ; Get our first byte
	CMPSKIPI.NE R0 0            ; If the loaded byte is NULL
	JUMP @Print_Line_Done       ; Be done
	FPUTC                       ; Otherwise print
	ADDUI R3 R3 1               ; Increment for next loop
	JUMP @Print_Line_0          ; And Loop

;; Clean up
:Print_Line_Done
	LOADUI R0 10                ; Put in Newline char
	FPUTC                       ; Write it out
	RET R15


;; Where we are putting the start of our stack
:stack
