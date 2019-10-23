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
	;; RAX, RSI, RDI => Temps
	;; R12 => MALLOC
	;; R13 => HEAD
	;; R14 => Output_file
	;; R15 => Input_file

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
	pop rax                     ;·Get·the·number·of·arguments
	pop rdi                     ;·Get·the·program·name
	pop rdi                     ;·Get·the·actual·input name
	mov rsi, 0                  ;·prepare·read_only
	mov rax, 2                  ;·the·syscall·number·for·open()
	syscall                     ; Now open that damn file
	mov r15, rax                ; Preserve the file pointer we were given

	pop rdi                     ;·Get·the·actual·output name
	mov rsi, 577                ; Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov rdx, 384                ; Prepare file as RW for owner only (600 in octal)
	mov rax, 2                  ;·the·syscall·number·for·open()
	syscall                     ; Now open that damn file
	cmp rax, 0                  ; Check for missing output
	jg _start_out               ; Have real input
	mov rax, 1                  ; Use stdout

_start_out:
	mov r14, rax                ; Preserve the file pointer we were given

	mov rax, 12                 ; the Syscall # for SYS_BRK
	mov rdi, 0                  ; Get current brk
	syscall                     ; Let the kernel do the work
	mov r12, rax                ; Set our malloc pointer

	call Tokenize_Line          ; Get all lines
	mov rax, r13                ; prepare for Reverse_List
	call Reverse_List           ; Correct order
	mov r13, rax                ; Update HEAD
	call Identify_Macros        ; Find the DEFINEs
	call Line_Macro             ; Apply the DEFINEs
	call Process_String         ; Handle strings
	call Eval_Immediates        ; Handle Numbers
	call Preserve_Other         ; Collect the remaining
	call Print_Hex              ; Output our results

Done:
	; program completed Successfully
	mov rdi, 0                  ; All is well
	mov rax, 0x3c               ; put the exit syscall number in eax
	syscall                     ; Call it a good day


;; Tokenize_Line Function
;; Using input file R15 and Head R13
;; Creates a linked list of structs
;; Uses RBX for in_set strings, RCX for Int C and RDX for Struct Token* p
Tokenize_Line:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
restart:
	call fgetc                  ; Read a char
	cmp rax, -4                 ; Check for EOF
	je done                     ; File is collected

	movzx rax, al               ; We have to zero extend it to use it
	mov rcx, rax                ; Protect C

	mov rbx, comments           ; Get pointer to "#;"
	call In_Set                 ; Check for comments
	cmp rax, 1                  ; If comments
	je Purge_LineComment        ; try again

	mov rax, rcx                ; put C in place for check
	mov rbx, terminators        ; Get pointer to "\n\t "
	call In_Set                 ; Check for terminators
	cmp rax, 1                  ; If terminator
	je restart                  ; try again

	mov rax, 32                 ; Malloc the struct P
	call malloc                 ; Get pointer to P
	mov rdx, rax                ; Protect P
	mov [rdx], r13              ; P->NEXT = HEAD
	mov r13, rdx                ; HEAD = P

	mov rax, rcx                ; put C in place for check
	mov rbx, string_char        ; Get pointer to "\"'"
	call In_Set                 ; Check for string chars
	cmp rax, 1                  ; If string char
	je Store_String             ; Get string

	call Store_Atom             ; Get whole token
	jmp restart

done:
	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; fgetc function
;; Receives FILE* in R15
;; Returns -4 (EOF) or char in RAX
fgetc:
	mov rax, -4                 ; Put EOF in rax
	push rax                    ; Assume bad (If nothing read, value will remain EOF)
	lea rsi, [rsp]              ; Get stack address
	mov rdi, r15                ; Where are we reading from
	mov rax, 0                  ; the syscall number for read
	push rdx                    ; Protect RDX
	mov rdx,  1                 ; set the size of chars we want
	push r11                    ; Protect r11
	syscall                     ; call the Kernel
	pop r11                     ; Restore r11
	pop rdx                     ; Restore RDX
	pop rax                     ; Get either char or EOF
	ret


;; Malloc isn't actually required if the program being built fits in the initial memory
;; However, it doesn't take much to add it.
;; Requires R12 to be initialized and RAX to have the number of desired bytes
malloc:
	mov rdi, r12                ; Using the current pointer
	add rdi, rax                ; Request the number of desired bytes
	mov rax, 12                 ; the Syscall # for SYS_BRK
	push rcx                    ; Protect rcx
	push r11                    ; Protect r11
	syscall                     ; call the Kernel
	pop r11                     ; Restore r11
	pop rcx                     ; Restore rcx
	mov rax, r12                ; Return pointer
	mov r12, rdi                ; Update pointer
	ret


;; Purge_LineComment function
;; Reads chars until LF and jumps to restart
Purge_LineComment:
	call fgetc                  ; Get a char
	movzx rax, al               ; Zero extend
	cmp rax, 10                 ; While not LF
	jne Purge_LineComment       ; Keep reading
	jmp restart


;; Store_String Function
;; Receives C in RCX, HEAD in RDX and Input file in R14
;; Uses RBX for terminator, RCX for C and RDX for string
Store_String:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX

	mov rax, 2                  ; Using TYPE STRING
	mov [rdx+8], rax            ; HEAD->TYPE = STRING
	mov rax, 256                ; Malloc the string
	call malloc                 ; Get pointer to P
	mov [rdx+16], rax           ; HEAD->TEXT = STRING
	mov rbx, rcx                ; Protect terminator
	mov rdx, rax                ; Protect string pointer
Store_String_Loop:
	mov [rdx], cl               ; write byte
	call fgetc                  ; read next char
	movzx rax, al               ; Zero extend it
	mov rcx, rax                ; Update C
	add rdx, 1                  ; STRING = STRING + 1
	cmp rcx, rbx                ; See if we hit terminator
	jne Store_String_Loop       ; Otherwise keep looping

	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	mov rax, rdx                ; return HEAD
	jmp restart


;; Store_Atom Function
;; Receives C in RCX, HEAD in RDX and Input file in R15
;; Uses RBX for in_set strings, RCX for C and RDX for string
Store_Atom:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX

	mov rax, 256                ; Malloc the string
	call malloc                 ; Get pointer to P
	mov [rdx+16], rax           ; HEAD->TEXT = STRING
	mov rbx, terminators        ; Get pointer to "\n\t "
	mov rdx, rax                ; Protect string pointer
Store_Atom_loop:
	mov [rdx], cl               ; write byte
	call fgetc                  ; read next char
	movzx rax, al               ; Zero extend it
	mov rcx, rax                ; Update C
	add rdx, 1                  ; STRING = STRING + 1
	call In_Set                 ; Check for terminators
	cmp rax, 0                  ; Check for "\n\t "
	je Store_Atom_loop          ; Loop otherwise

	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	mov rax, rdx                ; return HEAD
	ret


;; In_Set function
;; Receives Char C in RAX and CHAR* in RBX
;; Returns 1 if true, zero if false in RAX
In_Set:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
In_Set_loop:
	mov cl, [rbx]               ; Read char
	movzx rcx, cl               ; Zero extend it

	cmp rax, rcx                ; See if they match
	je In_Set_True              ; return true

	cmp rcx, 0                  ; Check for NULL
	je In_Set_False             ; return false

	add rbx, 1                  ; s = s + 1
	jmp In_Set_loop             ; Keep looping

In_Set_True:
	mov rax, 1                  ; Set True
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret

In_Set_False:
	mov rax, 0                  ; Set FALSE
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret

;; Char sets
terminators:
	db 10, 9, 32, 0

comments:
	db 35, 59, 0

string_char:
	db 34, 39, 0


;; Reverse_List function
;; Receives List in RAX
;; Returns the list reversed in RAX
Reverse_List:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rbx, rax                ; Set HEAD
	mov rax, 0                  ; ROOT = NULL
Reverse_List_Loop:
	cmp rbx, 0                  ; WHILE HEAD != NULL
	je Reverse_List_Done        ; Stop otherwise

	mov rcx, [rbx]              ; NEXT = HEAD->NEXT
	mov [rbx], rax              ; HEAD->NEXT = ROOT
	mov rax, rbx                ; ROOT = HEAD
	mov rbx, rcx                ; HEAD = NEXT
	jmp Reverse_List_Loop       ; Keep Going

Reverse_List_Done:
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; Identify_Macros function
;; Receives List in RAX
;; Updates the list in place; does not modify registers
;; Uses RBX for DEFINE, RCX for I
Identify_Macros:
	push rax                    ; Protect RAX
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
	mov rbx, DEFINE_str         ; Setup define string
	mov rcx, rax                ; I = HEAD
Identify_Macros_Loop:
	mov rax, [rcx+16]           ; I->TEXT
	call match                  ; IF "DEFINE" == I->TEXT
	cmp rax, 0                  ; Check if match
	jne Identify_Macros_Next    ; Skip the work

	;; Deal with MACRO
	mov rax, 1                  ; Using MACRO
	mov [rcx+8], rax            ; I->TYPE = MACRO

	mov rax, [rcx]              ; I->NEXT
	mov rax, [rax+16]           ; I->NEXT->TEXT
	mov [rcx+16], rax           ; I->TEXT = I->NEXT->TEXT

	mov rax, [rcx]              ; I->NEXT
	mov rax, [rax]              ; I->NEXT->NEXT
	mov rax, [rax+16]           ; I->NEXT->NEXT->TEXT
	mov [rcx+24], rax           ; I->EXPRESSION = I->NEXT->NEXT->TEXT

	mov rax, [rcx]              ; I->NEXT
	mov rax, [rax]              ; I->NEXT->NEXT
	mov rax, [rax]              ; I->NEXT->NEXT->NEXT
	mov [rcx], rax              ; I->NEXT = I->NEXT->NEXT->NEXT

Identify_Macros_Next:
	mov rcx, [rcx]              ; I = I->NEXT
	cmp rcx, 0                  ; Check for NULL
	jne Identify_Macros_Loop    ; Keep looping otherwise

	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	pop rax                     ; Restore RAX
	ret

DEFINE_str:
	db 68, 69, 70, 73, 78, 69, 0


;; match function
;; Receives CHAR* in RAX and CHAR* in RBX
;; Returns 0 (TRUE) or 1 (FALSE) in RAX
match:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
	mov rcx, rax                ; S1 in place
	mov rdx, rbx                ; S2 in place
match_Loop:
	mov al, [rcx]               ; S1[0]
	movzx rax, al               ; Make it useful
	mov bl, [rdx]               ; S2[0]
	movzx rbx, bl               ; Make it useful
	cmp rax, rbx                ; See if they match
	jne match_False             ; If not

	add rcx, 1                  ; S1 = S1 + 1
	add rdx, 1                  ; S2 = S2 + 1
	cmp rax, 0                  ; If reached end of string
	je match_Done               ; Perfect match
	jmp match_Loop              ; Otherwise keep looping

match_False:
	mov rax, 1                  ; Return false
match_Done:
	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; Line_Macro function
;; Receives List in RAX
;; Updates the list in place; does not modify registers
;; Uses RAX for I, RBX for I->TEXT, RCX for I->EXPRESSION
Line_Macro:
	push rax                    ; Protect RAX
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
Line_Macro_Loop:
	mov rbx, [rax+8]            ; I->TYPE
	cmp rbx, 1                  ; IF MACRO == I->TYPE
	jne Line_Macro_Next         ; Otherwise move on

	;; Is a macro apply
	mov rbx, [rax+16]           ; I->TEXT
	mov rcx, [rax+24]           ; I->EXPRESSION
	mov rax, [rax]              ; I->NEXT
	call Set_Expression         ; Apply it
	jmp Line_Macro_Loop         ; Move on to next

Line_Macro_Next:
	mov rax, [rax]              ; I->NEXT
	cmp rax, 0                  ; Check for NULL
	jne Line_Macro_Loop         ; Keep going

	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	pop rax                     ; Restore RAX
	ret


;; Set_Expression function
;; Receives List in RAX, CHAR* in RBX and CHAR* in RCX
;; Updates the list in place; does not modify registers
;; Uses RBX for C, RCX for EXP and RDX for I
Set_Expression:
	push rax                    ; Protect RAX
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
	mov rdx, rax                ; Set I
Set_Expression_Loop:
	mov rax, [rdx+8]            ; I->TYPE
	cmp rax, 1                  ; IF MACRO == I->TYPE
	je Set_Expression_Next      ; Ignore and move on

	mov rax, [rdx+16]           ; I->TEXT
	call match                  ; Check for match
	cmp rax, 0                  ; If match
	jne Set_Expression_Next     ; Otherwise next

	;; We have a non-macro match
	mov [rdx+24], rcx           ; I->EXPRESSION = EXP

Set_Expression_Next:
	mov rdx, [rdx]              ; I = I->NEXT
	cmp rdx, 0                  ; IF NULL == I
	jne Set_Expression_Loop     ; Otherwise keep looping

	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	pop rax                     ; Restore RAX
	ret


;; Process_String function
;; Receives List in RAX
;; Update the list in place; does not modify registers
;; Uses RBX for I->TEXT, RCX for I and RDX for S
Process_String:
	push rax                    ; Protect RAX
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
	mov rcx, rax                ; I = HEAD
Process_String_loop:
	mov rax, [rcx+8]            ; I->TYPE
	cmp rax, 2                  ; IF STRING == I->TYPE
	jne Process_String_Next     ; Skip to next

	mov rbx, [rcx+16]           ; I->TEXT
	mov al, [rbx]               ; I->TEXT[0]
	movzx rax, al               ; make it useful
	cmp rax, 39                 ; IF '\'' == I->TEXT[0]
	jne Process_String_Raw      ; Deal with '"'

	;; Deal with '\''
	add rbx, 1                  ; I->TEXT + 1
	mov [rcx+24], rbx           ; I->EXPRESSION = I->TEXT + 1
	jmp Process_String_Next     ; Move on to next

Process_String_Raw:
	mov rax, rbx                ; Get length of I->TEXT
	call string_length          ; Do it
	shr rax, 2                  ; LENGTH = LENGTH >> 2
	add rax, 1                  ; LENGTH = LENGTH + 1
	shl rax, 3                  ; LENGTH = LENGTH << 3
	call malloc                 ; Get string
	mov rdx, rbx                ; S = I->TEXT
	add rdx, 1                  ; S = S + 1
	mov [rcx+24], rax           ; I->EXPRESSION = hexify
	mov rbx, rax                ; Put hexify buffer in rbx

Process_String_Raw_Loop:
	mov al, [rdx]               ; Read 1 chars
	movzx rax, al               ; Make it useful
	add rdx, 1                  ; S = S + 1
	cmp al, 0                   ; Check for NULL
	pushf                       ; Protect condition
	call hex8                   ; write them all
	popf                        ; restore condition
	jne Process_String_Raw_Loop ; Keep looping

Process_String_Next:
	mov rcx, [rcx]              ; I = I->NEXT
	cmp rcx, 0                  ; IF NULL == I
	jne Process_String_loop     ; Otherwise keep looping

	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	pop rax                     ; Restore RAX
	ret


;; string_length function
;; Receives CHAR* in RAX
;; Returns INT in RAX
;; Uses RAX for CH, RBX for S and RCX for INDEX
string_length:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rbx, rax                ; Set S
	mov rcx, 0                  ; INDEX = 0
string_length_loop:
	mov al, [rbx+rcx]           ; S[0]
	movzx rax, al               ; make it useful
	cmp rax, 0                  ; IF NULL == S[0]
	je string_length_done       ; Stop

	add rcx, 1                  ; INDEX = INDEX + 1
	jmp string_length_loop      ; Keep going

string_length_done:
	mov rax, rcx                ; RETURN INDEX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; Eval_Immediates function
;; Receives List in RAX
;; Updates the list in place; does not modify registers
;; Uses RBX for I->TEXT[0], RCX for I->TEXT[1] and RDX for I
Eval_Immediates:
	push rax                    ; Protect RAX
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
	mov rdx, rax                ; I = HEAD
Eval_Immediates_Loop:
	;; Check for MACRO
	mov rax, [rdx+8]            ; I->TYPE
	cmp rax, 1                  ; IF MACRO == I-TYPE
	je Eval_Immediates_Next     ; Skip to next

	;; Check for NULL EXPRESSION
	mov rax, [rdx+24]           ; I->EXPRESSION
	cmp rax, 0                  ; IF NULL == I->EXPRESSION
	jne Eval_Immediates_Next    ; Skip to next

	;; Check if number
	mov rax, [rdx+16]           ; I->TEXT
	mov bl, [rax]               ; I->TEXT[0]
	movzx rbx, bl               ; Extend to use
	add rax, 1                  ; I->TEXT + 1
	mov cl, [rax]               ; I->TEXT[1]
	movzx rcx, cl               ; Extend to use
	call numerate_string        ; Convert string to INT
	cmp rax, 0                  ; IF 0 == numerate_number(I->TEXT + 1)
	jne Eval_Immediates_value   ; Has a value

	;; Last chance for Immediate
	cmp rcx, 48                 ; If '0' == I->TEXT[1]
	jne Eval_Immediates_Next    ; Skip to next

Eval_Immediates_value:
	call express_number         ; Convert value to hex string
	mov [rdx+24], rax           ; I->EXPRESSION = express_number(value, I-TEXT[0])

Eval_Immediates_Next:
	mov rdx, [rdx]              ; I = I->NEXT
	cmp rdx, 0                  ; IF NULL == I
	jne Eval_Immediates_Loop    ; Otherwise keep looping

	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	pop rax                     ; Restore RAX
	ret


;; numerate_string function
;; Receives CHAR* in RAX
;; Returns value of CHAR* in RAX
;; Uses RAX for VALUE, RBX for S, RCX for CH and RSI for NEGATIVE?
numerate_string:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
	push rsi                    ; Protect RSI
	mov rbx, rax                ; put S in correct place
	mov rax, 0                  ; Initialize to Zero
numerate_string_loop:
	mov cl, [rbx+1]             ; S[1]
	movzx rcx, cl               ; make it useful
	cmp rcx, 120                ; IF 'x' == S[1]
	je numerate_hex             ; Deal with hex input

	;; Assume decimal input
	mov rsi, 0                  ; Assume no negation
	mov cl, [rbx]               ; S[0]
	movzx rcx, cl               ; make it useful
	cmp rcx, 45                 ; IF '-' == S[0]
	jne numerate_decimal        ; Skip negation

	mov rsi, 1                  ; Set FLAG
	add rbx, 1                  ; S = S + 1

numerate_decimal:
	mov cl, [rbx]               ; S[0]
	movzx rcx, cl               ; make it useful
	cmp rcx, 0                  ; IF NULL == S[0]
	je numerate_decimal_done    ; We are done

	imul rax, 10                ; VALUE = VALUE * 10
	sub rcx, 48                 ; CH = CH - '0'
	cmp rcx, 9                  ; Check for illegal
	jg numerate_string_fail     ; If CH > '9'
	cmp rcx, 0                  ; Check for illegal
	jl numerate_string_fail     ; IF CH < 0
	add rax, rcx                ; VALUE = VALUE + CH
	add rbx, 1                  ; S = S + 1
	jmp numerate_decimal        ; Keep looping

numerate_decimal_done:
	cmp rsi, 1                  ; Check if need to negate
	jne numerate_string_done    ; Nope

	imul rax, -1                ; VALUE = VALUE * -1
	jmp numerate_string_done    ; Done

numerate_hex:
	add rbx, 2                  ; S = S + 2
numerate_hex_loop:
	mov cl, [rbx]               ; S[0]
	movzx rcx, cl               ; make it useful
	cmp rcx, 0                  ; IF NULL == S[0]
	je numerate_string_done     ; We are done

	shl rax, 4                  ; VALUE = VALUE << 4
	sub rcx, 48                 ; CH = CH - '0'
	cmp rcx, 10                 ; IF 10 >= CH
	jl numerate_hex_digit       ; NO
	sub rcx, 7                  ; Push A-F into range
numerate_hex_digit:
	cmp rcx, 15                 ; Check for illegal
	jg numerate_string_fail     ; If CH > 'F'
	cmp rcx, 0                  ; Check for illegal
	jl numerate_string_fail     ; IF CH < 0
	add rax, rcx                ; VALUE = VALUE + CH
	add rbx, 1                  ; S = S + 1
	jmp numerate_hex_loop       ; Keep looping

numerate_string_fail:
	mov rax, 0                  ; return ZERO

numerate_string_done:
	pop rsi                     ; Restore RSI
	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; express_number function
;; Receives INT in RAX and CHAR in RBX
;; Allocates a string and expresses the value in hex
;; Returns string in RAX
;; Uses RAX for VALUE, RBX for S and RCX for CH
express_number:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
	mov rcx, rbx                ; Put CH in right place
	mov rbx, rax                ; Protect VALUE
	cmp rcx, 37                 ; IF '%' == CH
	jne express_number2         ; Otherwise try @

	mov rax, 9                  ; We need 3bytes
	call malloc                 ; Get S pointer
	xchg rax, rbx               ; Put S and VALUE in place
	push rbx                    ; Protect S
	call hex32l                 ; Store 32bits
	jmp express_number_done     ; done

express_number2:
	cmp rcx, 64                 ; IF '@' == CH
	jne express_number1         ; Othrewise try !

	mov rax, 5                  ; We need 3bytes
	call malloc                 ; Get S pointer
	xchg rax, rbx               ; Put S and VALUE in place
	push rbx                    ; Protect S
	call hex16l                 ; Store 16bits
	jmp express_number_done     ; done

express_number1:
	mov rax, 3                  ; We need 3bytes
	call malloc                 ; Get S pointer
	xchg rax, rbx               ; Put S and VALUE in place
	push rbx                    ; Protect S
	call hex8                   ; Store 8bit

express_number_done:
	pop rax                     ; Restore S
	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; HEX to ascii routine
;; Receives INT in RAX and CHAR* in RBX
;; Stores ascii of INT in CHAR*
;; Returns only modifying RAX
hex64l:
	push rax                    ; Protect top 32
	call hex32l                  ; Store it
	pop rax                     ; do top 32
	shr rax, 32                 ; do bottom 32 first
hex32l:
	push rax                    ; Protect top 16
	call hex16l                  ; Store it
	pop rax                     ; do top 16
	shr rax, 16                 ; do bottom 16 first
hex16l:
	push rax                    ; Protect top byte
	call hex8                   ; Store it
	pop rax                     ; do high byte
	shr rax, 8                  ; do bottom byte first
hex8:
	push rax                    ; Protect bottom nibble
	shr rax, 4                  ; do high nibble first
	call hex4                   ; Store it
	pop rax                     ; do low nibble
hex4:
	and rax, 0xf                ; isolate nibble
	add al,'0'                  ; convert to ascii
	cmp al,'9'                  ; valid digit?
	jbe hex1                    ; yes
	add al,7                    ; use alpha range
hex1:
	mov [ebx], al               ; store result
	add ebx, 1                  ; next position
	ret


;; Preserve_Other function
;; Receives List in RAX
;; Updates the list in place; does not modify registers
;; Uses RAX for I, RBX for I->TEXT
Preserve_Other:
	push rax                    ; Protect RAX
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	push rdx                    ; Protect RDX
Preserve_Other_Loop:
	mov rbx, [rax+24]           ; I->EXPRESSION
	cmp rbx, 0                  ; IF NULL == I->EXPRESSION
	jne Preserve_Other_Next     ; Otherwise next

	;; Needs preserving
	mov rbx, [rax+16]           ; I->TEXT
	mov [rax+24], rbx           ; I->EXPRESSION = I->TEXT

Preserve_Other_Next:
	mov rax, [rax]              ; I = I->NEXT
	cmp rax, 0                  ; IF NULL == I
	jne Preserve_Other_Loop     ; Otherwise keep looping

	pop rdx                     ; Restore RDX
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	pop rax                     ; Restore RAX
	ret


;; Print_Hex function
;; Receives list in RAX
;; walks the list and prints the I->EXPRESSION for all nodes followed by newline
;; Uses RBX for I
Print_Hex:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rbx, r13                ; I = Head
Print_Hex_Loop:
	mov rax, [rbx+8]            ; I->TYPE
	cmp rax, 1                  ; IF MACRO == I->TYPE
	je Print_Hex_Next           ; Skip

	mov rax, [rbx + 24]         ; Using EXPRESSION
	call File_Print             ; Print it
	mov rax, 10                 ; NEWLINE
	call fputc                  ; Append it

Print_Hex_Next:
	mov rbx, [rbx]              ; Iterate to next Token
	cmp rbx, 0                  ; Check for NULL
	jne Print_Hex_Loop          ; Otherwise keep looping

	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; File_Print function
;; Receives CHAR* in RAX
;; calls fputc for every non-null char
File_Print:
	push rbx                    ; Protect RBX
	push rcx                    ; Protect RCX
	mov rbx, rax                ; Protect S
	cmp rax, 0                  ; Protect against nulls
	je File_Print_Done          ; Simply don't try to print them
File_Print_Loop:
	mov al, [rbx]               ; Read byte
	movzx rax, al               ; zero extend
	cmp rax, 0                  ; Check for NULL
	je File_Print_Done          ; Stop at NULL

	call fputc                  ; write it
	add rbx, 1                  ; S = S + 1
	jmp File_Print_Loop         ; Keep going

File_Print_Done:
	pop rcx                     ; Restore RCX
	pop rbx                     ; Restore RBX
	ret


;; fputc function
;; receives CHAR in RAX and FILE* in R14
;; writes char and returns
fputc:
	push rax                    ; We are writing rax
	lea rsi, [rsp]              ; Get stack address
	mov rdi, r14                ; Write to target file
	mov rax, 1                  ; the syscall number for write
	push rdx                    ; Protect RDX
	mov rdx, 1                  ; set the size of chars we want
	push r11                    ; Protect HEAD
	syscall                     ; call the Kernel
	pop r11                     ; Restore HEAD
	pop rdx                     ; Restore RDX
	pop rax                     ; Restore stack
	ret
