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

;; A Minimal C Compiler
;; type Cells are in the following form:
;; NEXT (0), SIZE (4), OFFSET (8), INDIRECT (12), MEMBERS (16), TYPE (20), NAME (24)
;; token_list Cells are in the following form:
;; NEXT (0), LOCALS/PREV (4), S (8), TYPE/FILENAME (12), ARGUMENTS/DEPTH/LINENUMBER (16)
;; Each being the length of a register [32bits]
;;

;; STACK space: End of program -> 1MB (0x100000)
;; HEAP space: 1MB -> End of Memory (2MB (0x200000))

;; R15 is the STACK pointer
;; R14 is the HEAP pointer

:start
	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE

	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

:main
	LOADUI R1 0x1100            ; Pass Tape_01 for reading
	LOADR32 R14 @HEAP           ; Setup Initial HEAP
	LOADUI R15 $STACK           ; Setup Initial STACK
	CALLI R15 @read_all_tokens  ; Read all Tokens in Tape_01
	CALLI R15 @reverse_list     ; Fix Token Order
	MOVE R13 R0                 ; Set global_token for future reading
	FALSE R12                   ; Set struct token_list* out to NULL
	FALSE R11                   ; Set struct token_list* list_strings to NULL
	FALSE R10                   ; Set struct token_list* globals_list to NULL
	CALLI R15 @program          ; Build our output
	LOADUI R0 $header_string1   ; Using our first header string
	LOADUI R1 0x1101            ; Using Tape_02
	CALLI R15 @file_print       ; Write string
	MOVE R0 R12                 ; using Contents of output_list
	CALLI R15 @recursive_output ; Recursively write
	LOADUI R0 $header_string2   ; Using our second header string
	CALLI R15 @file_print       ; Write string
	MOVE R0 R10                 ; using Contents of globals_list
	CALLI R15 @recursive_output ; Recursively write
	LOADUI R0 $header_string3   ; Using our third header string
	CALLI R15 @file_print       ; Write string
	MOVE R0 R11                 ; using Contents of strings_list
	CALLI R15 @recursive_output ; Recursively write
	LOADUI R0 $header_string4   ; Using our fourth header string
	CALLI R15 @file_print       ; Write string
	HALT                        ; We have completed compiling our input

;; Symbol lists
:global_constant_list
	NOP

:global_symbol_list
	NOP

;; Pointer to initial HEAP ADDRESS
:HEAP
	'00180000'

;; Output strings
:header_string1
	"
# Core program
"
:header_string2
	"
# Program global variables
"

:header_string3
	"
# Program strings
"

:header_string4
	"
:ELF_end
"


;; clearWhiteSpace function
;; Recieves a character in R0 and FILE* in R1 and line_num in R11
;; Returns first non-whitespace character in R0
:clearWhiteSpace
	CMPSKIPI.NE R0 32           ; Check for a Space
	JUMP @clearWhiteSpace_reset ; Looks like we need to remove a space

	CMPSKIPI.NE R0 9            ; Check for a tab
	JUMP @clearWhiteSpace_reset ; Looks like we need to remove a tab

	CMPSKIPI.E R0 10            ; Check for a newline
	RET R15                     ; Looks we found a non-whitespace

	ADDUI R11 R11 1             ; Increment line number
	;; Fall through to iterate to next char

:clearWhiteSpace_reset
	FGETC                       ; Get next char
	JUMP @clearWhiteSpace       ; Iterate


;; consume_byte function
;; Recieves a char in R0, FILE* in R1 and index in R13
;; Returns next char in R0
:consume_byte
	STOREX8 R0 R14 R13          ; Put char onto HEAP
	ADDUI R13 R13 1             ; Increment index
	FGETC                       ; Get next char
	RET R15


;; consume_word function
;; Recieves a char in R0, FILE* in R1, FREQUENT in R2 and index in R13
;; Returns next char in R0
:consume_word
	PUSHR R3 R15                ; Protect R3
	FALSE R3                    ; ESCAPE is FALSE
:consume_word_reset
	JUMP.NZ R3 @consume_word_iter1
	CMPSKIPI.NE R0 47           ; If \
	TRUE R3                     ; Looks like we are in an escape
	JUMP @consume_word_iter2
:consume_word_iter1
	FALSE R3                    ; Looks like we are no longer in an escape
:consume_word_iter2
	CALLI R15 @consume_byte     ; Store the char
	JUMP.NZ R3 @consume_word_reset        ; If escape loop
	CMPJUMPI.NE R0 R2 @consume_word_reset ; if not matching frequent loop
	FGETC                       ; Get a new char to return
	POPR R3 R15                 ; Restore R3
	RET R15


;; fixup_label function
;; Recieves nothing (But uses R14 as HEAP pointer)
;; Returns 32 in R0 and no other registers altered
:fixup_label
	PUSHR R1 R15                ; Protect R1 from change
	PUSHR R2 R15                ; Protect R2 from change
	LOADUI R0 58                ; Set HOLD to :
	FALSE R2                    ; Set I to 0
:fixup_label_reset
	MOVE R1 R0                  ; Set PREV = HOLD
	LOADXU8 R0 R14 R2           ; Read hold_string[I] into HOLD
	STOREX8 R1 R14 R2           ; Set hold_string[I] = PREV
	ADDUI R2 R2 1               ; increment I
	JUMP.NZ R0 @fixup_label_reset ; Loop until we hit a NULL

	;; clean up
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; in_set function
;; Recieves a Char in R0, FILE* in R1, char* in R2 and index in R13
;; Return result in R2
:in_set
	PUSHR R3 R15                ; Protect R3 from changes
:in_set_reset
	LOADU8 R3 R2 0              ; Get char from list
	CMPJUMPI.E R0 R3 @in_set_done ; We found a match
	ADDUI R2 R2 1               ; Increment to next char
	JUMP.NZ R3 @in_set_reset    ; Iterate if not NULL

	;; Looks like not found
	FALSE R2                    ; Return FALSE

:in_set_done
	CMPSKIPI.E R2 0             ; Provided not FALSE
	TRUE R2                     ; The result is true
	POPR R3 R15                 ; Restore R3
	RET R15

:keyword_chars
	"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

:symbol_chars
	"<=>|&!-"


;; preserve_keyword function
;; Recieves a Char in R0, FILE* in R1 and index in R13
;; Overwrites R2
;; Returns next CHAR
:preserve_keyword
	LOADUI R2 $keyword_chars    ; Using keyword list of chars
	CALLI R15 @in_set           ; Check if in list
	JUMP.Z R2 @preserve_keyword_label ; if not in set, stop iterating

:preserve_keyword_reset
	CALLI R15 @consume_byte     ; Consume another byte
	JUMP @preserve_keyword      ; Iterate

:preserve_keyword_label
	CMPSKIPI.NE R0 58           ; Check for label (:)
	CALLI R15 @fixup_label      ; Looks like we found one
	RET R15


;; preserve_symbol function
;; Recieves a Char in R0, FILE* in R1 and index in R13
;; Overwrites R2
;; Returns next CHAR
:preserve_symbol
	LOADUI R2 $symbol_chars     ; Using symbol list of chars
	CALLI R15 @in_set           ; Check if in list
	JUMP.NZ R2 @preserve_symbol_reset

	;; Looks we didn't find anything we wanted to preserve
	RET R15

:preserve_symbol_reset
	CALLI R15 @consume_byte     ; Consume another byte
	JUMP @preserve_symbol       ; Iterate


;; purge_macro function
;; Recieves a Char in R0, FILE* in R1 and index in R13
;; Returns next CHAR via jumping to get_token_reset
:purge_macro
	CMPSKIPI.NE R0 10           ; Check for Line Feed
	JUMP @get_token_reset       ; Looks like we found it, call it done

	FGETC                       ; Looks like we need another CHAR
	JUMP @purge_macro           ; Keep looping


;; get_token function
;; Recieves a Char in R0, FILE* in R1, line_num in R11 and TOKEN in R10
;; sets index in R13 and current in R12
;; Overwrites R2
;; Returns next CHAR
:get_token
	PUSHR R12 R15               ; Preserve R12
	PUSHR R13 R15               ; Preserve R13
	COPY R12 R14                ; Save CURRENT's Address
	ADDUI R14 R14 20            ; Update Malloc to free space for string
:get_token_reset
	FALSE R13                   ; Reset string_index to 0
	CALLI R15 @clearWhiteSpace  ; Clear any leading whitespace
	CMPSKIPI.NE R0 35           ; Deal with # line macros
	JUMP @purge_macro           ; Returns at get_token_reset

	;; Check for keywords
	LOADUI R2 $keyword_chars    ; Using keyword list
	CALLI R15 @in_set           ; Check if keyword
	JUMP.Z R2 @get_token_symbol ; if not a keyword
	CALLI R15 @preserve_keyword ; Yep its a keyword
	JUMP @get_token_done        ; Be done with token

	;; Check for symbols
:get_token_symbol
	LOADUI R2 $symbol_chars     ; Using symbol list
	CALLI R15 @in_set           ; Check if symbol
	JUMP.Z R2 @get_token_char   ; If not a symbol
	CALLI R15 @preserve_symbol  ; Yep its a symbol
	JUMP @get_token_done        ; Be done with token

	;; Check for char
:get_token_char
	CMPSKIPI.E R0 39            ; Check if '
	JUMP @get_token_string      ; Not a '
	COPY R2 R0                  ; Prepare for consume_word
	CALLI R15 @consume_word     ; Call it
	JUMP @get_token_done        ; Be done with token

	;; Check for string
:get_token_string
	CMPSKIPI.E R0 34            ; Check if "
	JUMP @get_token_EOF         ; Not a "
	COPY R2 R0                  ; Prepare for consume_word
	CALLI R15 @consume_word     ; Call it
	JUMP @get_token_done        ; Be done with token

	;; Check for EOF
:get_token_EOF
	CMPSKIPI.L R0 0             ; If c < 0
	JUMP @get_token_comment     ; If not EOF
	POPR R13 R15                ; Restore R13
	POPR R12 R15                ; Restore R12
	RET R15                     ; Otherwise just return the EOF

	;; Check for C comments
:get_token_comment
	CMPSKIPI.E R0 47            ; Deal with non-comments
	JUMP @get_token_else        ; immediately

	CALLI R15 @consume_byte     ; Deal with another byte
	CMPSKIPI.NE R0 42           ; if * make it a block comment
	JUMP @get_token_comment_block ; and purge it all

	CMPSKIPI.E R0 47            ; Check if not //
	JUMP @get_token_done        ; Finish off the token

	;; Looks like it was //
	FGETC                       ; Get next char
	JUMP @get_token_reset       ; Try again

	;; Deal with the mess that is C block comments
:get_token_comment_block
	FGETC                       ; Get next char
:get_token_comment_block_outer
	CMPSKIPI.NE R0 47           ; Check for closing /
	JUMP @get_token_comment_block_outer_done ; Yep has closing /
:get_token_comment_block_inner
	CMPSKIPI.NE R0 42           ; Check for preclosing *
	JUMP @get_token_comment_block_inner_done ; Yep has *

	;; Otherwise we are just consuming
	FGETC                       ; Remove another CHAR
	CMPSKIPI.NE R0 10           ; Check for Line Feed
	ADDUI R11 R11 1             ; Found one, updating line number
	JUMP @get_token_comment_block_inner

:get_token_comment_block_inner_done
	FGETC                       ; Remove another CHAR
	CMPSKIPI.NE R0 10           ; Check for Line Feed
	ADDUI R11 R11 1             ; Found one, updating line number
	JUMP @get_token_comment_block_outer

:get_token_comment_block_outer_done
	FGETC                       ; Remove another CHAR
	JUMP @get_token_reset       ; And Try again

	;; Deal with default case
:get_token_else
	CALLI R15 @consume_byte     ; Consume the byte and be done

:get_token_done
	ADDUI R13 R13 2             ; Pad with NULL the string
	STORE32 R14 R12 8           ; Set CURRENT->S to String
	ADD R14 R14 R13             ; Add string length to HEAP

	STORE32 R10 R12 0           ; CURRENT->NEXT = TOKEN
	STORE32 R10 R12 4           ; CURRENT->PREV = TOKE
	STORE32 R11 R12 16          ; CURRENT->LINENUM = LINE_NUM
	MOVE R10 R12                ; SET TOKEN to CURRENT
	POPR R13 R15                ; Restore R13
	POPR R12 R15                ; Restore R12
	RET R15


;; reverse_list function
;; Recieves a Token_list in R0
;; Returns List in Reverse order in R0
:reverse_list
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	FALSE R1                    ; Set ROOT to NULL
	CMPJUMPI.E R0 R1 @reverse_list_done ; ABORT if given a NULL
:reverse_list_reset
	LOAD32 R2 R0 0              ; SET next to HEAD->NEXT
	STORE32 R1 R0 0             ; SET HEAD->NEXT to ROOT
	MOVE R1 R0                  ; SET ROOT to HEAD
	MOVE R0 R2                  ; SET HEAD to NEXT
	JUMP.NZ R0 @reverse_list_reset ; Iterate if HEAD not NULL

:reverse_list_done
	MOVE R0 R1                  ; SET Result to ROOT
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; read_all_tokens function
;; Recieves a Char in R0, FILE* in R1
;; sets line_num in R11 and TOKEN in R10
;; Overwrites R2
;; Returns next CHAR
:read_all_tokens
	PUSHR R2 R15                ; Protect R2
	PUSHR R10 R15               ; Protect R10
	PUSHR R11 R15               ; Protect R11
	FGETC                       ; Read our first CHAR
	LOADUI R11 1                ; Start line_num at 1
	FALSE R10                   ; First token is NULL
:read_all_tokens_reset
	JUMP.NP R0 @read_all_tokens_done
	CALLI R15 @get_token
	JUMP @read_all_tokens_reset
:read_all_tokens_done
	MOVE R0 R10                 ; Return the Token
	POPR R11 R15                ; Restore R11
	POPR R10 R15                ; Restore R10
	POPR R2 R15                 ; Restore R2
	RET R15


;; file_print function
;; Recieves struct token_list* global_token in R13,
;;	struct token_list* out in R12,
;;	struct token_list* string_list in R11
;;	and struct token_list* global_list in R10
;; R13 Holds pointer to global_token, R14 is HEAP Pointer
;; Returns the token_list modified
:program
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
:program_iter
	JUMP.Z R13 @program_done    ; Looks like we read all the tokens
	LOADUI R0 $constant         ; Using the constant string
	LOAD32 R1 R13 8             ; GLOBAL_TOKEN->S
	CALLI R15 @match            ; Check if they match
	JUMP.Z R0 @program_type     ; Looks like not

	;; Deal with CONSTANT case
	LOADUI R3 $global_constant_list ; Where we store our global constant
	LOAD32 R2 R3 0              ; Get contents of global constants
	FALSE R1                    ; Set NULL
	LOAD32 R0 R13 0             ; GLOBAL_TOKEN->NEXT
	LOAD32 R0 R0 8              ; GLOBAL_TOKEN->NEXT->S
	CALLI R15 @sym_declare      ; Declare the global constant
	STORE32 R0 R3 0             ; Update global constant
	LOAD32 R2 R13 0             ; GLOBAL_TOKEN->NEXT
	LOAD32 R2 R2 0              ; GLOBAL_TOKEN->NEXT->NEXT
	STORE32 R0 R2 16            ; GLOBAL_CONSTANT_LIST->ARGUMENTS = GLOBAL_TOKEN->NEXT->NEXT
	LOAD32 R13 R2 0             ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT->NEXT->NEXT
	JUMP @program_iter          ; Loop again

:program_type
	CALLI R15 @type_name        ; Get the type
	JUMP.Z R0 @program_iter     ; If newly defined type iterate

	;; Looks like we got a defined type
	MOVE R1 R0                  ; Put the type where it can be used
	LOAD32 R0 R13 8             ; GLOBAL_TOKEN->S
	LOADUI R3 $global_symbol_list ; Get address of global symbol list
	LOAD32 R2 R3 0              ; GLOBAL_SYMBOLS_LIST
	CALLI R15 @sym_declare      ; Declare that global symbol
	STORE32 R0 R3 0             ; Update global symbol list
	LOAD32 R3 R13 8             ; GLOBAL_TOKEN->S
	LOAD32 R13 R13 0            ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT
	LOADUI R0 $semicolon        ; Get semicolon string
	LOAD32 R1 R13 8             ; GLOBAL_TOKEN->S
	CALLI R15 @match            ; Check if they match
	JUMP.Z R0 @program_function ; If not a match

	;; Deal with case of TYPE NAME;
	COPY R1 R10                 ; Using GLOBALS_LIST
	LOADUI R0 $program_string0  ; Using the GLOBAL_ prefix
	CALLI R15 @emit             ; emit it
	MOVE R1 R0                  ; Move new GLOBALS_LIST into Place
	MOVE R0 R3                  ; Use GLOBAL_TOKEN->PREV->S
	CALLI R15 @emit             ; emit it
	MOVE R1 R0                  ; Move new GLOBALS_LIST into Place
	LOADUI R0 $program_string1  ; Using the NOP postfix
	CALLI R15 @emit             ; emit it
	MOVE R10 R0                 ; Move new GLOBALS_LIST into Place
	LOAD32 R13 R13 0            ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT
	JUMP @program_iter

:program_function
	JUMP @program_iter

:program_done
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15

:program_string0
	":GLOBAL_"
:program_string1
	"
NOP
"


;; sym_declare function
;; Recieves char* in R0, struct type* in R1, struct token_list* in R2
;; R13 Holds pointer to global_token, R14 is HEAP Pointer
;; Returns struct token_list* in R0
:sym_declare
	PUSHR R3 R15                ; Protect R3
	COPY R3 R14                 ; Get A
	ADDUI R14 R14 20            ; CALLOC struct token_list
	STORE32 R2 R3 0             ; A->NEXT = LIST
	STORE32 R0 R3 8             ; A->S = S
	STORE32 R1 R3 12            ; A->TYPE = T
	MOVE R0 R3                  ; Prepare for Return
	POPR R3 R15                 ; Restore R3
	RET R15


;; emit function
;; Recieves char* in R0, struct token_list* in R1
;; R13 Holds pointer to global_token, R14 is HEAP Pointer
;; Returns struct token_list* in R0
:emit
	PUSHR R2 R15                ; Protect R2
	COPY R2 R14                 ; Pointer to T
	ADDUI R14 R14 20            ; CALLOC struct token_list
	STORE32 R1 R2 0             ; T->NEXT = HEAD
	STORE32 R0 R2 8             ; T->S = S
	MOVE R0 R2                  ; Put T in proper spot for return
	POPR R2 R15                 ; Restore R2
	RET R15

;; file_print function
;; Recieves pointer to string in R0 and FILE* in R1
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


;; recursive_output function
;; Recieves token_list in R0 and FILE* in R1
;; Returns nothing and alters nothing
:recursive_output
	JUMP.Z R0 @recursive_output_abort ; Abort if NULL
	PUSHR R2 R15                ; Preserve R2 from recursion
	MOVE R2 R0                  ; Preserve R0 from recursion
	LOAD32 R0 R2 0              ; Using I->NEXT
	CALLI R15 @recursive_output ; Recurse
	LOAD32 R0 R2 8              ; Using I->S
	CALLI R15 @file_print       ; Write the string
	MOVE R0 R2                  ; Put R0 back
	POPR R2 R15                 ; Restore R0
:recursive_output_abort
	RET R15


;; match function
;; Recieves a CHAR* in R0, CHAR* in R1
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
	CMPSKIP.E R1 R0             ; Compare the bytes
	FALSE R1                    ; Set FALSE
	JUMP.NZ R1 @match_cmpbyte   ; Loop if bytes are equal
;; Done
	CMPSKIPI.NE R0 0            ; If ended loop with everything matching
	TRUE R1                     ; Set as TRUE
	MOVE R0 R1                  ; Prepare for return
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; lookup_type function
;; Recieves a CHAR* in R0
;; Returns struct type* in R0 or NULL if no match
:lookup_type
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	LOADUI R2 $global_types     ; Get pointer to current global types
	LOAD32 R2 R2 0              ;I =  global_types
	MOVE R1 R0                  ; Put S in correct place
:lookup_type_iter
	LOAD32 R0 R2 24             ; Get I->NAME
	CALLI R15 @match            ; Check if I->NAME == S
	JUMP.NZ R0 @lookup_type_done ; If match found be done
	LOAD32 R2 R2 0              ; I = I->NEXT
	JUMP.NZ R2 @lookup_type_iter ; Otherwise iterate until I == NULL
:lookup_type_done
	MOVE R0 R2                  ; Our answer (I or NULL)
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15


;; build_member function
;; Recieves a struct type* in R0, int in R1 and int in R2
;; R13 Holds pointer to global_token, R14 is HEAP Pointer
;; Modifies R2 to current member_size
;; Returns struct type* in R0
:build_member
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	PUSHR R5 R15                ; Protect R5
	MOVE R4 R0                  ; Protect LAST
	CALLI R15 @type_name        ; Get MEMBER_TYPE
	COPY R3 R14                 ; SET I
	ADDUI R14 R14 28            ; CALLOC struct type
	LOAD32 R5 R13 8             ; GLOBAL_TOKEN->S
	STORE32 R5 R3 24            ; I->NAME = GLOBAL_TOKEN->S
	LOAD32 R13 R13 0            ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT
	STORE32 R4 R3 16            ; I->MEMBERS = LAST
	LOAD32 R2 R0 4              ; MEMBER_SIZE = MEMBER_TYPE->SIZE
	STORE32 R2 R3 4             ; I->SIZE = MEMBER_SIZE
	STORE32 R0 R3 20            ; I->TYPE = MEMBER_TYPE
	STORE32 R1 R3 8             ; I->OFFSET = OFFSET
	MOVE R0 R3                  ; RETURN I in R0
	POPR R5 R15                 ; Restore R5
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	RET R15


;; build_union function
;; Recieves a struct type* in R0, int in R1 and int in R2
;; R13 Holds pointer to global_token, R14 is HEAP Pointer
;; Modifies R2 to current member_size
;; Returns struct type* in R0
:build_union
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	PUSHR R5 R15                ; Protect R5
	MOVE R4 R0                  ; Protect LAST
	MOVE R3 R1                  ; Protect OFFSET
	FALSE R5                    ; SIZE = 0
	LOAD32 R13 R13 0            ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT
	LOADUI R0 $build_union_string0 ; ERROR MESSAGE
	LOADUI R1 $open_curly_brace ; OPEN CURLY BRACE
	CALLI R15 @require_match    ; Ensure we have that curly brace
:build_union_iter
	LOAD32 R0 R13 8             ; GLOBAL_TOKEN->S
	LOADU8 R0 R0 0              ; GLOBAL_TOKEN->S[0]
	LOADUI R1 125               ; numerical value of }
	CMPJUMPI.E R0 R1 @build_union_done ; No more looping required
	MOVE R0 R4                  ; We are passing last to be overwritten
	MOVE R1 R3                  ; We are also passing OFFSET
	CALLI R15 @build_member     ; To build_member to get new LAST and new member_size
	CMPSKIP.LE R2 R5            ; If MEMBER_SIZE > SIZE
	COPY R5 R2                  ; SIZE = MEMMER_SIZE
	MOVE R4 R0                  ; Protect LAST
	MOVE R3 R1                  ; Protect OFFSET
	LOADUI R0 $build_union_string1 ; ERROR MESSAGE
	LOADUI R1 $semicolon        ; SEMICOLON
	CALLI R15 @require_match    ; Ensure we have that curly brace
	JUMP @build_union_iter      ; Loop until we get that closing curly brace
:build_union_done
	MOVE R2 R5                  ; Setting MEMBER_SIZE = SIZE
	LOAD32 R13 R13 0            ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT
	MOVE R1 R3                  ; Restore OFFSET
	MOVE R0 R4                  ; Restore LAST as we are turning that
	POPR R5 R15                 ; Restore R5
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	RET R15

:build_union_string0
"ERROR in build_union
Missing {
"
:build_union_string1
"ERROR in build_union
Missing ;
"


;; create_struct function
;; Recieves Nothing
;; R13 Holds pointer to global_token, R14 is HEAP Pointer
;; Returns Nothing
:create_struct
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	PUSHR R2 R15                ; Protect R2
	PUSHR R3 R15                ; Protect R3
	PUSHR R4 R15                ; Protect R4
	PUSHR R5 R15                ; Protect R5
	PUSHR R6 R15                ; Protect R6
	FALSE R5                    ; OFFSET = 0
	FALSE R2                    ; MEMBER_SIZE = 0
	COPY R3 R14                 ; SET HEAD
	ADDUI R14 R14 28            ; CALLOC struct type
	COPY R4 R14                 ; SET I
	ADDUI R14 R14 28            ; CALLOC struct type
	LOAD32 R0 R13 8             ; GLOBAL_TOKEN->S
	STORE32 R0 R3 24            ; HEAD->NAME = GLOBAL_TOKEN->S
	STORE32 R0 R4 24            ; I->NAME = GLOBAL_TOKEN->S
	STORE32 R4 R3 12            ; HEAD->INDIRECT = I
	STORE32 R3 R4 12            ; I->INDIRECT - HEAD
	LOADUI R0 $global_types     ; Get Address of GLOBAL_TYPES
	LOAD32 R0 R0 0              ; Current pointer to GLOBAL_TYPES
	STORE R0 R3 0               ; HEAD->NEXT = GLOBAL_TYPES
	LOADUI R0 $global_types     ; Get Address of GLOBAL_TYPES
	STORE R3 R0 0               ; GLOBAL_TYPES = HEAD
	LOAD32 R13 R13 0            ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT
	LOADUI R0 4                 ; Standard Pointer SIZE
	STORE32 R0 R4 4             ; I->SIZE = 4
	LOADUI R0 $create_struct_string0 ; ERROR MESSAGE
	LOADUI R1 $open_curly_brace ; OPEN CURLY BRACE
	CALLI R15 @require_match    ; Ensure we have that curly brace
	FALSE R6                    ; LAST = NULL
:create_struct_iter
	LOAD32 R0 R13 8             ; GLOBAL_TOKEN->S
	LOADU8 R0 R0 0              ; GLOBAL_TOKEN->S[0]
	LOADUI R1 125               ; Numerical value of }
	CMPJUMPI.E R0 R1 @create_struct_done ; Stop looping if match
	LOADUI R1 $union            ; Pointer to string UNION
	LOAD32 R0 R13 8             ; GLOBAL_TOKEN->S
	CALLI R15 @match            ; Check if they Match
	SWAP R0 R6                  ; Put LAST in place
	MOVE R1 R5                  ; Put OFFSET in place
	JUMP.NZ R6 @create_struct_union ; Deal with union case

	;; Deal with standard member case
	CALLI R15 @build_member     ; Sets new LAST and MEMBER_SIZE
	JUMP @create_struct_iter2   ; reset for loop

:create_struct_union
	CALLI R15 @build_union

:create_struct_iter2
	ADD R5 R1 R2                ; OFFSET = OFFSET + MEMBER_SIZE
	SWAP R0 R6                  ; Put LAST in place
	LOADUI R0 $create_struct_string1 ; ERROR MESSAGE
	LOADUI R1 $semicolon        ; SEMICOLON
	CALLI R15 @require_match    ; Ensure we have that semicolon
	JUMP @create_struct_iter    ; Keep Looping

:create_struct_done
	LOAD32 R13 R13 0            ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT
	LOADUI R0 $create_struct_string1 ; ERROR MESSAGE
	LOADUI R1 $semicolon        ; SEMICOLON
	CALLI R15 @require_match    ; Ensure we have that semicolon
	STORE32 R5 R3 4             ; HEAD->SIZE = OFFSET
	STORE32 R6 R3 16            ; HEAD->MEMBERS = LAST
	STORE32 R6 R4 16            ; I->MEMBERS = LAST
	POPR R6 R15                 ; Restore R6
	POPR R5 R15                 ; Restore R5
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15

:create_struct_string0
"ERROR in create_struct
Missing {
"
:create_struct_string1
"ERROR in create_struct
Missing ;
"


;; type_name function
;; Recieves Nothing
;; R13 Holds pointer to global_token, R14 is HEAP Pointer
;; Returns struct type* in R0
:type_name
	PUSHR R1 R15                ; Protect R1
	LOADUI R0 $struct           ; String for struct for comparison
	LOAD32 R1 R13 8             ; GLOBAL_TOKEN->S
	CALLI R15 @match            ; Check if they match
	CMPSKIPI.E R0 0             ; If STRUCTURE
	LOAD32 R13 R13 0            ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT
	LOAD32 R1 R13 8             ; GLOBAL_TOKEN->S
	SWAP R0 R1                  ; Put GLOBAL_TOKEN->S in the right place
	CALLI R15 @lookup_type      ; RET = lookup_type(GLOBAL_TOKEN->S)
	CMPSKIP.E R0 R1             ; If RET == NULL and !STRUCTURE
	JUMP @type_name_struct      ; Guess not

	;; Exit with useful error message
	FALSE R1                    ; We will want to be writing the error message for the Human
	LOADUI R0 $type_name_string0 ; The first string
	CALLI R15 @file_print       ; Display it
	LOAD32 R1 R13 8             ; GLOBAL_TOKEN->S
	CALLI R15 @file_print       ; Display it
	LOADUI R0 $newline          ; Terminating linefeed
	CALLI R15 @file_print       ; Display it
	CALLI R15 @line_error       ; Give useful debug info
	HALT                        ; Just exit

:type_name_struct
	JUMP.NZ R0 @type_name_iter  ; If was found
	CALLI R15 @create_struct    ; Otherwise create it
	JUMP @type_name_done        ; and be done

:type_name_iter
	LOAD32 R13 R13 0            ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT
	LOAD32 R1 R13 8             ; GLOBAL_TOKEN->S
	LOADU8 R1 R1 0              ; GLOBAL_TOKEN->S[0]
	CMPSKIPI.E R1 42            ; if GLOBAL_TOKEN->S[0] == '*'
	JUMP @type_name_done        ; Looks like Nope
	LOAD32 R0 R0 12             ; RET = RET->INDIRECT
	JUMP @type_name_iter        ; Keep looping

:type_name_done
	POPR R1 R15                 ; Restore R1
	RET R15

:type_name_string0
"Unknown type "


;; line_error function
;; Recieves Nothing
;; R13 Holds pointer to global_token, R14 is HEAP Pointer
;; Returns nothing
:line_error
	PUSHR R0 R15                ; Protect R0
	PUSHR R1 R15                ; Protect R1
	LOADUI R0 $line_error_string0 ; Our leading string
	FALSE R1                    ; We want the user to see
	CALLI R15 @file_print       ; Print it
	LOAD32 R0 R13 16            ; GLOBAL_TOKEN->LINENUMBER
	CALLI R15 @numerate_number  ; Get a string pointer for number
	CALLI R15 @file_print       ; And print it
	POPR R1 R15                 ; Restore R1
	POPR R0 R15                 ; Restore R0
	RET R15

:line_error_string0
	"In file: TTY1 On line: "

;; require_match function
;; Recieves char* in R0 and char* in R1
;; R13 Holds pointer to global_token, R14 is HEAP Pointer
;; Returns Nothing
:require_match
	PUSHR R0 R15                ; Protect R0
	PUSHR R2 R15                ; Protect R2
	MOVE R2 R0                  ; Get MESSAGE out of the way
	LOAD32 R0 R13 8             ; GLOBAL_TOKEN->S
	CALLI R15 @match            ; Check if GLOBAL_TOKEN->S == REQUIRED
	JUMP.NZ R0 @require_match_done ; Looks like it was a match

	;; Terminate with an error
	MOVE R0 R2                  ; Put MESSAGE in required spot
	FALSE R1                    ; We want to write for user
	CALLI R15 @file_print       ; Write it
	CALLI R15 @line_error       ; And provide some debug info
	HALT                        ; Then Stop immediately

:require_match_done
	LOAD32 R13 R13 0            ; GLOBAL_TOKEN = GLOBAL_TOKEN->NEXT
	POPR R2 R15                 ; Restore R2
	POPR R0 R15                 ; Restore R0
	RET R15


;; numerate_number function
;; Recieves int in R0
;; R13 Holds pointer to global_token, R14 is HEAP Pointer
;; Returns pointer to string generated
:numerate_number
	PUSHR R1 R15                ; Preserve R1
	PUSHR R2 R15                ; Preserve R2
	PUSHR R3 R15                ; Preserve R3
	PUSHR R4 R15                ; Preserve R4
	PUSHR R5 R15                ; Preserve R5
	PUSHR R6 R15                ; Preserve R6
	MOVE R3 R0                  ; Move Integer out of the way
	COPY R1 R14                 ; Get pointer result
	ADDUI R14 R14 16            ; CALLOC the 16 chars of space
	FALSE R6                    ; Set index to 0

	JUMP.Z R3 @numerate_number_ZERO ; Deal with Special case of ZERO
	JUMP.P R3 @numerate_number_Positive
	LOADUI R0 45                ; Using -
	STOREX8 R0 R1 R6            ; write leading -
	ADDUI R6 R6 1               ; Increment by 1
	NOT R3 R3                   ; Flip into positive
	ADDUI R3 R3 1               ; Adjust twos

:numerate_number_Positive
	LOADR R2 @Max_Decimal       ; Starting from the Top
	LOADUI R5 10                ; We move down by 10
	FALSE R4                    ; Flag leading Zeros

:numerate_number_0
	DIVIDE R0 R3 R3 R2          ; Break off top 10
	CMPSKIPI.E R0 0             ; If Not Zero
	TRUE R4                     ; Flip the Flag

	JUMP.Z R4 @numerate_number_1 ; Skip leading Zeros
	ADDUI R0 R0 48              ; Shift into ASCII
	STOREX8 R0 R1 R6            ; write digit
	ADDUI R6 R6 1               ; Increment by 1

:numerate_number_1
	DIV R2 R2 R5                ; Look at next 10
	CMPSKIPI.E R2 0             ; If we reached the bottom STOP
	JUMP @numerate_number_0     ; Otherwise keep looping

:numerate_number_done
	LOADUI R0 10                ; Using LINEFEED
	STOREX8 R0 R1 R6            ; write
	MOVE R0 R1                  ; Return pointer to our string
	;; Cleanup
	POPR R6 R15                 ; Restore R6
	POPR R5 R15                 ; Restore R5
	POPR R4 R15                 ; Restore R4
	POPR R3 R15                 ; Restore R3
	POPR R2 R15                 ; Restore R2
	POPR R1 R15                 ; Restore R1
	RET R15

:numerate_number_ZERO
	LOADUI R0 48                ; Using Zero
	STOREX8 R0 R1 R6            ; write
	ADDUI R6 R6 1               ; Increment by 1
	JUMP @numerate_number_done  ; Be done

:Max_Decimal
	'3B9ACA00'


;; Keywords
:union
	"union"
:struct
	"struct"
:constant
	"CONSTANT"

;; Frequently Used strings
;; Generally used by require_match
:open_curly_brace
	"{"
:close_curly_brace
	"}"
:open_paren
	"("
:close_paren
	")"
:semicolon
	";"
:newline
	"
"

;; Global types
;; NEXT (0), SIZE (4), OFFSET (8), INDIRECT (12), MEMBERS (16), TYPE (20), NAME (24)
:global_types
	&type_void

:type_void
	&type_int                   ; NEXT
	'00 00 00 04'               ; SIZE
	NOP                         ; OFFSET
	&type_void                  ; INDIRECT
	NOP                         ; MEMBERS
	&type_void                  ; TYPE
	&type_void_name             ; NAME
:type_void_name
	"void"

:type_int
	&type_char                  ; NEXT
	'00 00 00 04'               ; SIZE
	NOP                         ; OFFSET
	&type_int                   ; INDIRECT
	NOP                         ; MEMBERS
	&type_int                   ; TYPE
	&type_int_name              ; NAME
:type_int_name
	"int"

:type_char
	&type_file                  ; NEXT
	'00 00 00 01'               ; SIZE
	NOP                         ; OFFSET
	&type_char_indirect         ; INDIRECT
	NOP                         ; MEMBERS
	&type_char                  ; TYPE
	&type_char_name             ; NAME
:type_char_name
	"char"

:type_char_indirect
	&type_file                  ; NEXT
	'00 00 00 04'               ; SIZE
	NOP                         ; OFFSET
	&type_char_double_indirect  ; INDIRECT
	NOP                         ; MEMBERS
	&type_char_indirect         ; TYPE
	&type_char_indirect_name    ; NAME
:type_char_indirect_name
	"char*"

:type_char_double_indirect
	&type_file                  ; NEXT
	'00 00 00 04'               ; SIZE
	NOP                         ; OFFSET
	&type_char_double_indirect  ; INDIRECT
	NOP                         ; MEMBERS
	&type_char_indirect         ; TYPE
	&type_char_double_indirect_name ; NAME
:type_char_double_indirect_name
	"char**"

:type_file
	&type_function              ; NEXT
	'00 00 00 04'               ; SIZE
	NOP                         ; OFFSET
	&type_file                  ; INDIRECT
	NOP                         ; MEMBERS
	&type_file                  ; TYPE
	&type_file_name             ; NAME
:type_file_name
	"FILE"

:type_function
	&type_unsigned              ; NEXT
	'00 00 00 04'               ; SIZE
	NOP                         ; OFFSET
	&type_function              ; INDIRECT
	NOP                         ; MEMBERS
	&type_function              ; TYPE
	&type_function_name         ; NAME
:type_function_name
	"FUNCTION"

:type_unsigned
	NOP                         ; NEXT (NULL)
	'00 00 00 04'               ; SIZE
	NOP                         ; OFFSET
	&type_unsigned              ; INDIRECT
	NOP                         ; MEMBERS
	&type_unsigned              ; TYPE
	&type_unsigned_name         ; NAME
:type_unsigned_name
	"unsigned"

:STACK
