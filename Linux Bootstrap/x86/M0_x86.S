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
	;; EAX, ECX, EBX => Temps
	;; EDI => MALLOC
	;; EBP => HEAD
	;; [Output] => Output_file
	;; [Input] => Input_file

	;; Struct format: (size 32)
	;; NEXT => 0
	;; TYPE => 8
	;; TEXT => 16
	;; EXPRESSION => 24

	;; Types
	;; None => 0
	;; MACRO => 1
	;; STRING => 2

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
	mov [Input], eax            ; Preserve the file pointer we were given

	pop ebx                     ;·Get·the·actual·output name
	mov ecx, 577                ; Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov edx, 384                ; Prepare file as RW for owner only (600 in octal)
	mov eax, 5                  ;·the·syscall·number·for·open()
	int 0x80                    ; Now open that damn file
	cmp eax, 0                  ; Check for missing output
	jg _start_out               ; Have real input
	mov eax, 1                  ; Use stdout

_start_out:
	mov [Output], eax           ; Preserve the file pointer we were given

	mov eax, 45                 ; the Syscall # for SYS_BRK
	mov ebx, 0                  ; Get current brk
	int 0x80                    ; Let the kernel do the work
	mov edi, eax                ; Set our malloc pointer

	call Tokenize_Line          ; Get all lines
	mov eax, ebp                ; prepare for Reverse_List
	call Reverse_List           ; Correct order
	mov ebp, eax                ; Update HEAD
	call Identify_Macros        ; Find the DEFINEs
	call Line_Macro             ; Apply the DEFINEs
	call Process_String         ; Handle strings
	call Eval_Immediates        ; Handle Numbers
	call Preserve_Other         ; Collect the remaining
	call Print_Hex              ; Output our results

Done:
	; program completed Successfully
	mov ebx, 0                  ; All is well
	mov eax, 1                  ; put the exit syscall number in eax
	int 0x80                    ; Call it a good day


;; Tokenize_Line Function
;; Using input file [Input] and Head EBP
;; Creates a linked list of structs
;; Uses EBX for in_set strings, ECX for Int C and EDX for Struct Token* p
Tokenize_Line:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
restart:
	call fgetc                  ; Read a char
	cmp eax, -4                 ; Check for EOF
	je done                     ; File is collected

	movzx eax, al               ; We have to zero extend it to use it
	mov ecx, eax                ; Protect C

	mov ebx, comments           ; Get pointer to "#;"
	call In_Set                 ; Check for comments
	cmp eax, 1                  ; If comments
	je Purge_LineComment        ; try again

	mov eax, ecx                ; put C in place for check
	mov ebx, terminators        ; Get pointer to "\n\t "
	call In_Set                 ; Check for terminators
	cmp eax, 1                  ; If terminator
	je restart                  ; try again

	mov eax, 32                 ; Malloc the struct P
	call malloc                 ; Get pointer to P
	mov edx, eax                ; Protect P
	mov [edx], ebp              ; P->NEXT = HEAD
	mov ebp, edx                ; HEAD = P

	mov eax, ecx                ; put C in place for check
	mov ebx, string_char        ; Get pointer to "\"'"
	call In_Set                 ; Check for string chars
	cmp eax, 1                  ; If string char
	je Store_String             ; Get string

	call Store_Atom             ; Get whole token
	jmp restart

done:
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; fgetc function
;; Receives FILE* in [Input]
;; Returns -4 (EOF) or char in EAX
fgetc:
	push edx                    ; Protect EDX
	push ecx                    ; Protect ECX
	push ebx                    ; Protect EBX
	mov eax, -4                 ; Put EOF in eax
	push eax                    ; Assume bad (If nothing read, value will remain EOF)
	lea ecx, [esp]              ; Get stack address
	mov ebx, [Input]            ; Where are we reading from
	mov eax, 3                  ; the syscall number for read
	mov edx,  1                 ; set the size of chars we want
	int 0x80                    ; call the Kernel
	pop eax                     ; Get either char or EOF
	pop ebx                     ; Restore EBX
	pop ecx                     ; Restore ECX
	pop edx                     ; Restore EDX
	ret


;; Malloc isn't actually required if the program being built fits in the initial memory
;; However, it doesn't take much to add it.
;; Requires EDI to be initialized and EAX to have the number of desired bytes
malloc:
	push edx                    ; Protect EDX
	push ecx                    ; Protect ECX
	push ebx                    ; Protect EBX

	mov ebx, edi                ; Using the current pointer
	add ebx, eax                ; Request the number of desired bytes
	mov eax, 45                 ; the Syscall # for SYS_BRK
	int 0x80                    ; call the Kernel
	mov eax, edi                ; Return pointer
	mov edi, ebx                ; Update pointer

	pop ebx                     ; Restore EBX
	pop ecx                     ; Restore ECX
	pop edx                     ; Restore EDX
	ret


;; Purge_LineComment function
;; Reads chars until LF and jumps to restart
Purge_LineComment:
	call fgetc                  ; Get a char
	movzx eax, al               ; Zero extend
	cmp eax, 10                 ; While not LF
	jne Purge_LineComment       ; Keep reading
	jmp restart


;; Store_String Function
;; Receives C in ECX, HEAD in EDX and Input file in [Output]
;; Uses EBX for terminator, ECX for C and EDX for string
Store_String:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX

	mov eax, 2                  ; Using TYPE STRING
	mov [edx+8], eax            ; HEAD->TYPE = STRING
	mov eax, 256                ; Malloc the string
	call malloc                 ; Get pointer to P
	mov [edx+16], eax           ; HEAD->TEXT = STRING
	mov ebx, ecx                ; Protect terminator
	mov edx, eax                ; Protect string pointer
Store_String_Loop:
	mov [edx], cl               ; write byte
	call fgetc                  ; read next char
	movzx eax, al               ; Zero extend it
	mov ecx, eax                ; Update C
	add edx, 1                  ; STRING = STRING + 1
	cmp ecx, ebx                ; See if we hit terminator
	jne Store_String_Loop       ; Otherwise keep looping

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	mov eax, edx                ; return HEAD
	jmp restart


;; Store_Atom Function
;; Receives C in ECX, HEAD in EDX and Input file in [Input]
;; Uses EBX for in_set strings, ECX for C and EDX for string
Store_Atom:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX

	mov eax, 256                ; Malloc the string
	call malloc                 ; Get pointer to P
	mov [edx+16], eax           ; HEAD->TEXT = STRING
	mov ebx, terminators        ; Get pointer to "\n\t "
	mov edx, eax                ; Protect string pointer
Store_Atom_loop:
	mov [edx], cl               ; write byte
	call fgetc                  ; read next char
	movzx eax, al               ; Zero extend it
	mov ecx, eax                ; Update C
	add edx, 1                  ; STRING = STRING + 1
	call In_Set                 ; Check for terminators
	cmp eax, 0                  ; Check for "\n\t "
	je Store_Atom_loop          ; Loop otherwise

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	mov eax, edx                ; return HEAD
	ret


;; In_Set function
;; Receives Char C in EAX and CHAR* in EBX
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

;; Char sets
terminators:
	db 10, 9, 32, 0

comments:
	db 35, 59, 0

string_char:
	db 34, 39, 0


;; Reverse_List function
;; Receives List in EAX
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


;; Identify_Macros function
;; Receives List in EAX
;; Updates the list in place; does not modify registers
;; Uses EBX for DEFINE, ECX for I
Identify_Macros:
	push eax                    ; Protect EAX
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov ebx, DEFINE_str         ; Setup define string
	mov ecx, eax                ; I = HEAD
Identify_Macros_Loop:
	mov eax, [ecx+16]           ; I->TEXT
	call match                  ; IF "DEFINE" == I->TEXT
	cmp eax, 0                  ; Check if match
	jne Identify_Macros_Next    ; Skip the work

	;; Deal with MACRO
	mov eax, 1                  ; Using MACRO
	mov [ecx+8], eax            ; I->TYPE = MACRO

	mov eax, [ecx]              ; I->NEXT
	mov eax, [eax+16]           ; I->NEXT->TEXT
	mov [ecx+16], eax           ; I->TEXT = I->NEXT->TEXT

	mov eax, [ecx]              ; I->NEXT
	mov eax, [eax]              ; I->NEXT->NEXT
	mov eax, [eax+16]           ; I->NEXT->NEXT->TEXT
	mov [ecx+24], eax           ; I->EXPRESSION = I->NEXT->NEXT->TEXT

	mov eax, [ecx]              ; I->NEXT
	mov eax, [eax]              ; I->NEXT->NEXT
	mov eax, [eax]              ; I->NEXT->NEXT->NEXT
	mov [ecx], eax              ; I->NEXT = I->NEXT->NEXT->NEXT

Identify_Macros_Next:
	mov ecx, [ecx]              ; I = I->NEXT
	cmp ecx, 0                  ; Check for NULL
	jne Identify_Macros_Loop    ; Keep looping otherwise

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	pop eax                     ; Restore EAX
	ret

DEFINE_str:
	db 68, 69, 70, 73, 78, 69, 0


;; match function
;; Receives CHAR* in EAX and CHAR* in EBX
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


;; Line_Macro function
;; Receives List in EAX
;; Updates the list in place; does not modify registers
;; Uses EAX for I, EBX for I->TEXT, ECX for I->EXPRESSION
Line_Macro:
	push eax                    ; Protect EAX
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
Line_Macro_Loop:
	mov ebx, [eax+8]            ; I->TYPE
	cmp ebx, 1                  ; IF MACRO == I->TYPE
	jne Line_Macro_Next         ; Otherwise move on

	;; Is a macro apply
	mov ebx, [eax+16]           ; I->TEXT
	mov ecx, [eax+24]           ; I->EXPRESSION
	mov eax, [eax]              ; I->NEXT
	call Set_Expression         ; Apply it
	jmp Line_Macro_Loop         ; Move on to next

Line_Macro_Next:
	mov eax, [eax]              ; I->NEXT
	cmp eax, 0                  ; Check for NULL
	jne Line_Macro_Loop         ; Keep going

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	pop eax                     ; Restore EAX
	ret


;; Set_Expression function
;; Receives List in EAX, CHAR* in EBX and CHAR* in ECX
;; Updates the list in place; does not modify registers
;; Uses EBX for C, ECX for EXP and EDX for I
Set_Expression:
	push eax                    ; Protect EAX
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov edx, eax                ; Set I
Set_Expression_Loop:
	mov eax, [edx+8]            ; I->TYPE
	cmp eax, 1                  ; IF MACRO == I->TYPE
	je Set_Expression_Next      ; Ignore and move on

	mov eax, [edx+16]           ; I->TEXT
	call match                  ; Check for match
	cmp eax, 0                  ; If match
	jne Set_Expression_Next     ; Otherwise next

	;; We have a non-macro match
	mov [edx+24], ecx           ; I->EXPRESSION = EXP

Set_Expression_Next:
	mov edx, [edx]              ; I = I->NEXT
	cmp edx, 0                  ; IF NULL == I
	jne Set_Expression_Loop     ; Otherwise keep looping

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	pop eax                     ; Restore EAX
	ret


;; Process_String function
;; Receives List in EAX
;; Update the list in place; does not modify registers
;; Uses EBX for I->TEXT, ECX for I and EDX for S
Process_String:
	push eax                    ; Protect EAX
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov ecx, eax                ; I = HEAD
Process_String_loop:
	mov eax, [ecx+8]            ; I->TYPE
	cmp eax, 2                  ; IF STRING == I->TYPE
	jne Process_String_Next     ; Skip to next

	mov ebx, [ecx+16]           ; I->TEXT
	mov al, [ebx]               ; I->TEXT[0]
	movzx eax, al               ; make it useful
	cmp eax, 39                 ; IF '\'' == I->TEXT[0]
	jne Process_String_Raw      ; Deal with '"'

	;; Deal with '\''
	add ebx, 1                  ; I->TEXT + 1
	mov [ecx+24], ebx           ; I->EXPRESSION = I->TEXT + 1
	jmp Process_String_Next     ; Move on to next

Process_String_Raw:
	mov eax, ebx                ; Get length of I->TEXT
	call string_length          ; Do it
	shr eax, 2                  ; LENGTH = LENGTH >> 2
	add eax, 1                  ; LENGTH = LENGTH + 1
	shl eax, 3                  ; LENGTH = LENGTH << 3
	call malloc                 ; Get string
	mov edx, ebx                ; S = I->TEXT
	add edx, 1                  ; S = S + 1
	mov [ecx+24], eax           ; I->EXPRESSION = hexify
	mov ebx, eax                ; Put hexify buffer in ebx

Process_String_Raw_Loop:
	mov al, [edx]               ; Read 1 chars
	movzx eax, al               ; Make it useful
	add edx, 1                  ; S = S + 1
	cmp al, 0                   ; Check for NULL
	pushf                       ; Protect condition
	call hex8                   ; write them all
	popf                        ; restore condition
	jne Process_String_Raw_Loop ; Keep looping

Process_String_Next:
	mov ecx, [ecx]              ; I = I->NEXT
	cmp ecx, 0                  ; IF NULL == I
	jne Process_String_loop     ; Otherwise keep looping

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	pop eax                     ; Restore EAX
	ret


;; string_length function
;; Receives CHAR* in EAX
;; Returns INT in EAX
;; Uses EAX for CH, EBX for S and ECX for INDEX
string_length:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ebx, eax                ; Set S
	mov ecx, 0                  ; INDEX = 0
string_length_loop:
	mov al, [ebx+ecx]           ; S[0]
	movzx eax, al               ; make it useful
	cmp eax, 0                  ; IF NULL == S[0]
	je string_length_done       ; Stop

	add ecx, 1                  ; INDEX = INDEX + 1
	jmp string_length_loop      ; Keep going

string_length_done:
	mov eax, ecx                ; RETURN INDEX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; Eval_Immediates function
;; Receives List in EAX
;; Updates the list in place; does not modify registers
;; Uses EBX for I->TEXT[0], ECX for I->TEXT[1] and EDX for I
Eval_Immediates:
	push eax                    ; Protect EAX
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov edx, eax                ; I = HEAD
Eval_Immediates_Loop:
	;; Check for MACRO
	mov eax, [edx+8]            ; I->TYPE
	cmp eax, 1                  ; IF MACRO == I-TYPE
	je Eval_Immediates_Next     ; Skip to next

	;; Check for NULL EXPRESSION
	mov eax, [edx+24]           ; I->EXPRESSION
	cmp eax, 0                  ; IF NULL == I->EXPRESSION
	jne Eval_Immediates_Next    ; Skip to next

	;; Check if number
	mov eax, [edx+16]           ; I->TEXT
	mov bl, [eax]               ; I->TEXT[0]
	movzx ebx, bl               ; Extend to use
	add eax, 1                  ; I->TEXT + 1
	mov cl, [eax]               ; I->TEXT[1]
	movzx ecx, cl               ; Extend to use
	call numerate_string        ; Convert string to INT
	cmp eax, 0                  ; IF 0 == numerate_number(I->TEXT + 1)
	jne Eval_Immediates_value   ; Has a value

	;; Last chance for Immediate
	cmp ecx, 48                 ; If '0' == I->TEXT[1]
	jne Eval_Immediates_Next    ; Skip to next

Eval_Immediates_value:
	call express_number         ; Convert value to hex string
	mov [edx+24], eax           ; I->EXPRESSION = express_number(value, I-TEXT[0])

Eval_Immediates_Next:
	mov edx, [edx]              ; I = I->NEXT
	cmp edx, 0                  ; IF NULL == I
	jne Eval_Immediates_Loop    ; Otherwise keep looping

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	pop eax                     ; Restore EAX
	ret


;; numerate_string function
;; Receives CHAR* in EAX
;; Returns value of CHAR* in EAX
;; Uses EAX for VALUE, EBX for S, ECX for CH and EDI for NEGATIVE?
numerate_string:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	push edi                    ; Protect EDI
	mov ebx, eax                ; put S in correct place
	mov eax, 0                  ; Initialize to Zero
numerate_string_loop:
	mov cl, [ebx+1]             ; S[1]
	movzx ecx, cl               ; make it useful
	cmp ecx, 120                ; IF 'x' == S[1]
	je numerate_hex             ; Deal with hex input

	;; Assume decimal input
	mov ecx, 0                  ; Assume no negation
	mov cl, [ebx]               ; S[0]
	movzx ecx, cl               ; make it useful
	cmp ecx, 45                 ; IF '-' == S[0]
	jne numerate_decimal        ; Skip negation

	mov edi, 1                  ; Set FLAG
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
	cmp edi, 1                  ; Check if need to negate
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
	pop edi                     ; Restore EDI
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; express_number function
;; Receives INT in EAX and CHAR in EBX
;; Allocates a string and expresses the value in hex
;; Returns string in EAX
;; Uses EAX for VALUE, EBX for S and ECX for CH
express_number:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
	mov ecx, ebx                ; Put CH in right place
	mov ebx, eax                ; Protect VALUE
	cmp ecx, 37                 ; IF '%' == CH
	jne express_number2         ; Otherwise try @

	mov eax, 9                  ; We need 3bytes
	call malloc                 ; Get S pointer
	xchg eax, ebx               ; Put S and VALUE in place
	push ebx                    ; Protect S
	call hex32l                 ; Store 32bits
	jmp express_number_done     ; done

express_number2:
	cmp ecx, 64                 ; IF '@' == CH
	jne express_number1         ; Othrewise try !

	mov eax, 5                  ; We need 3bytes
	call malloc                 ; Get S pointer
	xchg eax, ebx               ; Put S and VALUE in place
	push ebx                    ; Protect S
	call hex16l                 ; Store 16bits
	jmp express_number_done     ; done

express_number1:
	mov eax, 3                  ; We need 3bytes
	call malloc                 ; Get S pointer
	xchg eax, ebx               ; Put S and VALUE in place
	push ebx                    ; Protect S
	call hex8                   ; Store 8bit

express_number_done:
	pop eax                     ; Restore S
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; HEX to ascii routine
;; Receives INT in EAX and CHAR* in EBX
;; Stores ascii of INT in CHAR*
;; Returns only modifying EAX
hex64l:
	push eax                    ; Protect top 32
	call hex32l                  ; Store it
	pop eax                     ; do top 32
	shr eax, 32                 ; do bottom 32 first
hex32l:
	push eax                    ; Protect top 16
	call hex16l                  ; Store it
	pop eax                     ; do top 16
	shr eax, 16                 ; do bottom 16 first
hex16l:
	push eax                    ; Protect top byte
	call hex8                   ; Store it
	pop eax                     ; do high byte
	shr eax, 8                  ; do bottom byte first
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
	mov [ebx], al               ; store result
	add ebx, 1                  ; next position
	ret


;; Preserve_Other function
;; Receives List in EAX
;; Updates the list in place; does not modify registers
;; Uses EAX for I, EBX for I->TEXT
Preserve_Other:
	push eax                    ; Protect EAX
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	push edx                    ; Protect EDX
Preserve_Other_Loop:
	mov ebx, [eax+24]           ; I->EXPRESSION
	cmp ebx, 0                  ; IF NULL == I->EXPRESSION
	jne Preserve_Other_Next     ; Otherwise next

	;; Needs preserving
	mov ebx, [eax+16]           ; I->TEXT
	mov [eax+24], ebx           ; I->EXPRESSION = I->TEXT

Preserve_Other_Next:
	mov eax, [eax]              ; I = I->NEXT
	cmp eax, 0                  ; IF NULL == I
	jne Preserve_Other_Loop     ; Otherwise keep looping

	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	pop eax                     ; Restore EAX
	ret


;; Print_Hex function
;; Receives list in EAX
;; walks the list and prints the I->EXPRESSION for all nodes followed by newline
;; Uses EBX for I
Print_Hex:
	push ebx                    ; Protect EBX
	push ecx                    ; Protect ECX
	mov ebx, ebp                ; I = Head
Print_Hex_Loop:
	mov eax, [ebx+8]            ; I->TYPE
	cmp eax, 1                  ; IF MACRO == I->TYPE
	je Print_Hex_Next           ; Skip

	mov eax, [ebx + 24]         ; Using EXPRESSION
	call File_Print             ; Print it
	mov eax, 10                 ; NEWLINE
	call fputc                  ; Append it

Print_Hex_Next:
	mov ebx, [ebx]              ; Iterate to next Token
	cmp ebx, 0                  ; Check for NULL
	jne Print_Hex_Loop          ; Otherwise keep looping

	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret


;; File_Print function
;; Receives CHAR* in EAX
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
;; receives CHAR in EAX and FILE* in [Output]
;; writes char and returns
fputc:
	push edx                    ; Protect EDX
	push ecx                    ; protect ECX
	push ebx                    ; protect EBX
	push eax                    ; We are writing eax
	lea ecx, [esp]              ; Get stack address
	mov ebx, [Output]           ; Write to target file
	mov eax, 4                  ; the syscall number for write
	mov edx, 1                  ; set the size of chars we want
	int 0x80                    ; call the Kernel
	pop eax                     ; Restore stack
	pop ebx                     ; Restore EBX
	pop ecx                     ; Restore ECX
	pop edx                     ; Restore EDX
	ret

section .data
Input:
	dd 0
Output:
	dd 0
