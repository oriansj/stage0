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
	mov r9, rax                 ; Preserve the file pointer we were given

	pop rdi                     ;·Get·the·actual·output name
	mov rsi, 577                ; Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov rdx, 448                ; Prepare file as RWX for owner only (700 in octal)
	mov rax, 2                  ;·the·syscall·number·for·open()
	syscall                     ; Now open that damn file
	mov r10, rax                ; Preserve the file pointer we were given

	mov r15, -1                 ; Our flag for byte processing
	mov r14, 0                  ; temp storage for the sum
	mov r13, 0                  ; Our starting IP
	call First_pass             ; Process it

	; rewind input file
	mov rdi, r9                 ; Using our input file
	mov rsi, 0                  ; Offset Zero
	mov rdx, 0                  ; Whence Zero
	mov rax, 8                  ; lseek
	syscall

	mov r15, -1                 ; Our flag for byte processing
	mov r14, 0                  ; temp storage for the sum
	mov r13, 0                  ; Our starting IP
	call Second_pass            ; Process it

	jmp Done

First_pass:
	call Read_byte

	; Deal with EOF
	cmp rax, -4
	je First_pass_done

	; Check for :
	cmp rax, 0x3a
	jne First_pass_0

	; Deal with label
	call StoreLabel

First_pass_0:
	; Check for :
	cmp rax, 0x25
	je First_pass_pointer

	; Deal with everything else
	call hex                    ; Process our char

	; Deal with EOF
	cmp rax, -4
	je First_pass_done

	; deal with -1 values
	cmp rax, 0
	jl First_pass

	; deal with toggle
	cmp r15, 0
	je First_pass_1
	add r13, 1                  ; Increment IP

First_pass_1:
	not r15
	jmp First_pass

First_pass_pointer:
	; Deal with Pointer to label
	call Read_byte              ; Drop the char
	add r13, 4                  ; Increment IP
	jmp First_pass              ; Loop again

First_pass_done:
	RET

hex:
	; deal with EOF
	cmp rax, -4
	je EOF
	; deal with line comments starting with ;
	cmp rax, 0x23
	je ascii_comment
	; deal with line comments starting with ;
	cmp rax, 0x3b
	je ascii_comment
	; deal all ascii less than 0
	cmp rax, 0x30
	jl ascii_other
	; deal with 0-9
	cmp rax, 0x3a
	jl ascii_num
	; deal with all ascii less than A
	cmp rax, 0x41
	jl ascii_other
	; deal with A-F
	cmp rax, 0x47
	jl ascii_high
	;deal with all ascii less than a
	cmp rax, 0x61
	jl ascii_other
	;deal with a-f
	cmp rax, 0x67
	jl ascii_low
	; The rest that remains needs to be ignored
	jmp ascii_other

Second_pass:
	call Read_byte

	; Deal with EOF
	cmp rax, -4
	je Second_pass_done

	; Simply drop the label
	cmp rax, 0x3a
	jne Second_pass_0

	call Read_byte
	jmp Second_pass

Second_pass_0:
	; Deal with  pointer
	cmp rax, 0x25
	jne Second_pass_1

	call StorePointer
	jmp Second_pass

Second_pass_1:
	; Deal with everything else
	call hex                    ; Process our char

	; Deal with EOF
	cmp rax, -4
	je Second_pass_done

	; deal with -1 values
	cmp rax, 0
	jl Second_pass

	; deal with toggle
	cmp r15, 0
	je print

	; process first byte of pair
	mov r14, rax
	mov r15, 0
	jmp Second_pass

Second_pass_done:
	ret

EOF:
	ret
ascii_num:
	sub rax, 0x30
	ret
ascii_low:
	sub rax, 0x57
	ret
ascii_high:
	sub rax, 0x37
	ret
ascii_other:
	mov rax, -1
	ret
ascii_comment:
	call Read_byte
	cmp rax, 0xd
	je ascii_comment_cr
	cmp rax, 0xa
	jne ascii_comment
ascii_comment_cr:
	mov rax, -1
	ret

; process second byte of pair
print:
	; update the sum and store in output
	shl r14, 4
	add rax, r14
	mov [table], al

	; flip the toggle
	not r15

	; Print our first Hex
	mov rdx,  1                 ; set the size of chars we want
	call print_chars

	add r13, 1                  ; Increment IP
	jmp Second_pass

Done:
	; program completed Successfully
	mov rdi, 0                  ; All is well
	mov rax, 0x3c               ; put the exit syscall number in eax
	syscall                     ; Call it a good day

Read_byte:
	; Attempt to read 1 byte from STDIN
	mov rdx,  1                 ; set the size of chars we want
	mov rsi, table              ; Where to put it
	mov rdi, r9                 ; Where are we reading from
	mov rax, 0                  ; the syscall number for read
	syscall                     ; call the Kernel

	test rax, rax               ; check what we got
	je Read_byte_1              ; Got EOF call it done

	; load byte
	mov al, [table]             ; load char
	movzx rax, al               ; We have to zero extend it to use it
	ret

; Deal with EOF
Read_byte_1:
	mov rax, -4                 ; Put EOF in rax
	ret

print_chars:
	mov rsi, table              ; What we are writing
	mov rdi, r10                ; Write to target file
	mov rax, 1                  ; the syscall number for write
	syscall                     ; call the Kernel
	ret

Get_table_target:
	call Read_byte              ; Get single char label
	shl rax, 3                  ; Each label in table takes 8 bytes to store
	add rax, table              ; Calculate offset
	ret

StoreLabel:
	call Get_table_target
	mov [rax], r13              ; Write out pointer to table
	ret

StorePointer:
	add r13, 4                  ; Increment IP
	call Get_table_target       ; Get address of pointer
	mov rax, [rax]              ; Get pointer
	sub rax, r13                ; target - ip
	mov [table], rax            ; put value in output
	mov rdx,  4                 ; set the size of chars we want
	call print_chars
	ret


section .data
ELF_end:
table:
	dq 0
