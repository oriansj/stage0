;; Copyright (C) 2017 Jeremiah Orians
;; This file is part of stage0.
;;
;; stage0 is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; stage0 is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with stage0.  If not, see <http://www.gnu.org/licenses/>.

	section .text
	global _start

	;; Register usage:
	;; EAX => Temps

	;; Struct TYPE format: (size 28)
	;; NEXT => 0
	;; SIZE => 4
	;; OFFSET => 8
	;; INDIRECT => 12
	;; MEMBERS => 16
	;; TYPE => 20
	;; NAME => 24

	;; Struct TOKEN_LIST format: (size 20)
	;; NEXT => 0
	;; LOCALS/PREV => 4
	;; S => 8
	;; TYPE => 12
	;; ARGS/DEPTH => 16

; Where the ELF Header is going to hit
; Simply jump to _start
; Our main function
_start:
	pop eax                     ;·Get·the·number·of·arguments
	pop ebx                     ;·Get·the·program·name
	pop ebx                     ;·Get·the·actual·input name
	mov ecx, 0                  ;·prepare·read_only
	mov eax, 5                  ;·the·syscall·number·for·open()
	int 0x80                    ; Now open that damn file
	mov [Input_file], eax       ; Preserve the file pointer we were given

	pop ebx                     ;·Get·the·actual·output name
	mov ecx, 577                ; Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov edx, 384                ; Prepare file as RW for owner only (600 in octal)
	mov eax, 5                  ;·the·syscall·number·for·open()
	int 0x80                    ; Now open that damn file
	cmp eax, 0                  ; Check for missing output
	jg _start_out               ; Have real input
	mov eax, 1                  ; Use stdout

_start_out:
	mov [Output_file], eax      ; Preserve the file pointer we were given

	mov eax, 45                 ; the Syscall # for SYS_BRK
	mov ebx, 0                  ; Get current brk
	int 0x80                    ; Let the kernel do the work
	mov [MALLOC], eax           ; Set our malloc pointer
	mov eax, 0                  ; HEAD = NULL
	call read_all_tokens        ; Read all tokens
	call Reverse_List           ; Reverse order
;	call debug_list             ; Try to figure out what is wrong
	mov [global_token], eax     ; Set global_token
	call program                ; Convert into program
	mov eax, header_string1     ; Our header string
	call File_Print             ; Print it
	mov eax, [output_list]      ; Our output_list
	call recursive_output       ; Print core program
	mov eax, header_string2     ; Our second label
	call File_Print             ; Print it
	mov eax, [globals_list]     ; Our globals
	call recursive_output       ; Get them
	mov eax, header_string3     ; Our final header
	call File_Print             ; Print it
	mov eax, [strings_list]     ; Our strings
	call recursive_output       ; Get them

Done:
	; program completed Successfully
	mov ebx, 0                  ; All is well
	mov eax, 1                  ; put the exit syscall number in eax
	int 0x80                    ; Call it a good day

header_string1: db 10, "# Core program", 10, 0
header_string2: db 10, ":ELF_data", 10, 10, "# Program global variables", 10, 0
header_string3: db 10, "# Program strings", 10, 0

;; read_all_tokens function
;; Recieves Token_List* in EAX
;; Tokenizes all input and returns updated list in EAX
;; Returns TOKEN in EAX
;; Uses EAX for C
read_all_tokens:
	mov [Token], eax
	call fgetc
read_all_tokens_loop:
	cmp eax, -4                 ; Check for EOF
	je read_all_tokens_done     ; Stop if found
	call get_token              ; Read all tokens
	jmp read_all_tokens_loop    ; Loop
read_all_tokens_done:
	mov eax, [Token]
	ret


;; get_token function
;; Recieves INT in EAX
;; Makes a list of TOKEN_LIST
;; C and STRING_INDEX are stored in memory, ECX is used for S and EDX is used for current
;; Returns C in EAX
get_token:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX

	mov [C], eax                ; Set C

	mov eax, 20                 ; Malloc CURRENT
	call malloc                 ; Get Pointer
	mov edx, eax                ; Set CURRENT

	mov eax, 256                ; Malloc the string
	call malloc                 ; Get pointer to S
	mov ecx, eax                ; Set S
	mov [edx+8], ecx            ; CURRENT->S = S
reset:
	mov [string_index], ecx     ; S[0]
	mov eax, [C]                ; Using C

	call clear_white_space      ; Clear WhiteSpace
	mov [C], eax                ; Set C

	cmp eax, -4                 ; Check for EOF
	je get_token_abort          ; if EOF abort

	cmp eax, 35                 ; Check for '#'
	jne get_token_alpha         ; Nope

	;; Deal with # line comments
	call purge_macro            ; Let it handle it
	mov [C], eax                ; Set C
	jmp reset                   ; Try again

get_token_alpha:
	mov eax, [C]                ; Send C
	mov ebx, alphas             ; Get alphanumerics
	call In_Set                 ; See if in set
	cmp eax, 1                  ; IF TRUE
	jne get_token_symbol        ; Otherwise

	;; Store keywords
	mov eax, [C]                ; Send C
	call preserve_keyword       ; Store
	mov [C], eax                ; Set C
	jmp get_token_done          ; Be done with this token

get_token_symbol:
	mov eax, [C]                ; Send C
	mov ebx, symbols            ; Get symbols
	call In_Set                 ; See if in set
	cmp eax, 1                  ; IF TRUE
	jne get_token_strings       ; Otherwise

	;; Store symbols
	mov eax, [C]                ; Send C
	call preserve_symbol        ; Store
	mov [C], eax                ; Set C
	jmp get_token_done          ; Be done with this token

get_token_strings:
	mov eax, [C]                ; Send C
	mov ebx, strings            ; Get symbols
	call In_Set                 ; See if in set
	cmp eax, 1                  ; IF TRUE
	jne get_token_comment       ; Otherwise

	;; Store String
	mov eax, [C]                ; Send C
	call consume_word           ; Store
	mov [C], eax                ; Set C
	jmp get_token_done          ; Be done with this token

get_token_comment:
	mov eax, [C]                ; Send C
	cmp eax, 47                 ; IF '/' == C
	jne get_token_else          ; Otherwise

	call consume_byte           ; Hope it just is '/'
	mov [C], eax                ; Set C

	cmp eax, 42                 ; IF '*' we have '/*'
	jne get_token_comment_line  ; Check for '//'

	;; Deal with /* block comments */
	call fgetc                  ; get next C
	mov [C], eax                ; Set C
get_token_comment_block_outer:
	mov eax, [C]                ; Using C
	cmp eax, 47                 ; IF '/' != C
	je get_token_comment_block_done ; be done

get_token_comment_block_inner:
	mov eax, [C]                ; Using C
	cmp eax, 42                 ; IF '*' != C
	je get_token_comment_block_iter ; jump over

	;; Deal with inner loop
	call fgetc                  ; get next C
	mov [C], eax                ; Set C
	jmp get_token_comment_block_inner ; keep going

get_token_comment_block_iter:
	call fgetc                  ; get next C
	mov [C], eax                ; Set C
	jmp get_token_comment_block_outer

get_token_comment_block_done:
	call fgetc                  ; get next C
	mov [C], eax                ; Set C
	jmp reset                   ; throw away, try again

get_token_comment_line:
	cmp eax, 47                 ; IF '/' we have //
	jne get_token_done          ; keep if just '/'

	;; Deal with // line comment
	call fgetc                  ; drop to match
	mov [C], eax                ; Set C
	jmp reset                   ; throw away, try again

get_token_else:
	mov eax, [C]                ; Send C
	call consume_byte
	mov [C], eax                ; Set C

get_token_done:
	mov eax, [Token]            ; TOKEN
	mov [edx+4], eax            ; CURRENT->PREV = TOKEN
	mov [edx], eax              ; CURRENT->NEXT = TOKEN
	mov [Token], edx            ; TOKEN = CURRENT

get_token_abort:
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	mov eax, [C]                ; Return C
	ret


;; Malloc isn't actually required if the program being built fits in the initial memory
;; However, it doesn't take much to add it.
;; Requires [MALLOC] to be initialized and EAX to have the number of desired bytes
malloc:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov ebx, [MALLOC]           ; Using the current pointer
	add ebx, eax                ; Request the number of desired bytes
	mov eax, 45                 ; the Syscall # for SYS_BRK
	int 0x80                    ; call the Kernel
	mov eax, [MALLOC]           ; Return pointer
	mov [MALLOC], ebx           ; Update pointer
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; clear_white_space function
;; Recieves INT C in EAX
;; Returns first non-whitespace char in EAX
clear_white_space:
	cmp eax, 32                 ; Check for ' '
	je clear_white_space_wipe   ; wipe it out

	cmp eax, 10                 ; Check for '\n'
	je clear_white_space_wipe   ; wipe it output

	cmp eax, 9                  ; Check for '\t'
	jne clear_white_space_done  ; looks like non-whitespace

clear_white_space_wipe:
	call fgetc                  ; Read a new byte
	cmp eax, -4                 ; Check for EOF
	je clear_white_space_done   ; Short circuit
	jmp clear_white_space       ; iterate

clear_white_space_done:
	ret


;; In_Set function
;; Recieves Char C in EAX and CHAR* in EBX
;; Returns 1 if true, zero if false in EAX
In_Set:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
In_Set_loop:
	mov cl, [ebx]               ; Read char
	movzx ecx, cl               ; Zero extend it

	cmp eax, ecx                ; See if they match
	je In_Set_True              ; return true

	cmp ecx, 0                  ; Check for NULL
	je In_Set_False             ; return false

	add ebx, 1                  ; s = s + 1
	jmp In_Set_loop             ; Keep looping

In_Set_True:
	mov eax, 1                  ; Set True
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

In_Set_False:
	mov eax, 0                  ; Set FALSE
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

alphas: db "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", 0
symbols: db "<=>|&!-", 0
strings: db 34, 39, 0


;; purge_macro function
;; Recieves CH in EAX
;; Reads chars until Line feed is read
;; returns line feed
purge_macro:
	call fgetc                  ; read next char
	cmp eax, 10                 ; Check for '\n'
	jne purge_macro             ; Keep going
	ret


;; preserve_keyword function
;; Recieves INT C in EAX
;; collects all chars in keyword
;; Returns C in EAX
;; Uses ECX for INT C
preserve_keyword:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ecx, eax                ; Setup C
	mov ebx, alphas             ; Concerning ourselves with "abc.."
preserve_keyword_loop:
	call In_Set                 ; Check if alphanumerics
	cmp eax, 1                  ; IF TRUE
	jne preserve_keyword_label  ; Otherwise check for label

	mov eax, ecx                ; Pass C
	call consume_byte           ; consume that byte
	mov ecx, eax                ; Update C
	jmp preserve_keyword_loop   ; keep looping

preserve_keyword_label:
	mov eax, ecx                ; Fix return
	cmp eax, 58                 ; Check for ':'
	jne preserve_keyword_done   ; be done

	;; Fix our goto label
	call fixup_label            ; Fix the label
	mov eax, 32                 ; Return Whitespace

preserve_keyword_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; preserve_symbol function
;; Recieves INT C in EAX
;; collects all chars in symbol
;; Returns C in EAX
;; Uses ECX for INT C
preserve_symbol:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ecx, eax                ; Setup C
	mov ebx, symbols            ; Concerning ourselves with "<=>.."
preserve_symbol_loop:
	call In_Set                 ; Check if alphanumerics
	cmp eax, 1                  ; IF TRUE
	jne preserve_symbol_done    ; Otherwise be done

	mov eax, ecx                ; Pass C
	call consume_byte           ; consume that byte
	mov ecx, eax                ; Update C
	jmp preserve_symbol_loop    ; keep looping

preserve_symbol_done:
	mov eax, ecx                ; Fix return
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; consume_word function
;; recieves INT C in EAX
;; returns INT C in EAX
;; Uses EAX for C, EBX for FREQ and ECX for ESCAPE
consume_word:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ebx, eax                ; FREQ = C
	mov ecx, 0                  ; ESCAPE = FALSE
consume_word_loop:
	cmp ecx, 0                  ; IF !ESCAPE
	jne consume_word_escape     ; Enable escape

	cmp eax, 92                 ; if '\\'
	jne consume_word_iter       ; keep state

	mov ecx, 1                  ; ESCAPE = TRUE
	jmp consume_word_iter       ; keep going

consume_word_escape:
	mov ecx, 0                  ; ESCAPE = FALSE

consume_word_iter:
	call consume_byte           ; read next char

	cmp ecx, 0                  ; IF ESCAPE
	jne consume_word_loop       ; keep looping

	cmp eax, ebx                ; IF C != FREQ
	jne consume_word_loop       ; keep going

	call fgetc                  ; return next char
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; consume_byte function
;; Recieves INT C in EAX
;; Inserts C into string S, updates String S
;; Returns Next char in EAX
consume_byte:
	push ebx                    ; Protect EBX
	mov ebx, [string_index]     ; S[0]
	mov [ebx], al               ; S[0] = C
	add ebx, 1                  ; S = S + 1
	mov [string_index], ebx     ; Update S
	call fgetc
	pop ebx                     ; Restore EBX
	ret


;; fixup_label function
;; Recieves S in ECX
;; prepends ':' to string and returns registers un changed
;; Uses EAX for HOLD, EBX for PREV and ECX for S[0]
fixup_label:
	push eax                    ; Protect EAX
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, 58                 ; HOLD = ':'
	mov ecx, [edx+8]            ; HOLD_STRING[0]
fixup_label_loop:
	mov ebx, eax                ; PREV = HOLD
	mov al, [ecx]               ; HOLD = HOLD_STRING[I]
	movzx eax, al               ; make useful
	mov [ecx], bl               ; HOLD_STRING[I] = PREV
	add ecx, 1                  ; I = I + 1
	cmp eax, 0                  ; IF NULL == HOLD
	jne fixup_label_loop        ; Keep looping

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	pop eax                     ; Restore EAX
	ret


;; fgetc function
;; Loads FILE* from [INPUT_FILE]
;; Returns -4 (EOF) or char in EAX
fgetc:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov eax, -4                 ; Put EOF in eax
	push eax                    ; Assume bad (If nothing read, value will remain EOF)
	lea ecx, [esp]              ; Get stack address
	mov ebx, [Input_file]       ; Where are we reading from
	mov eax, 3                  ; the syscall number for read
	mov edx, 1                  ; set the size of chars we want
	int 0x80                    ; call the Kernel
	pop eax                     ; Get either char or EOF
	cmp eax, -4                 ; Check for EOF
	je fgetc_done               ; Return as is
	movzx eax, al               ; Make it useful
fgetc_done:
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; Reverse_List function
;; Recieves List in EAX
;; Returns the list reversed in EAX
Reverse_List:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ebx, eax                ; Set HEAD
	mov eax, 0                  ; ROOT = NULL
Reverse_List_Loop:
	cmp ebx, 0                  ; WHILE HEAD != NULL
	je Reverse_List_Done        ; Stop otherwise

	mov ecx, [ebx]              ; NEXT = HEAD->NEXT
	mov [ebx], eax              ; HEAD->NEXT = ROOT
	mov eax, ebx                ; ROOT = HEAD
	mov ebx, ecx                ; HEAD = NEXT
	jmp Reverse_List_Loop       ; Keep Going

Reverse_List_Done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; recursive_output function
;; Recieves list in EAX
;; walks the list and prints the I->S for all nodes backwards
;; Uses EBX for I
recursive_output:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	cmp eax, 0                  ; Check for NULL
	je recursive_output_done    ; Skip the work
	mov ebx, eax                ; I = Head

	mov eax, [ebx]              ; Iterate to next Token
	call recursive_output       ; Recurse

	mov eax, [ebx+8]            ; Using S
	call File_Print             ; Print it

recursive_output_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; File_Print function
;; Recieves CHAR* in EAX
;; calls fputc for every non-null char
File_Print:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ebx, eax                ; Protect S
	cmp eax, 0                  ; Protect against nulls
	je File_Print_Done          ; Simply don't try to print them
File_Print_Loop:
	mov al, [ebx]               ; Read byte
	movzx eax, al               ; zero extend
	cmp eax, 0                  ; Check for NULL
	je File_Print_Done          ; Stop at NULL

	call fputc                  ; write it
	add ebx, 1                  ; S = S + 1
	jmp File_Print_Loop         ; Keep going

File_Print_Done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; fputc function
;; recieves CHAR in EAX and load FILE* from [OUTPUT_FILE]
;; writes char and returns
fputc:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	push eax                    ; We are writing eax
	lea ecx, [esp]              ; Get stack address
	mov ebx, [Output_file]      ; Write to target file
	mov eax, 4                  ; the syscall number for write
	mov edx, 1                  ; set the size of chars we want
	int 0x80                    ; call the Kernel
	pop eax                     ; Restore stack
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; program function
;; recieves nothing, returns nothing
;; Uses EAX for type_size
program:
	;; The binary initialized the globals to null, so we can skip those steps
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX

new_type:
	mov eax, [global_token]     ; Using global_token
	cmp eax, 0                  ; Check if NULL
	je program_done             ; Be done if null

	mov ebx, [eax+8]            ; GLOBAL_TOKEN->S
	mov eax, constant           ; "CONSTANT"
	call match                  ; IF GLOBAL_TOKEN->S == "CONSTANT"
	cmp eax, 0                  ; If true
	jne program_else            ; Looks like not a constant

	;; Deal with minimal constant case
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next

	mov eax, [eax+8]            ; global_token->S
	mov ebx, 0                  ; NULL
	mov ecx, [global_constant_list] ; global_constant_list
	call sym_declare            ; Declare that constant
	mov [global_constant_list], eax ; global_constant_list = sym_declare(global_token->s, NULL, global_constant_list);

	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx]              ; global_token->next
	mov [eax+16], ebx           ; global_constant_list->arguments = global_token->next

	mov ebx, [ebx]              ; global_token->next->next
	mov [global_token], ebx     ; global_token = global_token->next->next;
	jmp new_type                ; go around again

program_else:
	call type_name              ; Figure out the type_size
	cmp eax, 0                  ; IF NULL == type_size
	je new_type                 ; it was a new type

	;; Add to global symbol table
	mov ebx, eax                ; put type_size in the right spot
	mov eax, [global_token]     ; Using global token
	mov eax, [eax+8]            ; global_token->S
	mov ecx, [global_symbol_list] ; Using global_symbol_list
	call sym_declare            ; Declare symbol
	mov [global_symbol_list], eax ; global_symbol_list = sym_declare(global_token->s, type_size, global_symbol_list);
	mov ebx, [global_token]     ; Using global token
	mov ebx, [ebx]              ; global_token->next
	mov [global_token], ebx     ; global_token = global_token->next

	mov ebx, [global_token]     ; Using global token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, semicolon          ; ";"
	call match                  ; if(match(";", global_token->s))
	cmp eax, 0                  ; If true
	jne program_function        ; looks like not a match

	;; Deal with the global variable
	mov ebx, [globals_list]     ; Using globals_list
	mov eax, program_string_0   ; ":GLOBAL_"
	call emit                   ; Emit it
	mov ebx, eax                ; update globals_list

	mov eax, [global_token]     ; Using global token
	mov eax, [eax+4]            ; global token->prev
	mov eax, [eax+8]            ; global token->prev->s
	call emit                   ; Emit it

	mov ebx, eax                ; update globals_list
	mov eax, program_string_1   ; "\nNOP\n"
	call emit                   ; Emit it
	mov [globals_list], eax     ; update globals_list

	mov eax, [global_token]     ; Using global token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next
	jmp new_type                ; go around again

program_function:
	mov ebx, [global_token]     ; Using global token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, open_paren         ; "("
	call match                  ; if(match(";", global_token->s))
	cmp eax, 0                  ; If true
	jne program_error           ; Otherwise deal with error case

	;; Deal with function definition
	call declare_function       ; Lets get the parsing rolling
	jmp new_type                ; Keep looping through functions

program_error:
	;; Deal with the case of something we don't support

program_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

;; Strings needed by the program function
program_string_0: db ":GLOBAL_", 0
program_string_1: db 10, "NOP", 10, 0


;; declare_function function
;; Recieves nothing and returns nothing
;; Sets current function and adds it to the global function list
declare_function:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, 0                  ; Using NULL
	mov [current_count], eax    ; current_count = 0

	mov eax, [global_token]     ; Using global token
	mov eax, [eax+4]            ; global token->prev
	mov eax, [eax+8]            ; global token->prev->s
	mov ebx, 0                  ; NULL
	mov ecx, [global_function_list] ; global_function_list
	call sym_declare            ; sym_declare(global_token->prev->s, NULL, global_function_list);
	mov [function], eax         ; function = sym_declare(global_token->prev->s, NULL, global_function_list);
	mov [global_function_list], eax ; global_function_list = function

	call collect_arguments      ; collect all of the function arguments

	mov eax, [global_token]     ; Using global token
	mov eax, [eax+8]            ; global token->s
	mov ebx, semicolon          ; ";"
	call match                  ; IF global token->s == ";"
	cmp eax, 0                  ; If true
	jne declare_function_full   ; It was a prototype

	;; Deal with prototypes
	mov eax, [global_token]     ; Using global token
	mov eax, [eax]              ; global token->next
	mov [global_token], eax     ; global token = global token->next
	jmp declare_function_done   ; Move on

declare_function_full:
	;; Deal will full function definitions
	mov eax, declare_function_string_0 ; "# Defining function "
	call emit_out               ; emit it

	mov eax, [function]         ; function
	mov eax, [eax+8]            ; function->s
	call emit_out               ; emit it

	mov eax, declare_function_string_1 ; "\n:FUNCTION_"
	call emit_out               ; emit it

	mov eax, [function]         ; function
	mov eax, [eax+8]            ; function->s
	call emit_out               ; emit it

	mov eax, declare_function_string_3 ; "\n"
	call emit_out               ; emit it

	call statement              ; Recursively get the function pieces

	mov eax, [output_list]      ; output
	mov eax, [eax+8]            ; output->s
	mov ebx, declare_function_string_2 ; "RETURN\n"
	call match                  ; IF output->s == "RETURN\n"
	cmp eax, 0                  ; If true we can skip adding it
	je declare_function_done    ; otherwise we need to add it

	;; Add the return to the end of a function lacking a return;
	mov eax, declare_function_string_2 ; "RETURN\n"
	call emit_out               ; emit it

declare_function_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

declare_function_string_0: db 35, " Defining function ", 0
declare_function_string_1: db 10, ":FUNCTION_", 0
declare_function_string_2: db "RETURN", 10, 0
declare_function_string_3: db 10, 0


;; collect_arguments function
;; Recieves nothing
;; Returns Nothing
;; Adds arguments to the function definition
;; holds struct type* type_size in ECX, then replace with struct token_list* a in ECX when type_size is used
collect_arguments:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next
collect_arguments_loop:
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, close_paren        ; ")"
	call match                  ; IF global_token->S == ")"
	cmp eax, 0                  ; we reached the end
	je collect_arguments_done   ; be done

	;; deal with the case of there are arguments
	call type_name              ; Get the type
	mov ecx, eax                ; put type_size safely out of the way

	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, close_paren        ; ")"
	call match                  ; IF global_token->S == ")"
	cmp eax, 0                  ; is a foo(int, char,void) case
	je collect_arguments_common ; deal with commas

	;; Trying second else
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, comma              ; ","
	call match                  ; IF global_token->S == ","
	cmp eax, 0                  ; then deal with the common
	je collect_arguments_common ; case of commas between arguments

	;; deal with foo(int a, char b)
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov ebx, ecx                ; put type_size in the right place
	mov ecx, [function]         ; Using function
	mov ecx, [ecx+16]           ; function->args
	call sym_declare            ; sym_declare(global_token->s, type_size, function->arguments);
	mov ecx, eax                ; put a in a safe place

	mov eax, [function]         ; Using function
	mov eax, [eax+16]           ; function->args
	cmp eax, 0                  ; IF function->args == NULL
	jne collect_arguments_another ; otherwise it isn't the first

	;; Deal with the case of first argument in the function
	mov eax, -4                 ; -4
	mov [ecx+16], eax           ; a->depth = -4
	jmp collect_arguments_next  ; get to next

collect_arguments_another:
	;; deal with the case of non-first arguments
	mov eax, [function]         ; Using function
	mov eax, [eax+16]           ; function->args
	mov eax, [eax+16]           ; function->args->depth
	sub eax, 4                  ; function->args->depth - 4
	mov [ecx+16], eax           ; a->depth = function->args->depth - 4

collect_arguments_next:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next

	mov eax, [function]         ; Using function
	mov [eax+16], ecx           ; function->args = a

collect_arguments_common:
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, comma              ; ","
	call match                  ; IF global_token->S == ","
	cmp eax, 0                  ; then deal with the comma
	jne collect_arguments_loop  ; otherwise loop

	;; keep foo(bar(), 1) expressions working
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next
	jmp collect_arguments_loop  ; keep going

collect_arguments_done:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; statement function
;; Recieves nothing
;; Returns nothing
;; Walks down global_token recursively to collect the contents of the function
statement:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX

	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, open_curly_brace   ; "{"
	call match                  ; IF global_token->S == "{"
	jne statement_label         ; otherwise try label

	;; deal with { statement }
	call recursive_statement    ; Statements inside of statements for days
	jmp statement_done          ; Be done

statement_label:
	mov al, [ebx]               ; global_token->S[0]
	movzx eax, al               ; make it useful
	cmp eax, 58                 ; IF global_token->S == ':'
	jne statement_local         ; otherwise try locals

	;; deal with labels
	mov eax, ebx                ; put global_token->S in the right spot
	call emit_out               ; emit it

	mov eax, statement_string_0 ; Using "\t#C goto label\n"
	call emit_out               ; emit it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next
	jmp statement_done          ; be done

statement_local:
	mov eax, ebx                ; put global_token->S in the right place
	mov ebx, prim_types         ; pointer to primative types
	call lookup_type            ; See if found
	cmp eax, 0                  ; IF NULL == lookup_type(global_token->S, prim_types)
	jne statement_local_success ; Sweet a new local

	;; Second chance
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, struct             ; "struct"
	call match                  ; IF global_token->S == "struct"
	cmp eax, 0                  ; then we are a local
	jne statement_if            ; otherwise try IF

statement_local_success:
	call collect_local          ; Grab those locals
	jmp statement_done          ; be done

statement_if:
	mov eax, if_string          ; Using "if"
	call match                  ; IF global_token->S == "if"
	cmp eax, 0                  ; then we have an if statement
	jne statement_do            ; otherwise try DO

	;; Deal with IF statement
	call process_if             ; DO IT
	jmp statement_done          ; be done

statement_do:
	mov eax, do_string          ; Using "do
	call match                  ; IF global_token->S == "do"
	cmp eax, 0                  ; then we have a do statement
	jne statement_while         ; otherwise try WHILE

	;; Deal with DO statement
	call process_do             ; DO IT
	jmp statement_done          ; be done

statement_while:
	mov eax, while_string       ; Using "while"
	call match                  ; IF global_token->S == "while"
	cmp eax, 0                  ; then we have a while statement
	jne statement_for           ; otherwise try FOR

	;; Deal with WHILE statement
	call process_while          ; DO IT
	jmp statement_done          ; be done

statement_for:
	mov eax, for_string         ; Using "for"
	call match                  ; IF global_token->S == "for"
	cmp eax, 0                  ; then we have a for statement
	jne statement_asm           ; otherwise try ASM

	;; Deal with FOR statement
	call process_for            ; DO IT
	jmp statement_done          ; be done

statement_asm:
	mov eax, asm_string         ; Using "asm"
	call match                  ; IF global_token->S == "asm"
	cmp eax, 0                  ; then we have an asm statement
	jne statement_goto          ; otherwise try GOTO

	;; Deal with ASM statement
	call process_asm            ; Hit it
	jmp statement_done          ; be done

statement_goto:
	mov eax, goto_string        ; Using "goto"
	call match                  ; IF global_token->S == "goto"
	cmp eax, 0                  ; then we have a goto statement
	jne statement_return        ; Otherwise try RETURN

	;; Deal with GOTO statement
	mov eax, statement_string_1 ; Using "JUMP %"
	call emit_out               ; emit it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next

	mov eax, [eax+8]            ; global_token->S
	call emit_out               ; emit it

	mov eax, statement_string_2 ; Using "\n"
	call emit_out               ; emit it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next

	mov eax, statement_string_4 ; Using "ERROR in statement\nMissing ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure it has the required
	jmp statement_done          ; Be done

statement_return:
	mov eax, return_string      ; Using "return"
	call match                  ; IF global_token->S == "return"
	cmp eax, 0                  ; then we have a return statement
	jne statement_break         ; Otherwise try BREAK

	;; Deal with RETURN Statement
	call return_result          ; Return anything they want
	jmp statement_done          ; be done

statement_break:
	mov eax, break_string       ; Using "break"
	call match                  ; IF global_token->S == "break"
	cmp eax, 0                  ; then we have a break statement
	jne statement_continue      ; Otherwise try CONTINUE

	;; Deal with BREAK statement
	call process_break          ; Lets do some damage
	jmp statement_done          ; be done

statement_continue:
	mov eax, continue_string    ; Using "continue"
	call match                  ; IF global_token->S == "continue"
	cmp eax, 0                  ; then we have a continue statement
	jne statement_else          ; Otherwise we are punting to an expression

	;; Deal with CONTINUE statement
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next

	mov eax, statement_string_3 ; Using "\n#continue statement\n"
	call emit_out               ; emit it

	mov eax, statement_string_4 ; Using "ERROR in statement\nMissing ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Don't forget the ";"
	jmp statement_done          ; Be done

statement_else:
	call expression             ; Collect expression
	mov eax, statement_string_4 ; Using "ERROR in statement\nMissing ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; make sure we have it

statement_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

statement_string_0: db 9, "#C goto label", 10, 0
statement_string_1: db "JUMP %", 0
statement_string_2: db 10, 0
statement_string_3: db 10, "#continue statement", 10, 0
statement_string_4: db "ERROR in statement", 10, "Missing ;", 10, 0


;; recursive_statement function
;; Recieves nothing
;; Returns nothing
;; Walks the global_token list to build the contents of statements
;; Uses struct token_list* frame in ECX
recursive_statement:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next

	mov ecx, [function]         ; Using function
	mov ecx, [ecx+4]            ; frame = function->locals

recursive_statement_loop:
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, close_curly_brace  ; Using "}"
	call match                  ; IF global_token->S == "}"
	cmp eax, 0                  ; Then we are done recuring
	je recursive_statement_cleanup ; and then we clean up

	;; Deal with the recursive calls
	call statement              ; Deal with another statement
	jmp recursive_statement_loop ; loop some more

recursive_statement_cleanup:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next

	mov eax, recursive_statement_string_0 ; Using "RETURN\n"
	mov ebx, [output_list]      ; Using output
	mov ebx, [ebx+8]            ; output->S
	call match                  ; IF output->S == "RETURN\n"
	cmp eax, 0                  ; Then we can skip the clean up
	je recursive_statement_done ; and be done

	;; Deal with cleanup
	mov ebx, [function]         ; Using function
	mov ebx, [ebx+4]            ; i = function->locals
	mov eax, recursive_statement_string_1 ; Using "POP_ebx\t# _recursive_statement_locals\n"

recursive_statement_locals:
	cmp ebx, ecx                ; IF frame != i
	je recursive_statement_done ; Otherwise be done

	;; Lets emit
	call emit_out               ; emit it
	mov ebx, [ebx]              ; i = i->next
	jmp recursive_statement_locals ; keep going

recursive_statement_done:
	mov eax, [function]         ; Using function
	mov [eax+4], ecx            ; function->locals = frame
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

recursive_statement_string_0: db "RETURN", 10, 0
recursive_statement_string_1: db "POP_ebx", 9, "# _recursive_statement_locals", 10, 0


;; return_result function
;; Recieves nothing
;; Returns nothing
;; Cleans up function and generates return
;; Also handles returing expressions
return_result:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next

	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; make it useful
	cmp eax, 59                 ; If global_token->S[0] == ';'
	je return_result_cleanup    ; Go straight to cleanup

	call expression             ; get the expression we are returning

return_result_cleanup:
	mov eax, return_result_string_0 ; Using "ERROR in return_result\nMISSING ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it

	mov ebx, [function]         ; Using function
	mov ebx, [ebx+4]            ; function->locals
	mov eax, return_result_string_1 ; Using "POP_ebx\t# _return_result_locals\n"
return_result_locals:
	cmp ebx, 0                  ; IF NULL == i
	je return_result_done       ; Be done

	call emit_out               ; Emit out pop
	mov ebx, [ebx]              ; i = i->NEXT
	jmp return_result_locals    ; Keep going

return_result_done:
	mov eax, return_result_string_2 ; Using "RETURN\n"
	call emit_out               ; Emit it
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

return_result_string_0: db "ERROR in return_result", 10, "MISSING ;", 10, 0
return_result_string_1: db "POP_ebx", 9, "# _return_result_locals", 10, 0
return_result_string_2: db "RETURN", 10, 0


;; collect_local function
;; Recieves nothing
;; Returns nothing
;; Walks global_token list to create function locals
;; Uses ECX for struct token_list* A
collect_local:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	call type_name              ; Get the local's type

	mov ebx, eax                ; Put struct type* type_size in the right place
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov ecx, [function]         ; Using function
	mov ecx, [ecx+4]            ; function->locals
	call sym_declare            ; Declare it
	mov ecx, eax                ; put it away safely

	;; Try for main
	mov eax, main_string        ; Using "main"
	mov ebx, [function]         ; Using function
	mov ebx, [ebx+8]            ; function->S
	call match                  ; IF match("main", function->s)
	cmp eax, 0                  ; possible
	jne collect_local_fresh     ; try to see if fresh function

	;; Ok we are in main, now to see if main is fresh
	mov eax, [function]         ; Using function
	mov eax, [eax+4]            ; function->locals
	cmp eax, 0                  ; IF NULL == function->locals
	jne collect_local_fresh     ; try to see if fresh function

	;; Sweet we are in a fresh main
	mov eax, -20                ; We start at -20
	mov [ecx+16], eax           ; a->DEPTH = -20
	jmp collect_local_common    ; Go to the commons

collect_local_fresh:
	mov eax, [function]         ; Using function
	mov eax, [eax+16]           ; function->args
	cmp eax, 0                  ; IF NULL == function->locals
	jne collect_local_first     ; Otherwise see if first

	mov eax, [function]         ; Using function
	mov eax, [eax+4]            ; function->locals
	cmp eax, 0                  ; IF NULL == function->locals
	jne collect_local_first     ; Otherwise try first

	;; Sweet we are in a fresh function
	mov eax, -8                 ; We start at -8
	mov [ecx+16], eax           ; a->DEPTH = -8
	jmp collect_local_common    ; Go to the commons

collect_local_first:
	mov eax, [function]         ; Using function
	mov eax, [eax+4]            ; function->locals
	cmp eax, 0                  ; IF NULL == function->locals
	jne collect_local_else      ; Looks like we are just another local

	;; Ok we are the first local
	mov eax, [function]         ; Using function
	mov eax, [eax+16]           ; function->args
	mov eax, [eax+16]           ; function->args->depth
	sub eax, 8                  ; function->arguments->depth - 8
	mov [ecx+16], eax           ; a->DEPTH = function->arguments->depth - 8
	jmp collect_local_common    ; Go to the commons

collect_local_else:
	;; Always the last to know
	mov eax, [function]         ; Using function
	mov eax, [eax+4]            ; function->locals
	mov eax, [eax+16]           ; function->locals->depth
	sub eax, 4                  ; function->locals->depth - 4
	mov [ecx+16], eax           ; a->DEPTH = function->locals->depth - 4

collect_local_common:
	mov eax, [function]         ; Using function

	mov [eax+4], ecx            ; function->locals = a
	mov ecx, [ecx+8]            ; a->S

	mov eax, collect_local_string_0 ; Using "# Defining local "
	call emit_out               ; emit it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	call emit_out               ; emit it

	mov eax, collect_local_string_1 ; Using "\n"
	call emit_out               ; emit it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov ebx, [eax+8]            ; global_token->S
	mov eax, equal              ; Using "="
	call match                  ; IF match("=", global_token->s)
	cmp eax, 0                  ; Deal with assignment
	jne collect_local_done      ; Otherwise finish it

	;; Deal with assignment
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	call expression             ; Recurse

collect_local_done:
	mov eax, collect_local_string_2 ; Using "ERROR in collect_local\nMissing ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it

	mov eax, collect_local_string_3 ; Using "PUSH_eax\t#"
	call emit_out               ; emit it

	mov eax, ecx                ; put A->S where it belongs
	call emit_out               ; emit it

	mov eax, collect_local_string_1 ; Using "\n"
	call emit_out               ; emit it

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

collect_local_string_0: db "# Defining local ", 0
collect_local_string_1: db 10, 0
collect_local_string_2: db "ERROR in collect_local", 10, "Missing ;", 10, 0
collect_local_string_3: db "PUSH_eax", 9, "#", 0


;; process_asm function
;; Recieves nothing
;; Returns nothing
;; Simply inlines the asm statements
;; Uses EBX for global_token temp storage
process_asm:
	push ebx                    ; Protect EBX
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, process_asm_string_0 ; Using "ERROR in process_asm\nMISSING (\n"
	mov ebx, open_paren         ; Using "("
	call require_match          ; Make sure we have it

	mov ebx, [global_token]     ; Using global_token
process_asm_iter:
	mov eax, [ebx+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	cmp eax, 34                 ; IF global_token->S[0] == '"'
	jne process_asm_done        ; Otherwise be done

	mov eax, [ebx+8]            ; global_token->S
	add eax, 1                  ; global_token->S + 1
	call emit_out               ; Emit it

	mov eax, process_asm_string_1 ; Using "\n"
	call emit_out               ; Emit it

	mov ebx, [ebx]              ; global_token->NEXT
	mov [global_token], ebx     ; global_token = global_token->NEXT
	jmp process_asm_iter        ; keep going

process_asm_done:
	mov eax, process_asm_string_2 ; Using "ERROR in process_asm\nMISSING )\n"
	mov ebx, close_paren        ; Using ")"
	call require_match          ; Make sure we have it

	mov eax, process_asm_string_3 ; Using "ERROR in process_asm\nMISSING ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it

	pop ebx                     ; Restore EBX
	ret

process_asm_string_0: db "ERROR in process_asm", 10, "MISSING (", 10, 0
process_asm_string_1: db 10, 0
process_asm_string_2: db "ERROR in process_asm", 10, "MISSING )", 10, 0
process_asm_string_3: db "ERROR in process_asm", 10, "MISSING ;", 10, 0


;; process_if function
;; Recieves nothing
;; Returns Nothing
;; Increments current_count recurses into expression + statement
;; Uses ECX for char* NUMBER_STRING
process_if:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, [current_count]    ; Using current count
	mov ebx, eax                ; Preparing for update
	add ebx, 1                  ; current_count + 1
	mov [current_count], ebx    ; current_count = current_count + 1
	call numerate_number        ; convert to string
	mov ecx, eax                ; put NUMBER_STRING in place

	mov eax, process_if_string_0 ; Using "# IF_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, process_if_string_1 ; Using "ERROR in process_if\nMISSING (\n"
	mov ebx, open_paren         ; Using "("
	call require_match          ; Make sure we have it

	call expression             ; Recurse to get the IF(...) part

	mov eax, process_if_string_2 ; Using "TEST\nJUMP_EQ %ELSE_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_if_string_3 ; Using "ERROR in process_if\nMISSING )\n"
	mov ebx, close_paren        ; Using ")"
	call require_match          ; Make sure we have it

	call statement              ; Recursive to get the IF(){...} part

	mov eax, process_if_string_4 ; Using "JUMP %_END_IF_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_if_string_5 ; Using ":ELSE_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, else_string        ; Using "else"
	call match                  ; IF global_token->S == "else"
	cmp eax, 0                  ; Then we need to collect the else too
	jne process_if_done         ; Otherwise finish up

	;; deal with else statement
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	call statement              ; Recurse to get the ELSE {...} part

process_if_done:
	mov eax, process_if_string_6 ; Using ":_END_IF_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

process_if_string_0: db "# IF_",0
process_if_string_1: db "ERROR in process_if", 10, "MISSING (", 10, 0
process_if_string_2: db "TEST", 10, "JUMP_EQ %ELSE_", 0
process_if_string_3: db "ERROR in process_if", 10, "MISSING )", 10, 0
process_if_string_4: db "JUMP %_END_IF_", 0
process_if_string_5: db ":ELSE_", 0
process_if_string_6: db ":_END_IF_", 0


;; save_break_frame microfunction
;; Overwrites EAX abd EBX
;; Saves break frame on stack
;; Returns to caller
save_break_frame:
	pop ebx                     ; Save return Address
	mov eax, [break_frame]      ; Get break_frame
	push eax                    ; Store as nested_locals
	mov eax, [break_target_head] ; Get break_target_head
	push eax                    ; Store as nested_break_head
	mov eax, [break_target_func] ; Get break_target_func
	push eax                    ; Store as nested_break_func
	mov eax, [break_target_num] ; Get break_target_num
	push eax                    ; Store as nested_break_num
	push ebx                    ; Put return back in place
	ret                         ; Return to caller


;; restore_break_frame microfunction
;; Overwrites EAX and EBX
;; Restores break frame from stack
;; Returns to caller
restore_break_frame:
	pop ebx                     ; Save return Address
	pop eax                     ; Get nested_break_num
	mov [break_target_num], eax ; Restore break_target_num
	pop eax                     ; Get nested_break_func
	mov [break_target_func], eax ; Restore break_target_func
	pop eax                     ; Get nested_break_head
	mov [break_target_head], eax ; Restore break_target_head
	pop eax                     ; Get nested_locals
	mov [break_frame], eax      ; Restore break_frame
	push ebx                    ; Put return back in place
	ret                         ; Return to caller


;; set_break_frame microfunction
;; Recieves char* head in EAX and char* num in EBX
;; Overwrites EAX and EBX
;; Returns to calling function
set_break_frame:
	mov [break_target_head], eax ; update break_target_head
	mov [break_target_num], ebx ; update break_target_num
	mov ebx, [function]         ; Using function
	mov eax, [ebx+4]            ; function->LOCALS
	mov [break_frame], eax      ; break_frame = function->LOCALS
	mov eax, [ebx+8]            ; function->S
	mov [break_target_func], eax ; break_target_func = function->S
	ret                         ; Return to sender


;; process_do function
;; Recieves Nothing
;; Returns Nothing
;; Increments current_count and leverages save/restore_break_frame pieces
;; Uses ECX for char* NUMBER_STRING
process_do:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	call save_break_frame       ; Save the frame

	mov eax, [current_count]    ; Using current count
	mov ebx, eax                ; Preparing for update
	add ebx, 1                  ; current_count + 1
	mov [current_count], ebx    ; current_count = current_count + 1
	call numerate_number        ; convert to string
	mov ecx, eax                ; put NUMBER_STRING in place

	mov eax, process_do_string_0 ; Using "DO_END_"
	mov ebx, ecx                ; Passing NUMBER_STRING
	call set_break_frame        ; Set the frame

	mov eax, process_do_string_1 ; Using ":DO_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	call statement              ; Do the DO {...} part

	mov eax, process_do_string_2 ; Using "ERROR in process_do\nMISSING while\n"
	mov ebx, while_string       ; Using "while"
	call require_match          ; Make sure we have it

	mov eax, process_do_string_3 ; Using "ERROR in process_do\nMISSING (\n"
	mov ebx, open_paren         ; Using "("
	call require_match          ; Make sure we have it

	call expression             ; Do the WHILE (...) part

	mov eax, process_do_string_4 ; Using "ERROR in process_do\nMISSING )\n"
	mov ebx, close_paren        ; Using ")"
	call require_match          ; Make sure we have it

	mov eax, process_do_string_5 ; Using "ERROR in process_do\nMISSING ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it

	mov eax, process_do_string_6 ; Using "TEST\nJUMP_NE %DO_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_do_string_7 ; Using ":DO_END_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	call restore_break_frame    ; Restore the old break frame

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

process_do_string_0: db "DO_END_", 0
process_do_string_1: db ":DO_", 0
process_do_string_2: db "ERROR in process_do", 10, "MISSING while", 10, 0
process_do_string_3: db "ERROR in process_do", 10, "MISSING (", 10, 0
process_do_string_4: db "ERROR in process_do", 10, "MISSING )", 10, 0
process_do_string_5: db "ERROR in process_do", 10, "MISSING ;", 10, 0
process_do_string_6: db "TEST", 10, "JUMP_NE %DO_", 0
process_do_string_7: db ":DO_END_", 0


;; process_while function
;; Recieves nothing
;; Returns nothing
;; Increments current_count and leverages save/restore_break_frame pieces
;; Uses ECX for char* NUMBER_STRING
process_while:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	call save_break_frame       ; Save break_frame

	mov eax, [current_count]    ; Using current count
	mov ebx, eax                ; Preparing for update
	add ebx, 1                  ; current_count + 1
	mov [current_count], ebx    ; current_count = current_count + 1
	call numerate_number        ; convert to string
	mov ecx, eax                ; put NUMBER_STRING in place

	mov eax, process_while_string_0 ; Using "END_WHILE_"
	mov ebx, ecx                ; Passing NUMBER_STRING
	call set_break_frame        ; Set it and forget it

	mov eax, process_while_string_1 ; Using ":WHILE_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, process_while_string_2 ; Using "ERROR in process_while\nMISSING (\n"
	mov ebx, open_paren         ; Using "("
	call require_match          ; Make sure we have it

	call expression             ; Deal with the WHILE (...) part

	mov eax, process_while_string_3 ; Using "TEST\nJUMP_EQ %END_WHILE_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_while_string_4 ; Using "# THEN_while_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_while_string_5 ; Using "ERROR in process_while\nMISSING )\n"
	mov ebx, close_paren        ; Using ")"
	call require_match          ; Make sure we have it

	call statement              ; Deal with the {....} part

	mov eax, process_while_string_6 ; Using "JUMP %WHILE_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_while_string_7 ; Using ":END_WHILE_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	call restore_break_frame    ; Restore the old break frame

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

process_while_string_0: db "END_WHILE_", 0
process_while_string_1: db ":WHILE_", 0
process_while_string_2: db "ERROR in process_while", 10, "MISSING (", 10, 0
process_while_string_3: db "TEST", 10, "JUMP_EQ %END_WHILE_", 0
process_while_string_4: db "# THEN_while_", 0
process_while_string_5: db "ERROR in process_while", 10, "MISSING )", 10, 0
process_while_string_6: db "JUMP %WHILE_", 0
process_while_string_7: db ":END_WHILE_", 0


;; process_for function
;; Recieves Nothing
;; Returns Nothing
;; Increments current_count and leverages save/restore_break_frame pieces
;; Uses ECX for char* NUMBER_STRING
process_for:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	call save_break_frame       ; Save the frame

	mov eax, [current_count]    ; Using current count
	mov ebx, eax                ; Preparing for update
	add ebx, 1                  ; current_count + 1
	mov [current_count], ebx    ; current_count = current_count + 1
	call numerate_number        ; convert to string
	mov ecx, eax                ; put NUMBER_STRING in place

	mov eax, process_for_string_0 ; Using "FOR_END_"
	mov ebx, ecx                ; Passing NUMBER_STRING
	call set_break_frame        ; Set it and forget it

	mov eax, process_for_string_1 ; Using "# FOR_initialization_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, process_for_string_2 ; Using "ERROR in process_for\nMISSING (\n"
	mov ebx, open_paren         ; Using "("
	call require_match          ; Make Sure we have it

	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, semicolon          ; Using ";"
	call match                  ; IF global_token->S == ";"
	cmp eax, 0                  ; Then no initializer
	je process_for_terminator   ; And skip getting the expression

	;; Deal with FOR (...; case
	call expression             ; Get the FOR ( ... ; part

process_for_terminator:
	mov eax, process_for_string_3 ; Using ":FOR_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_for_string_4 ; Using "ERROR in process_for\nMISSING ;1\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it

	call expression             ; Get the FOR ( ; ... ; Part

	mov eax, process_for_string_5 ; Using "TEST\nJUMP_EQ %FOR_END_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_for_string_6 ; Using "JUMP %FOR_THEN_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_for_string_7 ; Using ":FOR_ITER_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_for_string_8 ; Using "ERROR in process_for\nMISSING ;2\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it

	call expression             ; Get the FOR (;;...) part

	mov eax, process_for_string_9 ; Using "JUMP %FOR_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_for_string_10 ; Using ":FOR_THEN_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_for_string_11 ; Using "ERROR in process_for\nMISSING )\n"
	mov ebx, close_paren        ; Using ")"
	call require_match          ; Make sure we have it

	call statement              ; Get FOR (;;) {...} part

	mov eax, process_for_string_12 ; Using "JUMP %FOR_ITER_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Passing NUMBER_STRING
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	mov eax, process_for_string_13 ; Using ":FOR_END_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	call uniqueID_out           ; uniqueID_out(function->s, number_string)

	call restore_break_frame    ; Restore the old break frame

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

process_for_string_0: db "FOR_END_", 0
process_for_string_1: db "# FOR_initialization_", 0
process_for_string_2: db "ERROR in process_for", 10, "MISSING (", 10, 0
process_for_string_3: db ":FOR_", 0
process_for_string_4: db "ERROR in process_for", 10, "MISSING ;1", 10, 0
process_for_string_5: db "TEST", 10, "JUMP_EQ %FOR_END_", 0
process_for_string_6: db "JUMP %FOR_THEN_", 0
process_for_string_7: db ":FOR_ITER_", 0
process_for_string_8: db "ERROR in process_for", 10, "MISSING ;2", 10, 0
process_for_string_9: db "JUMP %FOR_", 0
process_for_string_10: db ":FOR_THEN_", 0
process_for_string_11: db "ERROR in process_for",10, "MISSING )", 10, 0
process_for_string_12: db "JUMP %FOR_ITER_", 0
process_for_string_13: db ":FOR_END_", 0


;; process_break function
;; Recieves nothing
;; Returns nothing
;; Handles the break out of loops case
;; Uses EBX for struct token_list* break_frame and ECX for struct token_list* I
process_break:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, [break_target_head] ; Catch big error
	cmp eax, 0                  ; IF(NULL == break_target_head)
	je process_break_bad        ; I'm sorry Mr White but you have stage-3 lung cancer

	mov eax, [function]         ; Using function
	mov ecx, [eax+4]            ; I = function->LOCALS
	mov ebx, [break_frame]      ; Put break_frame in the right spot
	mov eax, process_break_string_1 ; Using "POP_ebx\t# break_cleanup_locals\n"

process_break_iter:
	cmp ecx, 0                  ; IF (NULL == I)
	je process_break_cleaned    ; We are done

	cmp ecx, ebx                ; IF I != break_frame
	je process_break_cleaned    ; We are done

	call emit_out               ; Emit it
	mov ecx, [ecx]              ; I = I->NEXT
	jmp process_break_iter      ; Keep looping

process_break_cleaned:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, process_break_string_2 ; Using "JUMP %"
	call emit_out               ; Emit it

	mov eax, [break_target_head] ; Get what we are in
	call emit_out               ; Emit it

	mov eax, [break_target_func] ; Get what function we are in
	call emit_out               ; Emit it

	mov eax, underline          ; Using "_"
	call emit_out               ; Emit it

	mov eax, [break_target_num] ; Get dem digits
	call emit_out               ; Emit it

	mov eax, process_break_string_3 ; Using "\n"
	call emit_out               ; Emit it

	mov eax, process_break_string_4 ; Using "ERROR in break statement\nMissing ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

process_break_bad:
	;; Breaking badly
	mov eax, 2                  ; Using standard error
	mov [Output_file], eax      ; write to standard error
;	call line_error             ; Write useful debug info
	mov eax, ecx                ; put S in the right place
	call File_Print             ; print it

	mov eax, process_break_string_0 ; Ending string
	call File_Print             ; print it
	jmp Exit_Failure            ; Abort Hard

process_break_string_0: db "Not inside of a loop or case statement", 0
process_break_string_1: db "POP_ebx", 9, "# break_cleanup_locals", 10, 0
process_break_string_2: db "JUMP %", 0
process_break_string_3: db 10, 0
process_break_string_4: db "ERROR in break statement",10, "Missing ;", 10, 0


;; expression function
;; Recieves Nothing
;; Returns Nothing
;; Walks global_token and updates output_list
;; Uses EAX and EBX for match and ECX for char* store
expression:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	call bitwise_expr           ; Collect bitwise expressions

	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, equal              ; "="
	call match                  ; IF global_token->S == "="
	cmp eax, 0                  ; We have to deal with assignment
	jne expression_done         ; Looks like nope

	;; Deal with possible assignment
	mov ecx, expression_string_1 ; Assume "STORE_CHAR\n" by default
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+4]            ; global_token->PREV
	mov ebx, [ebx+8]            ; global_token->PREV->S
	mov eax, close_bracket      ; Using "]"
	call match                  ; IF global_token->S == "]"
	cmp eax, 0                  ; Then we might have a char
	jne expression_int          ; Otherwise INT

	mov ebx, [current_target]   ; Using current_target
	mov ebx, [ebx+24]           ; current_target->NAME
	mov eax, type_char_indirect_name ; Using "char*"
	call match                  ; Intensional inefficency because I feel like it
	cmp eax, 0                  ; IF current_target->NAME == "char*"
	jne expression_int          ; Do char anyway

	jmp expression_common       ; Looks like we have to use "STORE_CHAR\n"

expression_int:
	mov ecx, expression_string_0 ; Use "STORE_INTEGER\n"

expression_common:
	mov eax, expression         ; Passing expression
	call common_recursion       ; Recurse
	mov eax, ecx                ; Using Store
	call emit_out               ; Emit it
	mov eax, 0                  ; Using NULL
	mov [current_target], eax   ; current_target = NULL

expression_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

expression_string_0: db "STORE_INTEGER", 10, 0
expression_string_1: db "STORE_CHAR", 10, 0


;; bitwise_expr function
;; Recieves nothing
;; Returns nothing
;; Walks global_token list and updates output list
;; Just calls other functions
bitwise_expr:
	call relational_expr        ; Walk up the tree
	call bitwise_expr_stub      ; Let general recursion do the work
	ret


;; bitwise_expr_stub function
;; Recieves nothing
;; Returns Nothing
;; Just calls general_recursion a bunch
;; Uses EAX, EBX, ECX and EDX for passing constants to general recursion
bitwise_expr_stub:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX

	mov eax, relational_expr    ; Using relational_expr
	mov ebx, bitwise_expr_stub_string_0 ; Using "AND_eax_ebx\n"
	mov ecx, bitwise_and        ; Using "&"
	mov edx, bitwise_expr_stub  ; And recurse
	call general_recursion      ; Hit it

	mov eax, relational_expr    ; Using relational_expr
	mov ebx, bitwise_expr_stub_string_0 ; Using "AND_eax_ebx\n"
	mov ecx, logical_and        ; Using "&&"
	mov edx, bitwise_expr_stub  ; And recurse
	call general_recursion      ; Hit it

	mov eax, relational_expr    ; Using relational_expr
	mov ebx, bitwise_expr_stub_string_1 ; Using "OR_eax_ebx\n"
	mov ecx, bitwise_or         ; Using "|"
	mov edx, bitwise_expr_stub  ; And recurse
	call general_recursion      ; Hit it

	mov eax, relational_expr    ; Using relational_expr
	mov ebx, bitwise_expr_stub_string_1 ; Using "OR_eax_ebx\n"
	mov ecx, logical_or         ; Using "||"
	mov edx, bitwise_expr_stub  ; And recurse
	call general_recursion      ; Hit it

	mov eax, relational_expr    ; Using relational_expr
	mov ebx, bitwise_expr_stub_string_2 ; Using "XOR_ebx_eax_into_eax\n"
	mov ecx, bitwise_xor        ; Using "^"
	mov edx, bitwise_expr_stub  ; And recurse
	call general_recursion      ; Hit it

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

bitwise_expr_stub_string_0: db "AND_eax_ebx", 10, 0
bitwise_expr_stub_string_1: db "OR_eax_ebx", 10, 0
bitwise_expr_stub_string_2: db "XOR_ebx_eax_into_eax", 10, 0


;; relational_expr function
;; Recieves nothing
;; Returns Nothing
;; Walks global_token list and updates output list
;; just calls other function
relational_expr:
	call additive_expr          ; Walk up the tree
	call relational_expr_stub   ; Recurse
	ret


;; relational_expr_stub function
;; Recieves nothing
;; Returns Nothing
;; Just calls general_recursion a bunch
;; Uses EAX, EBX, ECX and EDX for passing constants to general recursion
relational_expr_stub:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX

	mov eax, additive_expr      ; Using additive_expr
	mov ebx, relational_expr_stub_string_0 ; Using "CMP\nSETL\nMOVEZBL\n"
	mov ecx, less_than_string   ; Using "<"
	mov edx, relational_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, additive_expr      ; Using additive_expr
	mov ebx, relational_expr_stub_string_1 ; Using "CMP\nSETLE\nMOVEZBL\n"
	mov ecx, less_than_equal_string ; Using "<="
	mov edx, relational_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, additive_expr      ; Using additive_expr
	mov ebx, relational_expr_stub_string_2 ; Using "CMP\nSETGE\nMOVEZBL\n"
	mov ecx, greater_than_equal_string ; Using ">="
	mov edx, relational_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, additive_expr      ; Using additive_expr
	mov ebx, relational_expr_stub_string_3 ; Using "CMP\nSETG\nMOVEZBL\n"
	mov ecx, greater_than_string ; Using ">"
	mov edx, relational_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, additive_expr      ; Using additive_expr
	mov ebx, relational_expr_stub_string_4 ; Using "CMP\nSETE\nMOVEZBL\n"
	mov ecx, equal_to_string    ; Using "=="
	mov edx, relational_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, additive_expr      ; Using additive_expr
	mov ebx, relational_expr_stub_string_5 ; Using "CMP\nSETNE\nMOVEZBL\n"
	mov ecx, not_equal_string   ; Using "!="
	mov edx, relational_expr_stub ; And recurse
	call general_recursion      ; Hit it

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

relational_expr_stub_string_0: db "CMP", 10, "SETL", 10, "MOVEZBL", 10,  0
relational_expr_stub_string_1: db "CMP", 10, "SETLE", 10, "MOVEZBL", 10, 0
relational_expr_stub_string_2: db "CMP", 10, "SETGE", 10, "MOVEZBL", 10, 0
relational_expr_stub_string_3: db "CMP", 10, "SETG", 10, "MOVEZBL", 10, 0
relational_expr_stub_string_4: db "CMP", 10, "SETE", 10, "MOVEZBL", 10, 0
relational_expr_stub_string_5: db "CMP", 10, "SETNE", 10, "MOVEZBL", 10, 0


;; additive_expr function
;; Recieves nothing
;; Returns Nothing
;; Walks global_token list and updates output list
;; just calls other function
additive_expr:
	call postfix_expr           ; Walk up the tree
	call additive_expr_stub     ; Recurse
	ret


;; additive_expr_stub function
;; Recieves nothing
;; Returns Nothing
;; Just calls general_recursion a bunch
;; Uses EAX, EBX, ECX and EDX for passing constants to general recursion
additive_expr_stub:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX

	mov eax, postfix_expr       ; Using postfix_expr
	mov ebx, additive_expr_stub_string_0 ; Using "ADD_ebx_to_eax\n"
	mov ecx, plus_string        ; Using "+"
	mov edx, additive_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, postfix_expr       ; Using postfix_expr
	mov ebx, additive_expr_stub_string_1 ; Using "SUBTRACT_eax_from_ebx_into_ebx\nMOVE_ebx_to_eax\n"
	mov ecx, minus_string       ; Using "-"
	mov edx, additive_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, postfix_expr       ; Using postfix_expr
	mov ebx, additive_expr_stub_string_2 ; Using "MULTIPLY_eax_by_ebx_into_eax\n"
	mov ecx, multiply_string    ; Using "*"
	mov edx, additive_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, postfix_expr       ; Using postfix_expr
	mov ebx, additive_expr_stub_string_3 ; Using "XCHG_eax_ebx\nLOAD_IMMEDIATE_edx %0\nDIVIDE_eax_by_ebx_into_eax\n"
	mov ecx, divide_string      ; Using "/"
	mov edx, additive_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, postfix_expr       ; Using postfix_expr
	mov ebx, additive_expr_stub_string_4 ; Using "XCHG_eax_ebx\nLOAD_IMMEDIATE_edx %0\nMODULUS_eax_from_ebx_into_ebx\nMOVE_edx_to_eax\n"
	mov ecx, modulus_string     ; Using "%"
	mov edx, additive_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, postfix_expr       ; Using postfix_expr
	mov ebx, additive_expr_stub_string_5 ; Using "COPY_eax_to_ecx\nCOPY_ebx_to_eax\nSAL_eax_cl\n"
	mov ecx, left_shift_string  ; Using "<<"
	mov edx, additive_expr_stub ; And recurse
	call general_recursion      ; Hit it

	mov eax, postfix_expr       ; Using postfix_expr
	mov ebx, additive_expr_stub_string_6 ; Using "COPY_eax_to_ecx\nCOPY_ebx_to_eax\nSAR_eax_cl\n"
	mov ecx, right_shift_string ; Using ">>"
	mov edx, additive_expr_stub ; And recurse
	call general_recursion      ; Hit it

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

additive_expr_stub_string_0: db "ADD_ebx_to_eax", 10, 0
additive_expr_stub_string_1: db "SUBTRACT_eax_from_ebx_into_ebx", 10, "MOVE_ebx_to_eax", 10, 0
additive_expr_stub_string_2: db "MULTIPLY_eax_by_ebx_into_eax", 10, 0
additive_expr_stub_string_3: db "XCHG_eax_ebx", 10, "LOAD_IMMEDIATE_edx %0", 10, "DIVIDE_eax_by_ebx_into_eax", 10, 0
additive_expr_stub_string_4: db "XCHG_eax_ebx", 10, "LOAD_IMMEDIATE_edx %0", 10, "MODULUS_eax_from_ebx_into_ebx", 10, "MOVE_edx_to_eax", 10, 0
additive_expr_stub_string_5: db "COPY_eax_to_ecx", 10, "COPY_ebx_to_eax", 10, "SAL_eax_cl", 10, 0
additive_expr_stub_string_6: db "COPY_eax_to_ecx", 10, "COPY_ebx_to_eax", 10, "SAR_eax_cl", 10, 0


;; postfix_expr function
;; Recieves nothing
;; Returns Nothing
;; Walks global_token list and updates output list
;; just calls other function
postfix_expr:
	call primary_expr           ; Walk up the tree
	call postfix_expr_stub      ; Recurse
	ret


;; postfix_expr_stub function
;; Recieves nothing
;; Returns Nothing
;; Checks for "[" and "->" and deals with them otherwise does nothing
;; Uses EAX, EBX, ECX and EDX for passing constants to general recursion
postfix_expr_stub:
	push ebx                    ; Protect EBX
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, open_bracket       ; Using "["
	call match                  ; IF global_token->S == "["
	cmp eax, 0                  ; then we have an array
	jne postfix_expr_stub_arrow ; Otherwise try arrow

	;; Deal with array
	call postfix_expr_array     ; Get it
	call postfix_expr_stub      ; Recurse

postfix_expr_stub_arrow:
	mov eax, arrow_string       ; Using "->"
	call match                  ; IF global_token->S == "->"
	cmp eax, 0                  ; Then we need to deal with struct offsets
	jne postfix_expr_stub_done  ; Otherwise be done

	;; Deal with arrow
	call postfix_expr_arrow     ; Get it
	call postfix_expr_stub      ; Recurse

postfix_expr_stub_done:
	pop ebx                     ; Restore EBX
	ret


;; unary_expr_sizeof function
;; Recieves nothing
;; Returns nothing
;; Uses ECX for A->SIZE
unary_expr_sizeof:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, unary_expr_sizeof_string_0 ; Using "ERROR in unary_expr\nMissing (\n"
	mov ebx, open_paren         ; Using "("
	call require_match          ; Make sure we have it

	call type_name              ; Get the type
	mov ecx, [eax+4]            ; Set A->TYPE

	mov eax, unary_expr_sizeof_string_1 ; Using "ERROR in unary_expr\nMissing )\n"
	mov ebx, close_paren        ; Using ")"
	call require_match          ; Make sure we have it

	mov eax, unary_expr_sizeof_string_2 ; Using "LOAD_IMMEDIATE_eax %"
	call emit_out               ; Emit it

	mov eax, ecx                ; Put A->SIZE in the right place
	call numerate_number        ; Turn into string
	call emit_out               ; Emit it

	mov eax, unary_expr_sizeof_string_3 ; Using "\n"
	call emit_out               ; Emit it

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

unary_expr_sizeof_string_0: db "ERROR in unary_expr", 10, "Missing (", 10, 0
unary_expr_sizeof_string_1: db "ERROR in unary_expr", 10, "Missing )", 10, 0
unary_expr_sizeof_string_2: db "LOAD_IMMEDIATE_eax %", 0
unary_expr_sizeof_string_3: db 10, 0


;; postfix_expr_array function
;; Recieves Nothing
;; Returns Nothing
;; Uses EBX for struct type* ARRAY and ECX for char* ASSIGN
postfix_expr_array:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, [current_target]   ; ARRAY = current_target
	push eax                    ; Protect it

	mov eax, expression         ; Using expression
	call common_recursion       ; Recurse

	pop ebx                     ; Restore array
	mov [current_target], ebx   ; current_target = ARRAY

	mov ecx, postfix_expr_array_string_0 ; ASSIGN = "LOAD_INTEGER\n"

	mov eax, type_char_indirect_name ; Using "char*"
	mov ebx, [ebx+24]           ; current_target->NAME
	call match                  ; IF current_target->NAME == "char*"
	cmp eax, 0                  ; load a byte
	jne postfix_expr_array_large ; Otherwise adjust

	;; Deal with loading byte
	mov ecx, postfix_expr_array_string_1 ; ASSIGN = "LOAD_BYTE\n"
	jmp postfix_expr_array_common ; Do the next bit

postfix_expr_array_large:
	;; deal with arrays made of things other than chars
	mov eax, postfix_expr_array_string_2 ; Using "SAL_eax_Immediate8 !"
	call emit_out               ; Emit it

	mov eax, [current_target]   ; Using current_target
	mov eax, [eax+12]           ; current_target->INDIRECT
	mov eax, [eax+4]            ; current_target->INDIRECT->SIZE
	call ceil_log2              ; ceil_log2(current_target->indirect->size)
	call numerate_number        ; numerate_number(ceil_log2(current_target->indirect->size))
	call emit_out               ; Emit it

	mov eax, postfix_expr_array_string_3 ; Using "\n"
	call emit_out               ; Emit it

postfix_expr_array_common:
	mov eax, postfix_expr_array_string_4 ; Using "ADD_ebx_to_eax\n"
	call emit_out               ; Emit it

	mov eax, postfix_expr_array_string_5 ; Using "ERROR in postfix_expr\nMissing ]\n"
	mov ebx, close_bracket      ; Using "]"
	call require_match          ; Make sure we have it

	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, equal              ; Using "="
	call match                  ; IF global_token->S == "="
	cmp eax, 0                  ; We need to preserve address
	jne postfix_expr_array_done ; Otherwise be done

	;; Clearing out assign
	mov ecx, postfix_expr_array_string_6 ; ASSIGN = ""

postfix_expr_array_done:
	mov eax, ecx                ; Using ASSIGN
	call emit_out               ; Emit it

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

postfix_expr_array_string_0: db "LOAD_INTEGER", 10, 0
postfix_expr_array_string_1: db "LOAD_BYTE", 10, 0
postfix_expr_array_string_2: db "SAL_eax_Immediate8 !", 0
postfix_expr_array_string_3: db 10, 0
postfix_expr_array_string_4: db "ADD_ebx_to_eax", 10, 0
postfix_expr_array_string_5: db "ERROR in postfix_expr", 10, "Missing ]", 10, 0
postfix_expr_array_string_6: db 0


;; ceil_log2 function
;; Recieves int a in EAX
;; Performs log2 on A and
;; Returns result in EAX
;; Uses EBX for INT A and ECX for INT RESULT
ceil_log2:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ecx, 0                  ; RESULT = 0

	mov ebx, eax                ; put A in right place
	sub eax, 1                  ; (A - 1)
	and eax, ebx                ; A & (A - 1)
	cmp eax, 0                  ; IF 0 == (A & (A - 1))
	jne ceil_log2_iter          ; Starting from -1

	mov ecx, -1                 ; RESULT = -1

ceil_log2_iter:
	cmp ebx, 0                  ; IF A > 0
	jle ceil_log2_done          ; Otherwise be done

	add ecx, 1                  ; RESULT = RESULT + 1
	shr ebx, 1                  ; A = A >> 1
	jmp ceil_log2_iter          ; Keep looping

ceil_log2_done:
	mov eax, ecx                ; Return RESULT
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; postfix_expr_arrow function
;; Recieves nothing
;; Returns nothing
;; Emits a bunch and updates current_target
;; Uses EBX for struct type* I
postfix_expr_arrow:
	push ebx                    ; Protect EBX
	mov eax, postfix_expr_arrow_string_0 ; Using "# looking up offset\n"
	call emit_out               ; Emit it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov ebx, [eax+8]            ; Using global_token->S
	mov eax, [current_target]   ; Using current_target
	call lookup_member          ; lookup_member(current_target, global_token->s)
	mov ebx, eax                ; struct type* I = lookup_member(current_target, global_token->s)

	mov eax, [eax+20]           ; I->TYPE
	mov [current_target], eax   ; current_target = I->TYPE

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, [ebx+8]            ; I->OFFSET
	cmp eax, 0                  ; IF 0 != I->OFFSET
	je postfix_expr_arrow_first ; Then we don't need to do an offset

	;; Deal with needing an offset
	mov eax, postfix_expr_arrow_string_1 ; Using "# -> offset calculation\nLOAD_IMMEDIATE_ebx %"
	call emit_out               ; Emit it

	mov eax, [ebx+8]            ; I->OFFSET
	call numerate_number        ; Convert to string
	call emit_out               ; Emit it

	mov eax, postfix_expr_arrow_string_2 ; Using "\nADD_ebx_to_eax\n"
	call emit_out               ; Emit it

postfix_expr_arrow_first:
	mov eax, [ebx+4]            ; I->SIZE
	cmp eax, 4                  ; IF I->SIZE >= 4
	jl postfix_expr_arrow_done  ; Otherwise be done

	;; Last chance for load
	mov eax, [global_token]     ; Using global_token
	mov ebx, [eax+8]            ; global_token->S
	mov eax, equal              ; Using "="
	call match                  ; IF global_token->S == "="
	cmp eax, 0                  ; Then we have assignment and should not load
	je postfix_expr_arrow_done  ; Be done

	;; Deal with load case
	mov eax, postfix_expr_arrow_string_3 ; Using "LOAD_INTEGER\n"
	call emit_out               ; Emit it

postfix_expr_arrow_done:
	pop ebx                     ; Restore EBX
	ret

postfix_expr_arrow_string_0: db "# looking up offset", 10, 0
postfix_expr_arrow_string_1: db "# -> offset calculation", 10, "LOAD_IMMEDIATE_ebx %", 0
postfix_expr_arrow_string_2: db 10, "ADD_ebx_to_eax", 10, 0
postfix_expr_arrow_string_3: db "LOAD_INTEGER", 10, 0


;; primary_expr function
;; Recieves nothing
;; Returns nothing
primary_expr:
	push ebx                    ; Protect EBX

	mov eax, [global_token]     ; Using global_token
	mov ebx, [eax+8]            ; global_token->S
	mov eax, sizeof_string      ; Using "sizeof"
	call match                  ; See if match
	cmp eax, 0                  ; IF match
	jne primary_expr_neg        ; Otherwise try negatives

	;; Deal with sizeof
	call unary_expr_sizeof      ; Lets do this
	jmp primary_expr_done       ; Be done

primary_expr_neg:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	cmp eax, 45                 ; IF global_token->S[0] == "-"
	jne primary_expr_not        ; Otherwise try logical NOT

	;; Deal with negative numbers
	mov eax, primary_expr_string_0 ; Using "LOAD_IMMEDIATE_eax %0\n"
	call emit_out               ; Emit it

	mov eax, postfix_expr       ; Passing postfix_expr
	call common_recursion       ; Get what it is notting

	mov eax, primary_expr_string_1 ; Using "SUBTRACT_eax_from_ebx_into_ebx\nMOVE_ebx_to_eax\n"
	call emit_out               ; Emit it
	jmp primary_expr_done       ; Be done

primary_expr_not:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	cmp eax, 33                 ; IF global_token->S[0] == "!"
	jne primary_expr_bin        ; Otherwise try '~'

	;; Deal with logical not
	mov eax, primary_expr_string_2 ; Using "LOAD_IMMEDIATE_eax %1\n"
	call emit_out               ; Emit it

	mov eax, postfix_expr       ; Passing postfix_expr
	call common_recursion       ; Get what it is notting

	mov eax, primary_expr_string_3 ; Using "XOR_ebx_eax_into_eax\n"
	call emit_out               ; Emit it
	jmp primary_expr_done       ; Be done

primary_expr_bin:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	cmp eax, 126                ; IF global_token->S[0] == "~"
	jne primary_expr_paren      ; Otherwise try paren

	;; Deal with binary NOT
	mov eax, postfix_expr       ; Passing postfix_expr
	call common_recursion       ; Get what it is notting
	mov eax, primary_expr_string_4 ; Using "NOT_eax\n"
	call emit_out               ; Emit it
	jmp primary_expr_done       ; Be done

primary_expr_paren:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	cmp eax, 40                 ; IF global_token->S[0] == "("
	jne primary_expr_ch         ; Otherwise try char

	;; deal with nesting
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT
	call expression             ; Lets recurse
	mov eax, primary_expr_string_5 ; Using "Error in Primary expression\nDidn't get )\n"
	mov ebx, close_paren        ; Using ")"
	call require_match          ; Make sure we have it
	jmp primary_expr_done       ; Be done

primary_expr_ch:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	cmp eax, 39                 ; Using "'"
	jne primary_expr_str        ; Otherwise try string

	;; Deal with chars
	call primary_expr_char      ; Handle that char
	jmp primary_expr_done       ; Be done

primary_expr_str:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	cmp eax, 34                 ; Using '"'
	jne primary_expr_var        ; Otherwise try a variable

	;; Deal with strings
	call primary_expr_string    ; Handle that string
	jmp primary_expr_done       ; Be done

primary_expr_var:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	mov ebx, primary_expr_string_6 ; Using "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
	call In_Set                 ; See if we have a match
	cmp eax, 1                  ; IF match
	jne primary_expr_num        ; otherwise try number

	;; Deal with variables
	call primary_expr_variable  ; Deal with variable
	jmp primary_expr_done       ; Be done

primary_expr_num:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	mov ebx, primary_expr_string_7 ; Using "0123456789"
	call In_Set                 ; See if we have a match
	cmp eax, 1                  ; IF match
	jne primary_expr_fail       ; otherwise we failed hard

	;; Deal with numbers
	call primary_expr_number    ; Collect the number
	jmp primary_expr_done       ; Be done

primary_expr_fail:
	;; looks like we hit bad input
	;; abort before it gets bad
	call primary_expr_failure   ; No match means failure
primary_expr_done:
	pop ebx                     ; Restore EBX
	ret

primary_expr_string_0: db "LOAD_IMMEDIATE_eax %0", 10, 0
primary_expr_string_1: db "SUBTRACT_eax_from_ebx_into_ebx", 10, "MOVE_ebx_to_eax", 10, 0
primary_expr_string_2: db "LOAD_IMMEDIATE_eax %1", 10, 0
primary_expr_string_3: db "XOR_ebx_eax_into_eax", 10, 0
primary_expr_string_4: db "NOT_eax", 10, 0
primary_expr_string_5: db "Error in Primary expression", 10, "Didn't get )", 10, 0
primary_expr_string_6: db "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_", 0
primary_expr_string_7:db "0123456789", 0


;; primary_expr_variable function
;; Recieves nothing
;; Returns nothing
;; Walks global and updates output
;; Uses EAX for struct token_list* a and ECX for char* S
primary_expr_variable:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, [global_token]     ; Using global_token
	mov ecx, [eax+8]            ; S = global_token->S
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, ecx                ; Using S
	mov ebx, [global_constant_list] ; Using global_constant_list
	call sym_lookup             ; sym_lookup(s, global_constant_list)
	cmp eax, 0                  ; IF NULL == sym_lookup(s, global_constant_list)
	je primary_expr_variable_local ; Try locals next

	;; Deal with constant load
	mov ebx, [eax+16]              ; a->ARGS
	mov eax, primary_expr_variable_string_2 ; Using "LOAD_IMMEDIATE_eax %"
	call emit_out               ; Emit it

	mov eax, [ebx+8]            ; a->ARGS->S
	call emit_out               ; Emit it

	mov eax, primary_expr_variable_string_1 ; Using "\n"
	call emit_out               ; Emit it
	jmp primary_expr_variable_done ; Be done

primary_expr_variable_local:
	mov eax, ecx                ; Using S
	mov ebx, [function]         ; Using function
	mov ebx, [ebx+4]            ; function->locals
	call sym_lookup             ; sym_lookup(s, function->locals)
	cmp eax, 0                  ; IF NULL == sym_lookup(s, global_constant_list)
	je primary_expr_variable_arguments ; try arguments next

	;; Deal with local load
	call variable_load          ; Collect it
	jmp primary_expr_variable_done ; Be done

primary_expr_variable_arguments:
	mov eax, ecx                ; Using S
	mov ebx, [function]         ; Using function
	mov ebx, [ebx+16]           ; function->args
	call sym_lookup             ; sym_lookup(s, function->args)
	cmp eax, 0                  ; IF NULL == sym_lookup(s, global_constant_list)
	je primary_expr_variable_function ; try functions next

	;; Deal with argument load
	call variable_load          ; Collect it
	jmp primary_expr_variable_done ; Be done

primary_expr_variable_function:
	mov eax, ecx                ; Using S
	mov ebx, [global_function_list] ; Using global_function_list
	call sym_lookup             ; sym_lookup(s, global_function_list)
	cmp eax, 0                  ; IF NULL == sym_lookup(s, global_function_list)
	je primary_expr_variable_global ; try globals next

	;; Deal with functions
	call function_load          ; Deal with the function
	jmp primary_expr_variable_done ; Be done

primary_expr_variable_global:
	mov eax, ecx                ; Using S
	mov ebx, [global_symbol_list] ; Using global_symbol_list
	call sym_lookup             ; sym_lookup(s, global_symbol_list)
	cmp eax, 0                  ; IF NULL == sym_lookup(s, global_symbol_list)
	je primary_expr_variable_error ; Give up

	;; Deal with globals
	call global_load               ; Collect that global
	jmp primary_expr_variable_done ; Be done

primary_expr_variable_error:
	mov eax, 2                  ; Using standard error
	mov [Output_file], eax      ; write to standard error
;	call line_error             ; Write useful debug info
	mov eax, ecx                ; put S in the right place
	call File_Print             ; print it

	mov eax, primary_expr_variable_string_0 ; Ending string
	call File_Print             ; print it
	jmp Exit_Failure            ; Abort Hard

primary_expr_variable_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

primary_expr_variable_string_0: db " is not a defined symbol", 10, 0
primary_expr_variable_string_1: db 10, 0
primary_expr_variable_string_2: db "LOAD_IMMEDIATE_eax %", 0


;; function_call function
;; Recieves char* S in EAX and int BOOL in EBX
;; Builds stack frames before and tears them down after function calls
;; Uses ECX for char* S, EDX for int BOOL, ESI for PASSED
function_call:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	push esi                    ; Protect ESI
	mov ecx, eax                ; Put S in place
	mov edx, ebx                ; Put BOOL in place
	mov esi, 0                  ; PASSED = 0

	mov eax, function_call_string_0 ; Using "ERROR in process_expression_list\nNo ( was found\n"
	mov ebx, open_paren         ; Using "("
	call require_match          ; Make sure we have it

	mov eax, function_call_string_1 ; Using "PUSH_edi\t# Prevent overwriting in recursion\n"
	call emit_out               ; Emit it

	mov eax, function_call_string_2 ; Using "PUSH_ebp\t# Protect the old base pointer\n"
	call emit_out               ; Emit it

	mov eax, function_call_string_3 ; Using "COPY_esp_to_edi\t# Copy new base pointer\n"
	call emit_out               ; Emit it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	cmp eax, 41                 ; IF global_token->S[0] == ")"
	je function_call_gen_done   ; Then no arguments to send

	;; looks like we have arguments to collect
	call expression             ; Collect the argument

	mov eax, function_call_string_4 ; Using "PUSH_eax\t#_process_expression1\n"
	call emit_out               ; Emit it
	mov esi, 1                  ; PASSED = 1

function_call_gen_iter:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	cmp eax, 44                 ; IF global_token->S[0] == ","
	jne function_call_gen_done  ; Otherwise we are done

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	call expression             ; Collect the argument

	mov eax, function_call_string_5 ; Using "PUSH_eax\t#_process_expression2\n"
	call emit_out               ; Emit it
	add esi, 1                  ; PASSED = PASSED + 1
	jmp function_call_gen_iter  ; Keep trying

function_call_gen_done:
	;; All is collected
	mov eax, function_call_string_6 ; Using "ERROR in process_expression_list\nNo ) was found\n"
	mov ebx, close_paren         ; Using ")"
	call require_match          ; Make sure we have it

	cmp edx, 0                  ; IF(BOOL == TRUE)
	jne function_call_static    ; Otherwise it is a static call

	;; Deal with a passed function pointer
	mov eax, function_call_string_7 ; Using "LOAD_BASE_ADDRESS_eax %"
	call emit_out               ; Emit it

	mov eax, ecx                ; Using S
	call emit_out               ; Emit it

	mov eax, function_call_string_8 ; Using "\nLOAD_INTEGER\n"
	call emit_out               ; Emit it

	mov eax, function_call_string_9 ; Using "COPY_edi_to_ebp\n"
	call emit_out               ; Emit it

	mov eax, function_call_string_10 ; Using "CALL_eax\n"
	call emit_out               ; Emit it

	mov eax, function_call_string_13 ; Using "POP_ebx\t# _process_expression_locals\n"
	jmp function_call_cleanup   ; Clean up

function_call_static:
	;; Deal with fixed function name
	mov eax, function_call_string_9 ; Using "COPY_edi_to_ebp\n"
	call emit_out               ; Emit it

	mov eax, function_call_string_11 ; Using "CALL_IMMEDIATE %FUNCTION_"
	call emit_out               ; Emit it

	mov eax, ecx                ; Using S
	call emit_out               ; Emit it

	mov eax, function_call_string_12 ; Using "\n"
	call emit_out               ; Emit it

	mov eax, function_call_string_13 ; Using "POP_ebx\t# _process_expression_locals\n"

function_call_cleanup:
	cmp esi, 0                  ; IF PASSED > 0
	jle function_call_done      ; Otherwise be done

	;; The desired string is already in EAX
	call emit_out               ; Emit it

	sub esi, 1                  ; PASSED = PASSED - 1
	jmp function_call_cleanup   ; Keep going

function_call_done:
	mov eax, function_call_string_14 ; Using "POP_ebp\t# Restore old base pointer\n"
	call emit_out               ; Emit it

	mov eax, function_call_string_15 ; Using "POP_edi\t# Prevent overwrite\n"
	call emit_out               ; Emit it

	pop esi                     ; Restore ESI
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

function_call_string_0: db "ERROR in process_expression_list", 10, "No ( was found", 10, 0
function_call_string_1: db "PUSH_edi", 9, "# Prevent overwriting in recursion", 10, 0
function_call_string_2: db "PUSH_ebp", 9, "# Protect the old base pointer", 10, 0
function_call_string_3: db "COPY_esp_to_edi", 9, "# Copy new base pointer", 10, 0
function_call_string_4: db "PUSH_eax", 9, "#_process_expression1", 10, 0
function_call_string_5: db "PUSH_eax", 9, "#_process_expression2", 10, 0
function_call_string_6: db "ERROR in process_expression_list", 10, "No ) was found", 10, 0
function_call_string_7: db "LOAD_BASE_ADDRESS_eax %", 0
function_call_string_8: db 10, "LOAD_INTEGER", 10, 0
function_call_string_9: db "COPY_edi_to_ebp", 10, 0
function_call_string_10: db "CALL_eax", 10, 0
function_call_string_11: db "CALL_IMMEDIATE %FUNCTION_", 0
function_call_string_12: db 10, 0
function_call_string_13: db "POP_ebx", 9, "# _process_expression_locals", 10, 0
function_call_string_14: db "POP_ebp", 9, "# Restore old base pointer", 10, 0
function_call_string_15: db "POP_edi", 9, "# Prevent overwrite", 10, 0


;; variable_load function
;; Recieves struct token_list* A in EAX
;; Returns nothing
;; Updates output and current_target
;; Uses ECX for A
variable_load:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ecx, eax                ; Protect A

	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, open_paren         ; Using "("
	call match                  ; IF global_token->S == "("
	cmp eax, 0                  ; Then it might be a function
	jne variable_load_regular   ; Otherwise it is regular

	mov ebx, [ecx+12]           ; A->TYPE
	mov ebx, [ebx+24]           ; A->TYPE->NAME
	mov eax, type_function_name ; Using "FUNCTION"
	call match                  ; IF A->TYPE->NAME == "FUNCTION"
	cmp eax, 0                  ; Then it must be a function
	jne variable_load_regular   ; otherwise just another regular

	;; deal with function
	mov eax, [ecx+16]           ; A->DEPTH
	call numerate_number        ; Convert to string
	mov ebx, 0                  ; pass 0 for true
	call function_call          ; Create the function call
	jmp variable_load_done      ; Be done

variable_load_regular:
	mov eax, [ecx+12]           ; A->TYPE
	mov [current_target], eax   ; current_target = A->TYPE

	mov eax, variable_load_string_0 ; Using "LOAD_BASE_ADDRESS_eax %"
	call emit_out               ; Emit it

	mov eax, [ecx+16]           ; A->DEPTH
	call numerate_number        ; Convert to string
	call emit_out               ; Emit it

	mov eax, variable_load_string_1 ; Using "\n"
	call emit_out               ; Emit it

	;; Check for special case of assignment
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, equal              ; Using "="
	call match                  ; IF global_token->S == "="
	cmp eax, 0                  ; Then we skip loading
	je variable_load_done       ; And be done

	;; Deal with common case
	mov eax, variable_load_string_2 ; Using "LOAD_INTEGER\n"
	call emit_out               ; Emit it

variable_load_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

variable_load_string_0: db "LOAD_BASE_ADDRESS_eax %", 0
variable_load_string_1: db 10, 0
variable_load_string_2: db "LOAD_INTEGER", 10, 0


;; function_load function
;; Recieves struct token_list* a in EAX
;; Returns nothing
;; Uses ECX to hold A->S
function_load:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, [eax+8]            ; A->S
	mov ecx, eax                ; Protect A->S
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, open_paren         ; Using "("
	call match                  ; IF global_token->S == "("
	cmp eax, 0                  ; The we need to do a function call
	jne function_load_regular   ; Otherwise just load it's address

	;; Deal with function call
	mov eax, ecx                ; Using A->S
	mov ebx, 1                  ; Using FALSE
	call function_call          ; Deal with it
	jmp function_load_done      ; Be done

function_load_regular:
	mov eax, function_load_string_0 ; Using "LOAD_IMMEDIATE_eax &FUNCTION_"
	call emit_out               ; Emit it

	mov eax, ecx                ; Using A->S
	call emit_out               ; Emit it

	mov eax, function_load_string_1 ; Using "\n"
	call emit_out               ; Emit it

function_load_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

function_load_string_0: db "LOAD_IMMEDIATE_eax &FUNCTION_", 0
function_load_string_1: db 10, 0


;; global_load function
;; Recieves struct token_list* A in EAX
;; Returns nothing
;; Uses EBX to hold A->S
global_load:
	push ebx                    ; Protect EBX
	mov ebx, eax                ; Set as A
	mov ebx, [ebx+8]            ; Set as A->S

	mov eax, [eax+12]           ; A->TYPE
	mov [current_target], eax   ; current_target = A->TYPE

	mov eax, global_load_string_0 ; Using "LOAD_IMMEDIATE_eax &GLOBAL_"
	call emit_out               ; Emit it

	mov eax, ebx                ; Using A->S
	call emit_out               ; Emit it

	mov eax, global_load_string_1 ; Using "\n"
	call emit_out               ; Emit it

	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, equal              ; "="
	call match                  ; IF global_token->S == "="
	cmp eax, 0                  ; We need to skip for assignment
	je global_load_done         ; and be done

	;; Otherwise we are loading the contents
	mov eax, global_load_string_2 ; Using "LOAD_INTEGER\n"
	call emit_out               ; Emit it

global_load_done:
	pop ebx                     ; Restore EBX
	ret

global_load_string_0: db "LOAD_IMMEDIATE_eax &GLOBAL_", 0
global_load_string_1: db 10, 0
global_load_string_2: db "LOAD_INTEGER", 10, 0


;; sym_lookup function
;; Recieves char* S in EAX and struct token_list* symbol_list in EBX
;; Uses I->S in EAX, S in EBX and I in ECX
;; Returns match or NULL
sym_lookup:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ecx, ebx                ; I = symbol_list
	mov ebx, eax                ; Put S in the right place
sym_lookup_iter:
	cmp ecx, 0                  ; IF NULL == I
	je sym_lookup_done          ; We failed to find match

	mov eax, [ecx+8]            ; Using I->S
	call match                  ; IF I->S == S
	cmp eax, 0                  ; then be done
	je sym_lookup_done          ; Failed

	mov ecx, [ecx]              ; I = I->NEXT
	jmp sym_lookup_iter         ; otherwise keep looping

sym_lookup_done:
	mov eax, ecx                ; Return I
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; primary_expr_number function
;; Recieves nothing
;; Returns nothing
;; Simply uses current global token to update output and then steps to next global_token
primary_expr_number:
	mov eax, primary_expr_number_string_0 ; Using "LOAD_IMMEDIATE_eax %"
	call emit_out               ; Emit it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	call emit_out               ; Emit it

	mov eax, primary_expr_number_string_1 ; Using "\n"
	call emit_out               ; Emit it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT
	ret

primary_expr_number_string_0: db "LOAD_IMMEDIATE_eax %", 0
primary_expr_number_string_1: db 10, 0


;; primary_expr_string function
;; recieves nothing
;; Returns nothing
;; creates entries for string and calls to generate string output
;; uses ECX for char* number_string
primary_expr_string:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ebx, [current_count]    ; Using current_count
	mov eax, ebx                ; And putting it in the right place
	call numerate_number        ; Get the string
	mov ecx, eax                ; protect number_string

	add ebx, 1                  ; current_count + 1
	mov [current_count], ebx    ; current_count = current_count + 1

	mov eax, primary_expr_string_string_0 ; Using "LOAD_IMMEDIATE_eax &STRING_"
	call emit_out               ; Emit it

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	mov ebx, ecx                ; Put number_string in the right place
	call uniqueID_out           ; Make it unique

	;; Generate the target
	mov eax, primary_expr_string_string_1 ; Using ":STRING_"
	mov ebx, [strings_list]     ; Using strings_list
	call emit                   ; Emit it
	mov ebx, eax                ; put new strings_list in place

	mov eax, [function]         ; Using function
	mov eax, [eax+8]            ; function->S
	call uniqueID               ; Make it unique
	mov ebx, eax                ; put new strings_list in place

	;; Parse the string
	mov eax, [global_token]     ; Using global token
	mov eax, [eax+8]            ; global_token->S
	call parse_string           ; convert to useful form
	call emit                   ; Emit it
	mov [strings_list], eax     ; Update Strings _list

	mov eax, [global_token]     ; Using global token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

primary_expr_string_string_0: db "LOAD_IMMEDIATE_eax &STRING_", 0
primary_expr_string_string_1: db ":STRING_", 0


;; primary_expr_char function
;; Recieves nothing
;; Returns nothing
;; Updates output_list using global_token
primary_expr_char:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov eax, primary_expr_char_string_0 ; Using "LOAD_IMMEDIATE_eax %"
	call emit_out               ; Emit it

	mov eax, [global_token]     ; Using global token
	mov eax, [eax+8]            ; global_token->S
	add eax, 1                  ; global_token->S + 1
	call escape_lookup          ; Get the char
	call numerate_number        ; Convert to string
	call emit_out               ; emit it

	mov eax, primary_expr_char_string_1 ; Using "\n"
	call emit_out               ; Emit it

	mov eax, [global_token]     ; Using global token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

primary_expr_char_string_0: db "LOAD_IMMEDIATE_eax %", 0
primary_expr_char_string_1: db 10, 0


;; primary_expr_failure function
;; Recieves nothing
;; Does not return but aborts hard
;; Complains about the bad input
primary_expr_failure:
;	call line_error             ; Get line of issue
	mov eax, 2                  ; Using Standard error
	mov [Output_file], eax      ; write to standard error
	mov eax, primary_expr_failure_string_0 ; Using "Recieved "
	call File_Print             ; Print it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	call File_Print             ; Print it

	mov eax, primary_expr_failure_string_1 ; Using " in primary_expr\n"
	call File_Print             ; Print it
	jmp Exit_Failure            ; Abort Hard

primary_expr_failure_string_0: db "Recieved ", 0
primary_expr_failure_string_1: db " in primary_expr", 10, 0


;; general_recursion function
;; Recieves FUNCTION F in EAX, char* S in EBX, char* name in ECX and FUNCTION iterate in EDX
;; Returns nothing
;; Uses ECX for char* S, EDX for FUNCTION iterate and EBP for FUNCTION F
;; But generally recurses a shitload
general_recursion:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	push ebp                    ; Protect EBP
	mov ebp, eax                ; Protect F
	mov eax, ecx                ; Put name in the right place
	mov ecx, ebx                ; Protect S

	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	call match                  ; IF match(name, global_token->s)
	cmp eax, 0                  ; If true we do
	jne general_recursion_done  ; Otherwise skip it

	;; Deal with the recursion
	mov eax, ebp                ; Put F in the right place
	call common_recursion       ; Recurse

	mov eax, ecx                ; Put S in the right place
	call emit_out               ; Emit it

	mov eax, edx                ; Put iterate in the right place
	call eax                    ; Down the rabbit hole

general_recursion_done:
	pop ebp                     ; Restore EBP
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; promote_type function
;; Recieves struct type* a in EAX and struct type* b in EBX
;; Returns the most recent type in EAX
;; Uses EAX for struct type* I, ECX for struct type* A and EDX for struct type* B
promote_type:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	cmp ebx, 0                  ; IF NULL == A
	je promote_type_done        ; Just return A

	mov ecx, eax                ; Put A in place
	mov edx, ebx                ; Put B in place
	mov eax, ebx                ; IF NULL == A
	cmp ecx, 0                  ; Then we just return B
	je promote_type_done        ; Be done

	;; Looks like we need to walk the list
	mov ecx, [ecx+24]           ; A->NAME
	mov edx, [edx+24]           ; B->NAME
	mov eax, [global_types]     ; I = global_types
promote_type_iter:
	cmp eax, 0                  ; IF NULL == I
	je promote_type_done        ; Just be done

	mov ebx, [eax+24]           ; I->NAME
	cmp ebx, ecx                ; IF(A->NAME == I->NAME)
	je promote_type_done        ; Be done

	cmp ebx, edx                ; IF(B->NAME == I->NAME)
	je promote_type_done        ; Be done

	mov ebx, [eax+12]           ; I->INDIRECT
	mov ebx, [ebx+24]           ; I->INDIRECT->NAME

	cmp ebx, ecx                ; IF(A->NAME == I->INDIRECT->NAME)
	je promote_type_done        ; Be done

	cmp ebx, edx                ; IF(B->NAME == I->INDIRECT->NAME)
	je promote_type_done        ; Be done

	mov eax, [eax]              ; I = I->NEXT
	jmp promote_type_iter       ; Keep going

promote_type_done:
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; common_recursion function
;; Recieves FUNCTION F in EAX
;; Returns Nothing
;; Walks global_token list and update output_list
;; Updates current_target
;; Uses EBX to hold FUNCTION F and struct type* last_type
common_recursion:
	push ebx                    ; Protect EBX
	mov ebx, eax                ; Put FUNCTION F safely out of the way
	mov eax, common_recursion_string_0 ; Using "PUSH_eax\t#_common_recursion\n"
	call emit_out               ; Emit it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, ebx                ; Prepare for function call
	mov ebx, [current_target]   ; Get last type
	call eax                    ; F();
	mov eax, [current_target]   ; Get current_target
	call promote_type           ; get the right type
	mov [current_target], eax   ; Set new current_target

	mov eax, common_recursion_string_1 ; Using "POP_ebx\t# _common_recursion\n"
	call emit_out               ; Emit it
	pop ebx                     ; Restore EBX
	ret

common_recursion_string_0: db "PUSH_eax", 9, "#_common_recursion", 10, 0
common_recursion_string_1: db "POP_ebx", 9, "# _common_recursion", 10, 0


;; require_match function
;; Recieves char* message in EAX and char* required in EBX
;; Returns nothing
;; Uses ECX to hold message and updates global_token
require_match:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ecx, eax                ; put the message somewhere safe
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	call match                  ; IF required == global_token->S
	cmp eax, 0                  ; we are fine
	je require_match_good       ; otherwise pain

	;; Deal will bad times
;	call line_error             ; Tell user what went wrong
	mov eax, 2                  ; Using standard error
	mov [Output_file], eax      ; write to standard error
	mov eax, ecx                ; using our message
	call File_Print             ; Print it
	jmp Exit_Failure            ; Abort HARD

require_match_good:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->next
	mov [global_token], eax     ; global_token = global_token->next
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; uniqueID Function
;; Recieves char*S in EAX, struct token_list* l in EBX snd char* num in ECX
;; Returns updated struct token_list* L in EAX
uniqueID:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	call emit                   ; emit(s, l)
	mov ebx, eax                ; Put L in correct place
	mov eax, underline          ; Usinf "_"
	call emit                   ; emit("_", l)
	mov ebx, eax                ; Put L in correct place
	mov eax, ecx                ; Put num in correct place
	call emit                   ; emit(num, l)
	mov ebx, eax                ; Put L in correct place
	mov eax, uniqueID_string_0  ; Using "\n"
	call emit                   ; emit("\n", l)
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

uniqueID_string_0: db 10, 0


;; uniqueID_out function
;; Recieves char* S in EAX and char* num in EBX
;; Returns nothing
uniqueID_out:
	push eax                    ; Protect EAX
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ecx, ebx                ; Put num in right spot
	mov ebx, [output_list]      ; Using output_list
	call uniqueID               ; Get updated list
	mov [output_list], eax      ; output_list = uniqueID(s, output_list, num)
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	pop eax                     ; Restore EAX
	ret


;; emit_out function
;; Recieves char* S in EAX
;; Returns nothing
;; Updates output_list
;; MUST NOT ALTER REGISTERS
emit_out:
	push eax                    ; Protect EAX
	push ebx                    ; Protect EBX
	mov ebx, [output_list]      ; Using output_list
	call emit                   ; emit it
	mov [output_list], eax      ; update it
	pop ebx                     ; Restore EBX
	pop eax                     ; Restore EAX
	ret


;; emit function
;; Recieves char *s in EAX and struct token_list* head in EBX
;; Returns struct token_list* T in EAX
emit:
	push ecx                    ; Protect ECX
	mov ecx, eax                ; put S out of the way
	mov eax, 20                 ; sizeof(struct token_list)
	call malloc                 ; get T
	mov [eax], ebx              ; t->next = head;
	mov [eax+8], ecx            ; t->s = s;
	pop ecx                     ; Restore ECX
	ret


;; escape_lookup function
;; Recieves char* c in EAX
;; Returns integer value of char in EAX
;; Aborts hard if unknown escape is recieved
;; Uses ECX to hold char* C
escape_lookup:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ecx, eax                ; Put char* C in safe place
	mov al, [ecx]               ; Load c[0]
	movzx eax, al               ; make it useful
	cmp eax, 92                 ; If '\\' != c[0]
	jne escape_lookup_done      ; Be done

	mov ebx, ecx                ; Prepare for walk
	add ebx, 1                  ; increment
	mov bl, [ebx]               ; load c[1]
	movzx ebx, bl               ; make it useful

	cmp ebx, 120                ; Check if \x??
	je escape_lookup_hex        ; Deal with hex

	;; Deal with \? escapes
	mov eax, 10                 ; Guess "\n"
	cmp ebx, 110                ; If n
	je escape_lookup_done       ; Be done

	mov eax, 9                  ; Guess "\t"
	cmp ebx, 116                ; If t
	je escape_lookup_done       ; Be done

	mov eax, ebx                ; "\\", "'" and '"' all encode as themselves
	cmp ebx, 92                 ; If "\\"
	je escape_lookup_done       ; Be done
	cmp ebx, 39                 ; IF "'"
	je escape_lookup_done       ; Be done
	cmp ebx, 34                 ; IF '"'
	je escape_lookup_done       ; Be done

	mov eax, 13                 ; Guess "\r"
	cmp ebx, 114                ; IF r
	je escape_lookup_done       ; Be done

	;; Looks like we have no clue what we are doing
	;; Aborting hard
	mov eax, 2                  ; Using Standard error
	mov [Output_file], eax      ; write to standard error
	mov eax, escape_lookup_string_0 ; Using "Unknown escape recieved: "
	call File_Print             ; Print it
	mov eax, ecx                ; Using C
	call File_Print             ; Print it
	mov eax, escape_lookup_string_1 ; Using " Unable to process\n"
	call File_Print             ; Print it
	jmp Exit_Failure            ; Abort Hard

escape_lookup_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

escape_lookup_hex:
	;; Give up on C and just assume they know what they are doing
	add ecx, 2                  ; increment
	mov al, [ecx]               ; c[2]
	movzx eax, al               ; make it useful
	add ecx, 1                  ; increment
	call char2hex               ; Get the hex value
	sal eax, 4                  ; c << 4
	mov bl, [ecx]               ; c[3]
	movzx ebx, bl               ; make it useful
	xchg eax, ebx               ; protect c << 4
	call char2hex               ; Get the hex value
	add eax, ebx                ; hex(c[2]) << 4 + hex(c[3])
	jmp escape_lookup_done      ; Be done

escape_lookup_string_0: db "Unknown escape recieved: ", 0
escape_lookup_string_1: db " Unable to process", 10, 0


;; char2hex function
;; Recieves char in EAX
;; Returns hex or aborts hard
char2hex:
	sub eax, 48                 ; Try 0-9
	cmp eax, 10                 ; Otherwise fun times
	jl char2hex_done            ; Be done

	;; Deal with A-F
	and eax, 0xDF               ; Unset High bit turning a-f into A-F
	sub eax, 7                  ; Shift down into position
	cmp eax, 10                 ; Everything below A is bad
	jl char2hex_fail            ; And should fail
	cmp eax, 16                 ; Make sure we are below F
	jl char2hex_done            ; If so be done

char2hex_fail:
	;; Time to fail hard
	mov eax, 2                  ; Using Standard error
	mov [Output_file], eax      ; write to standard error
	mov eax, char2hex_string_0  ; Using "Tried to print non-hex number\n"
	call File_Print             ; Print it
	jmp Exit_Failure            ; Abort Hard

char2hex_done:
	ret

char2hex_string_0: db "Tried to print non-hex number", 10, 0


;; parse_string function
;; Recieves char* string in EAX
;; Returns cleaned up string
;; Protects char* string in EBX
parse_string:
	push ebx                    ; Protect EBX
	mov ebx, eax                ; Protect char* string
	call weird                  ; Determine if we have a weird string
	cmp eax, 0                  ; If weird
	je parse_string_weird       ; Deal with it

	;; Dealing with regular string
	mov eax, ebx                ; Passing Char* string
	call collect_regular_string ; Collect it
	jmp parse_string_done       ; Be done

parse_string_weird:
	mov eax, ebx                ; Passing Char* string
	call collect_weird_string   ; Collect it

parse_string_done:
	pop ebx                     ; Restore EBX
	ret


;; weird function
;; Recieves char* string in EAX
;; Returns true(0) or false(1) in EAX
;; Uses ECX to hold char* string
weird:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ecx, eax                ; Place string in safe place
	add ecx, 1                  ; increment past the "
weird_reset:
	mov al, [ecx]               ; Load a char
	movzx eax, al               ; Make it useful
	cmp eax, 0                  ; IF NULL == C
	je weird_false              ; Nothing weird found

	cmp eax, 92                 ; IF '\\'
	jne weird_escaped           ; Deal with escaping

	;; Deal with escape
	mov eax, ecx                ; We are passing the string
	call escape_lookup          ; to look it up

	add ecx, 1                  ; string = string + 1
	mov bl, [ecx]               ; get string[1]
	movzx ebx, bl               ; make it useful
	cmp ebx, 120                ; IF 'x' == string[1]
	jne weird_escaped           ; otherwise skip the gap

	add ecx, 2                  ; string = string + 2

weird_escaped:
	push eax                    ; Protect C in case we need it
	mov ebx, weird_string_0     ; Use "\t\n !#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
	call In_Set                 ; To find if weird
	cmp eax, 1                  ; IF TRUE
	pop eax                     ; Restore C
	jne weird_true              ; Then not weird

	add ecx, 1                  ; string = string + 1

	;; Last chance for weird
	mov ebx, weird_string_1     ; Use "\t\n\r "
	call In_Set                 ; Check for special case
	cmp eax, 1                  ; IF TRUE
	jne weird_reset             ; Otherwise not in the special case

	;; Deal with possible special case
	mov al, [ecx]               ; Load string[1]
	movzx eax, al               ; Make it useful
	cmp eax, 58                 ; IF string[1] == ":"
	je weird_true               ; Then we hit the special case
	jmp weird_reset             ; Keep trying

weird_done:
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

weird_true:
	mov eax, 0                  ; Return true
	jmp weird_done              ; Be done

weird_false:
	mov eax, 1                  ; Return false
	jmp weird_done              ; Be done

weird_string_0: db 9, 10, " !#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~", 0
weird_string_1: db 9, 10, 13, 32, 0


;; collect_regular_string function
;; Recieves char* string in EAX
;; Malloc and creates new string to return in EAX
;; Uses ECX for return string and EDX for passed string
collect_regular_string:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov edx, eax                ; Protect our passed string
	mov eax, 256                ; We need 256bytes of storage
	call malloc                 ; Get our new pointer
	mov ecx, eax                ; put it in place
	push eax                    ; protect until done
collect_regular_string_reset:
	mov al, [edx]               ; string[0]
	movzx eax, al               ; Make it useful
	cmp eax, 0                  ; See if we hit the end
	je collect_regular_string_done ; And be done

	cmp eax, 92                 ; IF string[0] == '\\'
	je collect_regular_string_escaped ; Deal with that mess

	;; deal with boring char
	mov [ecx], al               ; hold_string[index] = string[0]
	add ecx, 1                  ; Increment it
	add edx, 1                  ; Increment it
	jmp collect_regular_string_reset ; And keep going

collect_regular_string_escaped:
	mov eax, edx                ; Using string
	call escape_lookup          ; Get the char
	mov [ecx], al               ; hold_string[index] = escape_lookup(string)
	add edx, 1                  ; Increment it
	add ecx, 1                  ; Increment it
	mov al, [edx]               ; string[0]
	movzx eax, al               ; Make it useful
	add edx, 1                  ; Increment it
	cmp eax, 120                ; IF 'x' == string[1]
	jne collect_regular_string_reset ; Otherwise keep going

	add edx, 2                  ; Increment it
	jmp collect_regular_string_reset ; Keep going

collect_regular_string_done:
	mov eax, 34                 ; Using '"'
	mov [ecx], al               ; hold_string[index] = '"'
	add ecx, 1                  ; Increment it
	mov eax, 10                 ; Using "\n"
	mov [ecx], al               ; hold_string[index] = '\n'
	pop eax                     ; Return our new string
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; collect_weird_string function
;; Recieves char* string in EAX
;; Mallocs and returns char* hold in EAX
;; Uses ECX for char* hold and EDX for char* string
collect_weird_string:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov edx, eax                ; Protect our passed string
	mov eax, 512                ; We need 512bytes of storage
	call malloc                 ; Get our new pointer
	mov ecx, eax                ; put it in place
	push eax                    ; protect until done

	mov eax, 39                 ; Using "'"
	mov [ecx], al               ; hold_string[index] = "'"
	add ecx, 1                  ; Increment it
	add edx, 1                  ; Increment it
collect_weird_string_reset:
	mov al, [edx]               ; Read a byte
	movzx eax, al               ; Make it useful
	cmp eax, 0                  ; IF NULL == string[0]
	je collect_weird_string_done ; Be done

	mov eax, 32                 ; Using ' '
	mov [ecx], al               ; hold_string[index] = ' '
	add ecx, 1                  ; Increment it

	mov eax, edx                ; Using string
	call escape_lookup          ; Get the char
	call hex8                   ; Update ECX

	mov al, [edx]               ; Read a byte
	movzx eax, al               ; Make it useful
	add edx, 1                  ; Increment it
	cmp eax, 92                 ; IF string[0] == '\\'
	jne collect_weird_string_reset ; Otherwise keep going

	mov al, [edx]               ; Read a byte
	movzx eax, al               ; Make it useful
	add edx, 1                  ; Increment it
	cmp eax, 120                ; IF 'x' == string[1]
	jne collect_weird_string_reset ; Otherwise keep going

	add edx, 2                  ; Increment it
	jmp collect_weird_string_reset ; Keep going

collect_weird_string_done:
	mov eax, 32                 ; Using ' '
	mov [ecx], al               ; hold_string[index] = ' '
	add ecx, 1                  ; Increment it
	mov eax, 48                 ; Using '0'
	mov [ecx], al               ; hold_string[index] = '0'
	add ecx, 1                  ; Increment it
	mov [ecx], al               ; hold_string[index] = '0'
	add ecx, 1                  ; Increment it
	mov eax, 39                 ; Using "'"
	mov [ecx], al               ; hold_string[index] = "'"
	add ecx, 1                  ; Increment it
	mov eax, 10                 ; Using "\n"
	mov [ecx], al               ; hold_string[index] = '\n'
	pop eax                     ; Return our new string
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; HEX to ascii routine
;; Recieves INT in EAX and CHAR* in ECX
;; Stores ascii of INT in CHAR*
;; Returns only modifying EAX and ECX
hex8:
	push eax                    ; Protect bottom nibble
	shr eax, 4                  ; do high nibble first
	call hex4                   ; Store it
	pop eax                     ; do low nibble
hex4:
	and eax, 0xf                ; isolate nibble
	add al,'0'                  ; convert to ascii
	cmp al,'9'                  ; valid digit?
	jbe hex1                    ; yes
	add al,7                    ; use alpha range
hex1:
	mov [ecx], al               ; store result
	add ecx, 1                  ; next position
	ret


;; type_name function
;; Recieves nothing
;; Returns type_size in EAX
;; Uses ECX for STRUCT TYPE* RET
type_name:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx+8]            ; global_token->S
	mov eax, struct             ; Using "struct"
	call match                  ; IF global_token->S == "struct"
	mov ecx, eax                ; Protect structure
	cmp eax, 0                  ; need to skip over "struct"
	jne type_name_native        ; otherwise keep going

	;; Deal with possible STRUCTs
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx]              ; global_token->next
	mov [global_token], ebx     ; global_token = global_token->next
	mov eax, [ebx+8]            ; global_token->S
	mov ebx, [global_types]     ; get all known types
	call lookup_type            ; Find type if possible
	mov ecx, eax                ; Set ret

	cmp eax, 0                  ; IF NULL == ret
	jne type_name_common        ; We have to create struct

	;; Create a struct
	call create_struct          ; Create a new struct
	mov ecx, 0                  ; We wish to return NULL
	jmp type_name_done          ; be done

type_name_native:
	;; Deal only with native types
	mov eax, ebx                ; Put global_token->S in the right place
	mov ebx, [global_types]     ; get all known types
	call lookup_type            ; Find the type if possible
	mov ecx, eax                ; Set ret

	cmp eax, 0                  ; IF NULL == ret
	jne type_name_common        ; We need to abort hard

	;; Aborting hard
	mov eax, 2                  ; Using Standard error
	mov [Output_file], eax      ; write to standard error
	mov eax, type_name_string_0 ; Print header
	call File_Print             ; Print it

	mov eax, [global_token]     ; Using global token
	mov eax, [eax+8]            ; global_token->S
	call File_Print             ; Print it

	mov eax, type_name_string_1 ; Print footer
	call File_Print             ; Print it

;	call line_error             ; Give details
	jmp Exit_Failure           ; Abort

type_name_common:
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx]              ; global_token->next
	mov [global_token], ebx     ; global_token = global_token->next

type_name_iter:
	mov eax, [ebx+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; make it useful
	cmp eax, 42                 ; IF global_token->S[0] == '*'
	jne type_name_done          ; recurse

	;; Deal with char**
	mov ecx, [ecx+12]           ; ret = ret->indirect
	mov ebx, [global_token]     ; Using global_token
	mov ebx, [ebx]              ; global_token->next
	mov [global_token], ebx     ; global_token = global_token->next
	jmp type_name_iter          ; keep looping

type_name_done:
	mov eax, ecx                ; put ret in the right place
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

type_name_string_0: db "Unknown type ", 0
type_name_string_1: db 10, 0


;; lookup_type function
;; Recieves char* s in EAX and struct type* start in EBX
;; Returns struct type* in EAX
;; Uses EBX for S and ECX for I
lookup_type:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ecx, ebx                ; I = Start
	mov ebx, eax                ; Put S in place
lookup_type_iter:
	cmp ecx, 0                  ; Check if I == NULL
	je lookup_type_done         ; return NULL

	mov eax, [ecx+24]           ; I->NAME
	call match                  ; Check if matching
	cmp eax, 0                  ; IF I->NAME == S
	je lookup_type_done         ; return it

	mov ecx, [ecx]              ; Otherwise I = I->NEXT
	jmp lookup_type_iter        ; And keep looping

lookup_type_done:
	mov eax, ecx                ; return either I or NULL
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; create_struct function
;; Recieves nothing
;; Returns nothing
;; Uses global_token to malloc a struct's definition
;; Uses ECX for int OFFSET, EDX for struct type* head, EBP for struct type* I,
;; EDI for member_size (Which is passed) and ESI for LAST
;; EAX and EBX are used for scratch
create_struct:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	push ebp                    ; Protect EBP
	push edi                    ; Protect EDI
	push esi                    ; Protect ESI
	mov ecx, 0                  ; OFFSET = 0
	mov edi, 0                  ; member_size = 0

	mov eax, 28                 ; sizeof(struct type)
	call malloc                 ; malloc(sizeof(struct type))
	mov edx, eax                ; Set HEAD

	mov eax, 28                 ; sizeof(struct type)
	call malloc                 ; malloc(sizeof(struct type))
	mov ebp, eax                ; Set I

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov [edx+24], eax           ; HEAD->NAME = global_token->S
	mov [ebp+24], eax           ; I->NAME = global_token->S

	mov [edx+12], ebp           ; HEAD->INDIRECT = I
	mov [ebp+12], edx           ; I->INDIRECT = HEAD

	mov eax, [global_types]     ; Using global_types
	mov [edx], eax              ; HEAD->NEXT = global_types
	mov [global_types], edx     ; global_types = HEAD

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, 4                  ; Using register size
	mov [ebp+4], eax            ; I->SIZE = register size

	mov eax, create_struct_string_0 ; Using "ERROR in create_struct\n Missing {\n"
	mov ebx, open_curly_brace   ; Using "{"
	call require_match          ; Make sure we have it

	mov esi, 0                  ; LAST = NULL

create_struct_iter:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; Make it useful
	cmp eax, 125                ; IF global_token->S[0] == "}"
	je create_struct_done       ; be done

	;; Looks like we are adding members
	;; Lets see if it is a union
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov ebx, union              ; Using "union"
	call match                  ; IF match(global_token->s, "union")
	cmp eax, 0                  ; Deal with union
	jne create_struct_single    ; Otherwise deal with singles

	;; Deal with union
	mov eax, esi                ; Put last in right place
	mov ebx, ecx                ; put offset in right place
	call build_union            ; ASSEMBLE
	mov esi, eax                ; last = build_union(last, offset)
	add ecx, edi                ; offset = offset + member_size

	mov eax, create_struct_string_1 ; Using "ERROR in create_struct\n Missing ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it
	jmp create_struct_iter      ; keep going

create_struct_single:
	;; deal with singles
	mov eax, esi                ; Put last in right place
	mov ebx, ecx                ; put offset in right place
	call build_member           ; ASSEMBLE
	mov esi, eax                ; last = build_union(last, offset)
	add ecx, edi                ; offset = offset + member_size

	mov eax, create_struct_string_1 ; Using "ERROR in create_struct\n Missing ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it
	jmp create_struct_iter      ; keep going

create_struct_done:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, create_struct_string_1 ; Using "ERROR in create_struct\n Missing ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it

	mov [edx+4], ecx            ; HEAD->SIZE = OFFSET
	mov [edx+16], esi           ; HEAD->MEMBERS = LAST
	mov [ebp+16], esi           ; I->MEMBERS = LAST

	pop esi                     ; Restore ESI
	pop edi                     ; Restore EDI
	pop ebp                     ; Restore EBP
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

create_struct_string_0: db "ERROR in create_struct", 10, " Missing {", 10, 0
create_struct_string_1: db "ERROR in create_struct", 10, " Missing ;", 10, 0


;; lookup_member function
;; Recieves struct type* parent in EAX and char* name in EBX
;; Returns struct type* I in EAX
;; Uses char* NAME in EBX, ECX for struct type* I and EDX to hold parent for errors
;; Aborts hard if not found
lookup_member:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov edx, eax                ; Protect Parent
	mov ecx, [eax+16]           ; struct type* I = parent->MEMBERS
lookup_member_iter:
	cmp ecx, 0                  ; IF I == NULL
	je lookup_member_fail       ; Abort HARD

	mov eax, [ecx+24]           ; Using I->NAME
	call match                  ; IF I->NAME == NAME
	cmp eax, 0                  ; Then we have found the member
	mov eax, ecx                ; Prepare for return
	mov ecx, [ecx+16]           ; Prepare for loop I = I->MEMBERS
	jne lookup_member_iter      ; Looks like we are looping

	;; I is already in EAX
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

lookup_member_fail:
	mov eax, 2                  ; Using Standard error
	mov [Output_file], eax      ; write to standard error
	mov eax, lookup_member_string_0 ; Using "ERROR in lookup_member "
	call File_Print             ; print it

	mov eax, [edx+24]           ; PARENT->NAME
	call File_Print             ; print it

	mov eax, arrow_string       ; Using "->"
	call File_Print             ; print it

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	call File_Print             ; print it

	mov eax, lookup_member_string_1 ; Using " does not exist\n"
	call File_Print             ; print it

;	call line_error             ; Write useful debug info

	mov eax, lookup_member_string_2 ; Using "\n"
	call File_Print             ; print it
	jmp Exit_Failure            ; Abort Hard

lookup_member_string_0: db "ERROR in lookup_member ", 0
lookup_member_string_1: db " does not exist", 10, 0
lookup_member_string_2: db 10, 0


;; build_member function
;; Recieves struct type* last in EAX, int offset in EBX and global member_size in EDI
;; Updates member_size in EDI and returns struct type* I in EAX
;; Uses ECX for struct type* member_type and EDX for struct type* I
build_member:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov edx, eax                ; Put last out of the way
	mov eax, 28                 ; Allocate type
	call malloc                 ; Get I
	mov [eax+16], edx           ; I->MEMBERS = LAST
	mov [eax+8], ebx            ; I->OFFSET = OFFSET
	mov edx, eax                ; Put I in place

	call type_name              ; Get member_type
	mov ecx, eax                ; Put in place
	mov [edx+20], ecx           ; I->TYPE = MEMBER_TYPE
	mov eax, [global_token]     ; Using global_token
	mov ebx, [eax+8]            ; global_token->S
	mov [edx+24], ebx           ; I->NAME = global_token->S
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	;; Check if we have an array
	mov ebx, [eax+8]            ; global_token->S
	mov eax, open_bracket       ; Using "["
	call match                  ; IF global_token->S == "["
	cmp eax, 0                  ; Then we have to deal with arrays in our structs
	je build_member_array       ; So deal with that pain

	;; Deal with non-array case
	mov eax, [ecx+4]            ; member_type->SIZE
	mov [edx+4], eax            ; I->SIZE = member_type->SIZE
	jmp build_member_done       ; Be done

build_member_array:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, [eax+8]            ; global_token->S
	call numerate_string        ; convert number
	mov ebx, [ecx+20]           ; member_type->TYPE
	mov ebx, [ebx+4]            ; member_type->TYPE->SIZE
	imul eax, ebx               ; member_type->type->size * numerate_string(global_token->s)
	mov [edx+4], eax            ; I->SIZE = member_type->type->size * numerate_string(global_token->s)

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, build_member_string_0 ; Using "Struct only supports [num] form\n"
	mov ebx, close_bracket      ; Using "]"
	call require_match          ; Make sure we have it

build_member_done:
	mov edi, [edx+4]            ; MEMBER_SIZE = I->SIZE
	mov [edx+20], ecx           ; I->TYPE = MEMBER_TYPE
	mov eax, edx                ; Return I

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

build_member_string_0: db "Struct only supports [num] form", 10, 0


;; build_union function
;; Recieves struct type* last in EAX, int offset in EBX and global member_size in EDI
;; Updates member_size in EDI and returns struct type* LAST in EAX
;; Uses ECX for struct type* last, EDX for int offset, ESI for int size and EDI for int member_size
build_union:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	push esi                    ; Protect ESI
	mov ecx, eax                ; Put LAST in right spot
	mov edx, ebx                ; Put OFFSET in right spot
	mov esi, 0                  ; SIZE = 0

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, build_union_string_0 ; Using "ERROR in build_union\nMissing {\n"
	mov ebx, open_curly_brace   ; Using "{"
	call require_match          ; Make sure we have it

build_union_iter:
	mov eax, [global_token]     ; Using global_token
	mov eax, [eax+8]            ; global_token->S
	mov al, [eax]               ; global_token->S[0]
	movzx eax, al               ; make it useful
	cmp eax, 125                ; IF global_token->S[0] == "}"
	je build_union_done         ; Be done

	;; Collect union member
	mov eax, ecx                ; Passing LAST
	mov ebx, edx                ; Passing offset
	call build_member           ; build_member(last, offset)
	mov ecx, eax                ; last = build_member(last, offset)

	cmp esi, edi                ; IF member_size > size
	jg build_union_size         ; Then update size

	;; deal with member_size > size
	mov esi, edi                ; SIZE = MEMBER_SIZE

build_union_size:
	mov eax, build_union_string_1 ; Using "ERROR in build_union\nMissing ;\n"
	mov ebx, semicolon          ; Using ";"
	call require_match          ; Make sure we have it
	jmp build_union_iter        ; Keep going

build_union_done:
	mov edi, esi                ; MEMBER_SIZE = SIZE

	mov eax, [global_token]     ; Using global_token
	mov eax, [eax]              ; global_token->NEXT
	mov [global_token], eax     ; global_token = global_token->NEXT

	mov eax, ecx                ; Return last

	pop esi                     ; Restore ESI
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

build_union_string_0: db "ERROR in build_union", 10, "Missing {", 10, 0
build_union_string_1: db "ERROR in build_union", 10, "Missing ;", 10, 0


;; sym_declare function
;; Recieves char *s in EAX, struct type* t in EBX, and struct token_list* list in ECX
;; Returns struct token_list* in EAX
;; Uses EAX for A
sym_declare:
	push edx                    ; Protect EDX
	mov edx, eax                ; Get char *S safely out of the way
	mov eax, 20                 ; Using sizeof(struct token_list)
	call malloc                 ; Get pointer to A
	mov [eax], ecx              ; A->NEXT = LIST
	mov [eax+8], edx            ; A->S = S
	mov [eax+12], ebx           ; A->TYPE = T
	pop edx                     ; Restore EDX
	ret


;; match function
;; Recieves CHAR* in EAX and CHAR* in EBX
;; Returns 0 (TRUE) or 1 (FALSE) in EAX
match:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov ecx, eax                ; S1 in place
	mov edx, ebx                ; S2 in place
match_Loop:
	mov al, [ecx]               ; S1[0]
	movzx eax, al               ; Make it useful
	mov bl, [edx]               ; S2[0]
	movzx ebx, bl               ; Make it useful
	cmp eax, ebx                ; See if they match
	jne match_False             ; If not

	add ecx, 1                  ; S1 = S1 + 1
	add edx, 1                  ; S2 = S2 + 1
	cmp eax, 0                  ; If reached end of string
	je match_Done               ; Perfect match
	jmp match_Loop              ; Otherwise keep looping

match_False:
	mov eax, 1                  ; Return false
match_Done:
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; numerate_number function
;; Recieves an INT A in EAX
;; Returns char* result in EAX
;; Allocates 16 bytes of memory
;; Behaves badly when given a negative number too large
;; Uses EAX for temp, EBX for DIVISOR, EDX for mod/0, ESI for result[i] and EBP for A
numerate_number:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	push esi                    ; Protect ESI
	push ebp                    ; Protect EBP
	mov ebp, eax                ; Protect A

	mov eax, 16                 ; 16bytes
	call malloc                 ; Get our pointer
	push eax                    ; Protect our pointer
	mov esi, eax                ; put pointer in right place
	mov ebx, 0x3B9ACA00         ; Set divisor to largest positive number that fits in 32bits

	cmp ebp, 0                  ; Deal with 0 case
	je numerate_number_ZERO     ; If it is
	jg numerate_number_positive ; If it is positive

	;; Deal with negative case
	mov eax, 45                 ; Using "-"
	mov [esi], al               ; Write it
	add esi, 1                  ; increment
	imul ebp, -1                ; A = A * -1

numerate_number_positive:
	mov edx, 0                  ; Set top to 0
	mov eax, ebp                ; Using A as bottom
	idiv ebx                    ; edx:eax % ebx -> edx + edx:eax / ebx -> eax [Even if we don't want it]
	cmp eax, 0                  ; IF 0 == (a / divisor)
	jne numerate_number_iter    ; Clean up those leading Zeros

	mov edx, 0                  ; Set top to 0
	mov eax, ebx                ; Using Divisor for bottom
	mov ebx, 10                 ; Make this shit work because idiv 10 doesn't work
	idiv ebx                    ; edx:eax % 10 -> edx + edx:eax / 10 -> eax [Even if we don't want it]
	mov ebx, eax                ; Update divisor
	jmp numerate_number_positive ; Keep collecting

numerate_number_iter:
	cmp ebx, 0                  ; IF DIVISOR < 0
	jle numerate_number_done    ; Be done

	mov edx, 0                  ; Set top to 0
	mov eax, ebp                ; Using A as bottom
	idiv ebx                    ; edx:eax % ebx -> edx + edx:eax / ebx -> eax [Even if we don't want it]
	add eax, 48                 ; ((a / divisor) + 48)
	mov [esi], al               ; Write it
	mov ebp, edx                ; a = a % divisor

	mov edx, 0                  ; Set top to 0
	mov eax, ebx                ; Using Divisor for bottom
	mov ebx, 10                 ; Make this shit work because idiv 10 doesn't work
	idiv ebx                    ; edx:eax % 10 -> edx + edx:eax / 10 -> eax [Even if we don't want it]
	mov ebx, eax                ; Update divisor

	add esi, 1                  ; increment
	jmp numerate_number_iter    ; Keep going

numerate_number_done:
	pop eax                     ; Restore our result
	pop ebp                     ; Restore EBP
	pop esi                     ; Restore ESI
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

numerate_number_ZERO:
	mov eax, 48                 ; Using '0'
	mov [esi], al               ; Write it
	add esi, 1                  ; increment
	jmp numerate_number_done    ; Be done


;; numerate_string function
;; Recieves CHAR* in EAX
;; Returns value of CHAR* in EAX
;; Uses EAX for VALUE, EBX for S, ECX for CH and ESI for NEGATIVE?
numerate_string:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	push esi                    ; Protect ESI
	mov ebx, eax                ; put S in correct place
	mov eax, 0                  ; Initialize to Zero
numerate_string_loop:
	mov cl, [ebx+1]             ; S[1]
	movzx ecx, cl               ; make it useful
	cmp ecx, 120                ; IF 'x' == S[1]
	je numerate_hex             ; Deal with hex input

	;; Assume decimal input
	mov esi, 0                  ; Assume no negation
	mov cl, [ebx]               ; S[0]
	movzx ecx, cl               ; make it useful
	cmp ecx, 45                 ; IF '-' == S[0]
	jne numerate_decimal        ; Skip negation

	mov esi, 1                  ; Set FLAG
	add ebx, 1                  ; S = S + 1

numerate_decimal:
	mov cl, [ebx]               ; S[0]
	movzx ecx, cl               ; make it useful
	cmp ecx, 0                  ; IF NULL == S[0]
	je numerate_decimal_done    ; We are done

	imul eax, 10                ; VALUE = VALUE * 10
	sub ecx, 48                 ; CH = CH - '0'
	cmp ecx, 9                  ; Check for illegal
	jg numerate_string_fail     ; If CH > '9'
	cmp ecx, 0                  ; Check for illegal
	jl numerate_string_fail     ; IF CH < 0
	add eax, ecx                ; VALUE = VALUE + CH
	add ebx, 1                  ; S = S + 1
	jmp numerate_decimal        ; Keep looping

numerate_decimal_done:
	cmp esi, 1                  ; Check if need to negate
	jne numerate_string_done    ; Nope

	imul eax, -1                ; VALUE = VALUE * -1
	jmp numerate_string_done    ; Done

numerate_hex:
	add ebx, 2                  ; S = S + 2
numerate_hex_loop:
	mov cl, [ebx]               ; S[0]
	movzx ecx, cl               ; make it useful
	cmp ecx, 0                  ; IF NULL == S[0]
	je numerate_string_done     ; We are done

	shl eax, 4                  ; VALUE = VALUE << 4
	sub ecx, 48                 ; CH = CH - '0'
	cmp ecx, 10                 ; IF 10 >= CH
	jl numerate_hex_digit       ; NO
	sub ecx, 7                  ; Push A-F into range
numerate_hex_digit:
	cmp ecx, 15                 ; Check for illegal
	jg numerate_string_fail     ; If CH > 'F'
	cmp ecx, 0                  ; Check for illegal
	jl numerate_string_fail     ; IF CH < 0
	add eax, ecx                ; VALUE = VALUE + CH
	add ebx, 1                  ; S = S + 1
	jmp numerate_hex_loop       ; Keep looping

numerate_string_fail:
	mov eax, 0                  ; return ZERO

numerate_string_done:
	pop esi                     ; Restore ESI
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; Exit_Failure function
;; Recieves nothing
;; And aborts hard
;; Does NOT return
Exit_Failure:
	mov ebx, 1                  ; All is wrong
	mov eax, 1                  ; put the exit syscall number in eax
	int 0x80                    ; Call it a bad day


;; Keywords
union: db "union", 0
struct: db "struct", 0
constant: db "CONSTANT", 0
main_string: db "main", 0
argc_string: db "argc", 0
argv_string: db "argv", 0
if_string: db "if", 0
else_string: db "else", 0
do_string: db "do", 0
while_string: db "while", 0
for_string: db "for", 0
asm_string: db "asm", 0
goto_string: db "goto", 0
return_string: db "return", 0
break_string: db "break", 0
continue_string: db "continue", 0
sizeof_string: db "sizeof", 0
plus_string: db "+", 0
minus_string: db "-", 0
multiply_string: db "*", 0
divide_string: db "/", 0
modulus_string: db "%", 0
left_shift_string: db "<<", 0
right_shift_string: db ">>", 0
less_than_string: db "<", 0
less_than_equal_string: db "<=", 0
greater_than_equal_string: db ">=", 0
greater_than_string: db ">", 0
equal_to_string: db "==", 0
not_equal_string: db "!=", 0
bitwise_and: db "&", 0
logical_and: db "&&", 0
bitwise_or: db "|", 0
logical_or: db "||", 0
bitwise_xor: db "^", 0
arrow_string: db "->", 0


;; Frequently Used strings
;; Generally used by require_match
open_curly_brace: db "{", 0
close_curly_brace: db "}", 0
open_paren: db "(", 0
close_paren: db ")", 0
open_bracket: db "[", 0
close_bracket: db "]", 0
comma: db ",", 0
semicolon: db ";", 0
equal: db "=", 0
percent: db "%", 0
newline: db "\n", 0
underline: db "_", 0


prim_types:
type_void:
	dd type_int                 ; NEXT
	dd 4                        ; SIZE
	dd 0                        ; OFFSET
	dd type_void                ; INDIRECT
	dd 0                        ; MEMBERS
	dd type_void                ; TYPE
	dd type_void_name           ; NAME
type_void_name: db "void", 0

type_int:
	dd type_char                ; NEXT
	dd 4                        ; SIZE
	dd 0                        ; OFFSET
	dd type_int                 ; INDIRECT
	dd 0                        ; MEMBERS
	dd type_int                 ; TYPE
	dd type_int_name            ; NAME
type_int_name: db "int", 0

type_char:
	dd type_file                ; NEXT
	dd 1                        ; SIZE
	dd 0                        ; OFFSET
	dd type_char_indirect       ; INDIRECT
	dd 0                        ; MEMBERS
	dd type_char                ; TYPE
	dd type_char_name           ; NAME
type_char_name: db "char", 0

type_char_indirect:
	dd type_file                ; NEXT
	dd 4                        ; SIZE
	dd 0                        ; OFFSET
	dd type_char_double_indirect ; INDIRECT
	dd 0                        ; MEMBERS
	dd type_char_indirect       ; TYPE
	dd type_char_indirect_name  ; NAME
type_char_indirect_name: db "char*", 0

type_char_double_indirect:
	dd type_file                ; NEXT
	dd 4                        ; SIZE
	dd 0                        ; OFFSET
	dd type_char_double_indirect ; INDIRECT
	dd 0                        ; MEMBERS
	dd type_char_indirect       ; TYPE
	dd type_char_double_indirect_name ; NAME
type_char_double_indirect_name: db "char**", 0

type_file:
	dd type_function            ; NEXT
	dd 4                        ; SIZE
	dd 0                        ; OFFSET
	dd type_file                ; INDIRECT
	dd 0                        ; MEMBERS
	dd type_file                ; TYPE
	dd type_file_name           ; NAME
type_file_name: db "FILE", 0

type_function:
	dd type_unsigned            ; NEXT
	dd 4                        ; SIZE
	dd 0                        ; OFFSET
	dd type_function            ; INDIRECT
	dd 0                        ; MEMBERS
	dd type_function            ; TYPE
	dd type_function_name       ; NAME
type_function_name: db "FUNCTION", 0

type_unsigned:
	dd 0                        ; NEXT
	dd 4                        ; SIZE
	dd 0                        ; OFFSET
	dd type_unsigned            ; INDIRECT
	dd 0                        ; MEMBERS
	dd type_unsigned            ; TYPE
	dd type_unsigned_name       ; NAME
type_unsigned_name: db "unsigned", 0


;; debug_list function
;; Recieves struct token_list* in EAX
;; Prints contents of list and exits
;; Does NOT return
debug_list:
	mov ebp, eax                ; Protect the list pointer
	mov eax, 2                  ; Using Standard error
	mov [Output_file], eax      ; write to standard error

debug_list_iter:
	;; Header
	mov eax, debug_list_string0 ; Using our first string
	call File_Print             ; Print it
	mov eax, ebp                ; Use address of pointer
	call numerate_number        ; Convert it into string
	call File_Print             ; Print it

	;; NEXT
	mov eax, debug_list_string1 ; Using our second string
	call File_Print             ; Print it
	mov eax, [ebp]              ; Use address of pointer
	call numerate_number        ; Convert it into string
	call File_Print             ; Print it

	;; PREV
	mov eax, debug_list_string2 ; Using our third string
	call File_Print             ; Print it
	mov eax, [ebp+4]            ; Use address of pointer
	call numerate_number        ; Convert it into string
	call File_Print             ; Print it

	;; S
	mov eax, debug_list_string3 ; Using our fourth string
	call File_Print             ; Print it
	mov eax, [ebp+8]               ; Use address of pointer
	call numerate_number        ; Convert it into string
	call File_Print             ; Print it

	;; S Contents
	mov eax, debug_list_string4 ; Using our fifth string
	call File_Print             ; Print it
	mov eax, [ebp+8]            ; Use address of string
	cmp eax, 0                  ; IF NULL Pointer
	jne debug_list_null         ; otherwise display
	mov eax, debug_list_string_null ; Give meaningful message instead
debug_list_null:
	call File_Print             ; Print it

	;; TYPE
	mov eax, debug_list_string5 ; Using our sixth string
	call File_Print             ; Print it
	mov eax, [ebp+12]           ; Use address of pointer
	call numerate_number        ; Convert it into string
	call File_Print             ; Print it

	;; ARGS/DEPTH
	mov eax, debug_list_string6 ; Using our third string
	call File_Print             ; Print it
	mov eax, [ebp+16]           ; Use address of pointer
	call numerate_number        ; Convert it into string
	call File_Print             ; Print it

	mov eax, 10                 ; Add "\n"
	call fputc                  ; print it
	call fputc                  ; print it

	mov ebp, [ebp]              ; TOKEN = TOKEN->NEXT
	cmp ebp, 0                  ; Check if NULL
	jne debug_list_iter         ; iterate otherwise

	mov ebx, 666                ; All is HELL
	mov eax, 1                  ; put the exit syscall number in eax
	int 0x80                    ; Call it a bad day

debug_list_string0: db "Token_list node at address: ", 0
debug_list_string1: db 10, "NEXT address: ", 0
debug_list_string2: db 10, "PREV address: ", 0
debug_list_string3: db 10, "S address: ", 0
debug_list_string4: db 10, "The contents of S are: ", 0
debug_list_string5: db 10, "TYPE address: ", 0
debug_list_string6: db 10, "ARGUMENTS address: ", 0
debug_list_string_null: db ">::<NULL>::<", 0


section .data
Address_of: dd 0
C: dd 0
Input_file: dd 0
MALLOC: dd 0
Output_file: dd 0
Token: dd 0
break_frame: dd 0
break_target_func: dd 0
break_target_head: dd 0
break_target_num: dd 0
current_count: dd 0
current_target: dd 0
function: dd 0
global_constant_list: dd 0
global_function_list: dd 0
global_symbol_list: dd 0
global_token: dd 0
global_types: dd prim_types
globals_list: dd 0
output_list: dd 0
string_index: dd 0
strings_list: dd 0
