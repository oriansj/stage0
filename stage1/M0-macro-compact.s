; Copyright (C) 2020 Jeremiah Orians
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
	;; We will be using R12 for scratch
	;; We will be using R13 for storage of tokens
	LOADUI R14 0x800           ; Our malloc pointer (Initialized)
	LOADUI R15 $stack           ; Put stack at end of program

	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE

	;; Setup offset table
	READSCID R0                 ; Get process capabilities
	ANDI R1 R0 0xF              ; We only care about size nybble
	LOADUI R0 1                 ; Assume we are 8bit
	SL0 R0 R0 R1                ; Let size nybble correct answer
	STORER16 R0 @offset_Text    ; Set ->TEXT offset
	ADDU R1 R0 R0               ; twice the size is the offset of the expression
	STORER16 R1 @offset_Expression ; Set ->EXPRESSION offset
	ADDU R0 R1 R0               ; 3 times the size of the register is the size of the struct
	STORER16 R0 @offset_struct  ; Set offset_struct

;; Main program
;; Reads contents of Tape_01 and applies all Definitions
;; Writes results to Tape_02
;; Accepts no arguments and HALTS when done
:main
	COPY R12 R14                ; calloc scratch
	CALLI R15 @collect_defines  ; Get all the defines

	;; We need to rewind tape_01 to perform our second pass
	LOADUI R0 0x1100
	REWIND

	FALSE R0                    ; Make sure not EOF
	CALLI R15 @generate_output  ; Write the results to Tape_02
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE
	LOADUI R0 0x1101            ; Close TAPE_02
	FCLOSE
	HALT                        ; We are Done


;; match function
;; Receives a CHAR* in R0, CHAR* in R1
;; Returns Bool in R0 indicating if strings match
:match
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	MOVE R2 R0                  ; Put First string in place
	MOVE R3 R1                  ; Put Second string in place
	LOADUI R4 0                 ; Set initial index of 0
:match_cmpbyte
	LOADXU8 R0 R2 R4            ; Get a byte of our first string
	LOADXU8 R1 R3 R4            ; Get a byte of our second string
	ADDUI R4 R4 1               ; Prep for next loop
	CMPSKIP.NE R1 R0            ; Compare the bytes
	JUMP.NZ R1 @match_cmpbyte   ; Loop if bytes are equal
;; Done
	FALSE R2                    ; Default answer
	CMPSKIP.NE R0 R1            ; If ended loop with everything matching
	TRUE R2                     ; Set as TRUE
	MOVE R0 R2                  ; Prepare for return
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; in_set function
;; Receives a Char in R0, char* in R1
;; Return result in R0
:in_set
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2 from changes
:in_set_reset
	LOADU8 R2 R1 0              ; Get char from list
	JUMP.Z R2 @in_set_fail      ; Stop when 0 == s[0]
	CMPJUMPI.E R0 R2 @in_set_done ; We found a match
	ADDUI R1 R1 1               ; Increment to next char
	JUMP.NZ R2 @in_set_reset    ; Iterate if not NULL

:in_set_fail
	;; Looks like not found
	FALSE R1                    ; Return FALSE

:in_set_done
	CMPSKIPI.E R1 0             ; Provided not FALSE
	TRUE R2                     ; The result is true
	MOVE R0 R2                  ; Put result in correct place
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; file_print function
;; Receives pointer to string in R0 and FILE* in R1
;; Returns nothing
:file_print
	PUSHR R2 R15                ; Protect R2 from Overwrite
	MOVE R2 R0                  ; Put string pointer into place
:file_print_read
	LOAD8 R0 R2 0               ; Get a char
	JUMP.Z R0 @file_print_done  ; If NULL be done
	FPUTC                       ; Write the Char
	ADDUI R2 R2 1               ; Point at next CHAR
	JUMP @file_print_read       ; Loop again
:file_print_done
	POPR R2 R15                 ; Restore R2
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


;; collect_defines function
;; Returns nothing
;; Recieves nothing
;; Simply reads one token at a time
;; Collecting the DEFINEs
;; Uses R0, R1 and R2 as temps
;; Updates R12 scratch, R13 tokens and R14 HEAP
:collect_defines
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
:collect_defines_loop
	CALLI R15 @read_token       ; c = read_token();
	PUSHR R0 R15                ; Protect C
	COPY R0 R12                 ; Using scratch
	LOADUI R1 $DEFINE_STRING    ; Using "DEFINE"
	CALLI R15 @match            ; See if they match
	JUMP.NZ R0 @collect_defines_valid ; Looks like we have a match
	CALLI R15 @clear_scratch    ; Clear out the scratch buffer
	POPR R0 R15                 ; Restore C
	JUMP.NP R0 @collect_defines_done ; Hit EOF
	JUMP @collect_defines_loop  ; Otherwise keep looping

:collect_defines_valid
	POPR R0 R15                 ; Restore C
	CALLI R15 @clear_scratch    ; Clear out the scratch buffer
	LOADR16 R0 @offset_struct   ; Get the size of the struct
	ADDU R14 R14 R0             ; Allocate struct
	STORE R13 R12 0             ; N->NEXT = tokens
	COPY R13 R12                ; tokens = N
	COPY R12 R14                ; SCRATCH = CALLOC(max_string, sizeof(char));
	CALLI R15 @read_token       ; get the text of the define
	LOADR16 R0 @offset_Text     ; Get ->TEXT offset
	STOREX R12 R13 R0           ; N->TEXT = scratch
	ADDUI R14 R14 1             ; Add some NULL padding
	COPY R12 R14                ; SCRATCH = CALLOC(max_string, sizeof(char)); length = 0;
	CALLI R15 @read_token       ; Get the expression of the define
	PUSHR R0 R15                ; Protect C
	LOADR16 R0 @offset_Expression ; Get ->EXPRESSION offset
	STOREX R12 R13 R0           ; N->EXPRESSION = scratch
	ADDUI R14 R14 1             ; Add some NULL padding
	COPY R12 R14                ; SCRATCH = CALLOC(max_string, sizeof(char)); length = 0;
	POPR R0 R15                 ; Restore C
	JUMP.P R0 @collect_defines_loop ; Keep looping if not NULL

:collect_defines_done
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15


;; read_token function
;; Returns int C in R0
;; Updates the contents of (R12) scratch and (R12-R14)length (via updating HEAP (R14))
;; Uses R0, R1 and R2 as temps
:read_token
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	LOADUI R1 0x1100            ; Using TAPE_01
	FGETC                       ; Read a byte

	JUMP.NP R0 @read_token_done ; if EOF, just return EOF
	CMPSKIPI.NE R0 10           ; IF '\n' just return '\n'
	JUMP @read_token_done       ; Be done
	CMPSKIPI.NE R0 9            ; IF '\t' just return '\t'
	JUMP @read_token_done       ; Be done
	CMPSKIPI.NE R0 32           ; IF ' ' just return ' '
	JUMP @read_token_done       ; Be done

	COPY R2 R0                  ; Protect C
	LOADUI R1 $read_token_comments ; Using "#;"
	CALLI R15 @in_set           ; Check if in set
	LOADUI R1 0x1100            ; Using TAPE_01
	JUMP.NZ R0 @delete_line_comment ; Then it is a line comment and needs to be purged
	COPY R0 R2                  ; Put C into place for write
	CMPSKIPI.NE R0 34           ; IF '"'
	JUMP @read_string           ; Collect that string
	CMPSKIPI.NE R0 39           ; IF "'"
	JUMP @read_string           ; Collect that string

	;; Deal with the fallthrough case of a single token
:read_token_loop
	PUSH8 R2 R14                ; scratch[length] = c; length = length + 1;
	LOADUI R1 0x1100            ; Using TAPE_01
	FGETC                       ; Read a byte
	COPY R2 R0                  ; Protect C
	LOADUI R1 $read_token_whitespace ; Using " \t\n"
	CALLI R15 @in_set           ; IF in set
	JUMP.Z R0 @read_token_loop  ; Otherwise keep looping
	MOVE R0 R2                  ; Return our C
	JUMP @read_token_done       ; else be done

	;; Deal with line comment case
:delete_line_comment
	FGETC                       ; Read a byte
	CMPSKIPI.NE R0 10           ; IF '\n'
	JUMP @read_token_done       ; Be done
	JUMP @delete_line_comment   ; Otherwise keep looping

	;; Deal with "RAW STRINGS" and 'HEX LITERALS'
	;; R1 is already TAPE_01 and R2 is the terminator
:read_string
	PUSH8 R0 R14                ; scratch[length] = c; length = length + 1;
	FGETC                       ; Read a byte
	CMPJUMPI.NE R0 R2 @read_string ; Keep looping if not terminator

:read_token_done
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15

:read_token_comments
	"#;"
:read_token_whitespace
	" 	
"


;; clear_scratch function
;; Recieves nothing
;; Returns nothing
;; Clears SCRATCH (R12) and LENGTH (R14-R12) by POPing off the HEAP (R14)
:clear_scratch
	PUSHR R0 R15                ; Protect R0
:clear_scratch_loop
	CMPJUMPI.E R12 R14 @clear_scratch_done ; When LENGTH == 0 and SCRATCH is cleared
	POP8 R0 R14                 ; Clear the last byte of SCRATCH and decrement LENGTH
	JUMP @clear_scratch_loop    ; Keep looping
:clear_scratch_done
	POPR R0 R15                 ; Restore R0
	RET R15


	;; generate_output function
	;; Returns nothing
	;; Recieves nothing
	;; Simply reads one token at a time
	;; Outputting if possible
	;; Uses R0, R1 and R2 as temps
	;; Manipulates SCRATCH (R12) and LENGTH (R14-R12) but should reset HEAP (R14) each loop
:generate_output
	JUMP.NP R0 @generate_output_done ; Stop if we hit EOF
	CALLI R15 @clear_scratch    ; Clear the scratch
	CALLI R15 @read_token       ; Get a token
	CMPJUMPI.E R12 R14 @generate_output ; Go again if we read nothing
	COPY R2 R0                  ; Protect C
	LOAD8 R0 R12 0              ; SCRATCH[0]
	LOADUI R1 $generate_output_hex ; Using ":!@$%&"
	CALLI R15 @in_set           ; See if worth keeping
	JUMP.Z R0 @generate_output_define

	;; Deal with the case of labels and pointers
	COPY R0 R12                 ; Using scratch
	LOADUI R1 0x1101            ; And TAPE_02
	CALLI R15 @file_print       ; Print it
	LOADUI R0 10                ; Using '\n'
	FPUTC                       ; fputc('\n', TAPE_02);
	MOVE R0 R2                  ; Put C in correct spot for catching EOF
	JUMP @generate_output       ; Loop it

:generate_output_define
	COPY R0 R12                 ; Using SCRATCH
	LOADUI R1 $DEFINE_STRING    ; Using "DEFINE"
	CALLI R15 @match            ; See if we have a match
	JUMP.Z R0 @generate_output_string ; If not try a string

	;; Deal with the case of DEFINE statement
	CALLI R15 @clear_scratch    ; Clear out the scratch
	CALLI R15 @read_token       ; Get a token
	CALLI R15 @clear_scratch    ; Clear out the scratch
	CALLI R15 @read_token       ; Get a token
	JUMP @generate_output       ; Loop it

:generate_output_string
	LOAD8 R0 R12 0              ; SCRATCH[0]
	CMPSKIPI.E R0 34            ; If SCRATCH[0] == '"'
	JUMP @generate_output_literal ; Otherwise try next

	;; Deal with the case of "RAW STRING"
	LOADUI R1 0x1101            ; And TAPE_02
	CALLI R15 @hexify_string    ; Write it
	LOADUI R0 10                ; Using '\n'
	FPUTC                       ; Write it
	MOVE R0 R2                  ; Return C
	JUMP @generate_output       ; Loop it

:generate_output_literal
	CMPSKIPI.E R0 39            ; If SCRATCH[0] == '\''
	JUMP @generate_output_defined ; Otherwise try next

	;; Deal with the case of 'HEX LITERAL'
	ADDUI R0 R12 1              ; Using SCRATCH + 1
	LOADUI R1 0x1101            ; And TAPE_02
	CALLI R15 @file_print       ; Print it
	LOADUI R0 10                ; Using '\n'
	FPUTC                       ; Write it
	MOVE R0 R2                  ; Return C
	JUMP @generate_output       ; Loop it

:generate_output_defined
	CALLI R15 @find_match       ; Lets see if SCRATCH has a match
	JUMP.Z R0 @generate_output_number ; Nope, try a NUMBER

	;; Deal with case of a DEFINED token
	LOADUI R1 0x1101            ; And TAPE_02
	CALLI R15 @file_print       ; Print it
	LOADUI R0 10                ; Using '\n'
	FPUTC                       ; Write it
	MOVE R0 R2                  ; Return C
	JUMP @generate_output       ; Loop it

:generate_output_number
	COPY R0 R12                 ; Using SCRATCH
	LOAD8 R1 R12 0              ; Get SCRATCH[0]
	CALLI R15 @numerate_string  ; See if it is a number
	CMPSKIPI.E R1 48            ; IF '0' == SCRATCH[0]
	JUMP.Z R0 @generate_output_fail ; We failed

	;; Deal with the case of numbers
	LOADUI R1 0x1101            ; And TAPE_02
	CALLI R15 @hex16            ; Write it
	LOADUI R0 10                ; Using '\n'
	FPUTC                       ; Write it
	MOVE R0 R2                  ; Return C
	JUMP @generate_output       ; Loop it

:generate_output_fail
	FALSE R1                    ; Write to STDOUT
	LOADUI R0 $generate_output_message1 ; Put our header
	CALLI R15 @file_print       ; Print it
	MOVE R0 R12                 ; Using SCRATCH
	CALLI R15 @file_print       ; Print it
	LOADUI R0 $generate_output_message2 ; Put our header
	CALLI R15 @file_print       ; Print it
	HALT                        ; FUCK

:generate_output_done
	RET R15

:generate_output_hex
	":!@$%&"

:generate_output_message1
	"
Unknown other: "

:generate_output_message2
	"
Aborting to prevent problems
"


;; hexify_string function
;; Recieves FILE* in R1
;; Writes SCRATCH (R12)
;; Uses R2 to check for hitting NULL and R3 for I
:hexify_string
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R12 R15               ; Protect R12
	ADDUI R12 R12 1             ; Skip past the '"'
	FALSE R3                    ; I = 0
:hexify_string_loop
	LOADXU16 R0 R12 R3          ; Grab 2 bytes
	ANDI R2 R0 0xFF             ; Preserve byte to check for NULL
	CALLI R15 @hex16            ; Convert to hex and print
	ADDUI R3 R3 2               ; I = I + 2
	JUMP.NZ R2 @hexify_string_loop

	;; Deal with extra padding
:hexify_string_padding
	FALSE R0                    ; Writing ZERO
	ANDI R3 R3 0x3              ; (I & 0x3)
	JUMP.Z R3 @hexify_string_done ; IF (0 == (I & 0x3)) be done
	CALLI R15 @hex8             ; Write another NULL byte
	ADDUI R3 R3 1               ; I = I + 1
	JUMP @hexify_string_padding ; Keep padding

:hexify_string_done
	POPR R12 R15                ; Restore R12
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	RET R15


;; hex16 functionality
;; Accepts 16bit value in R0
;; And FILE* output in R1
;; Returns to whatever called it
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
	FPUTC                       ; Write HEX
	RET R15                     ; Get next nybble or return if done


	;; find_match function
	;; Recieves SCRATCH in R12
	;; And tokens in R13
	;; Returns NULL or EXPRESSION if match found
:find_match
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	COPY R2 R13                 ; P = tokens
:find_match_loop
	JUMP.Z R2 @find_match_done  ; Be done if not found
	LOADR16 R1 @offset_Text     ; Get ->TEXT offset
	LOADX R0 R2 R1              ; Using P->TEXT
	COPY R1 R12                 ; Using SCRATCH
	CALLI R15 @match            ; See if they match
	JUMP.NZ R0 @find_match_success ; Found it
	LOAD R2 R2 0                ; P = P->NEXT
	JUMP @find_match_loop       ; Keep looping

	;; Deal with match
:find_match_success
	LOADR16 R1 @offset_Expression ; Using ->EXPRESSION offset
	LOADX R2 R2 R1              ; Using P->EXPRESSION
:find_match_done
	MOVE R0 R2                  ; Put result in R0
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; offset table
;; Values will be updated to reflect
;; register sizes greater than 8bits
;; if registers are larger than 8 bits
;; Padded with 2 extra NULLs to help the Disassembler
;; As 4byte alignment is generally assumed to simply
;; Work required to figure out strings
:offset_Text
	1
:offset_Expression
	2
:offset_struct
	3
	'00 00'

:DEFINE_STRING
	"DEFINE"

; Where our stack will start
:stack
