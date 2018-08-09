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
;	STORER32 R0 @global_token   ; Set global_token for future reading
;	FALSE R0                    ; Pass NULL to program
;	CALLI R15 @program          ; Build our output
	LOADUI R0 $header_string1   ; Using our first header string
	LOADUI R1 0x1101            ; Using Tape_02
	CALLI R15 @file_print       ; Write string
;	LOADUI R0 $output_list      ; using Contents of output_list
;	CALLI R15 @recursive_output ; Recursively write
	LOADUI R0 $header_string2   ; Using our second header string
	CALLI R15 @file_print       ; Write string
;	LOADUI R0 $globals_list     ; using Contents of globals_list
;	CALLI R15 @recursive_output ; Recursively write
	LOADUI R0 $header_string3   ; Using our third header string
	CALLI R15 @file_print       ; Write string
;	LOADUI R0 $strings_list     ; using Contents of strings_list
;	CALLI R15 @recursive_output ; Recursively write
	LOADUI R0 $header_string4   ; Using our fourth header string
	CALLI R15 @file_print       ; Write string
	HALT                        ; We have completed compiling our input

;; Pointer to initial HEAP ADDRESS
:HEAP
	'00180000'

;; Pointer to our list of tokens collected in the input
:global_token
	NOP

;; Pointer to our list of assembly tokens generated
:output_list
	NOP

;; Pointer to our list of globals
:globals_list
	NOP

;; Pointer to our list of string tokens generated
:strings_list
	NOP

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
	JUMP @get_token_comment     ; Not a "
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

:program
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
;;  Recieves token_list in R0 and FILE* in R1
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

:STACK
