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
	pop eax                     ;·Get·the·number·of·arguments
	pop ebx                     ;·Get·the·program·name
	pop ebx                     ;·Get·the·actual·input name
	mov ecx, 0                  ;·prepare·read_only
	mov edx, 0                  ;·extra sure
	mov eax, 5                  ;·the·syscall·number·for·open()
	int 0x80                    ; Now open that damn file
	mov [fin], eax              ; Preserve the file pointer we were given

	pop ebx                     ;·Get·the·actual·output name
	mov ecx, 577                ; Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov edx, 448                ; Prepare file as RWX for owner only (700 in octal)
	mov eax, 5                  ;·the·syscall·number·for·open()
	int 0x80                    ; Now open that damn file
	mov [fout], eax             ; Preserve the file pointer we were given

	mov ebp, -1                 ; Our flag for byte processing
	mov esi, 0                  ; temp storage for the sum
	mov edi, 0                  ; Our starting IP
	call First_pass             ; Process it

	; rewind input file
	mov ebx, [fin]              ; Using our input file
	mov ecx, 0                  ; Offset Zero
	mov edx, 0                  ; Whence Zero
	mov eax, 19                 ; lseek
	int 0x80

	mov ebp, -1                 ; Our flag for byte processing
	mov esi, 0                  ; temp storage for the sum
	mov edi, 0                  ; Our starting IP
	call Second_pass            ; Process it

	jmp Done

First_pass:
	call Read_byte

	; Deal with EOF
	cmp eax, -4
	je First_pass_done

	; Check for :
	cmp eax, 0x3a
	jne First_pass_0

	; Deal with label
	call StoreLabel

First_pass_0:
	; Check for :
	cmp eax, 0x25
	je First_pass_pointer

	; Deal with everything else
	call hex                    ; Process our char

	; Deal with EOF
	cmp eax, -4
	je First_pass_done

	; deal with -1 values
	cmp eax, 0
	jl First_pass

	; deal with toggle
	cmp ebp, 0
	je First_pass_1
	add edi, 1                  ; Increment IP

First_pass_1:
	not ebp
	jmp First_pass

First_pass_pointer:
	; Deal with Pointer to label
	call Read_byte              ; Drop the char
	add edi, 4                  ; Increment IP
	jmp First_pass              ; Loop again

First_pass_done:
	RET

hex:
	; deal with EOF
	cmp eax, -4
	je EOF
	; deal with line comments starting with ;
	cmp eax, 0x23
	je ascii_comment
	; deal with line comments starting with ;
	cmp eax, 0x3b
	je ascii_comment
	; deal all ascii less than 0
	cmp eax, 0x30
	jl ascii_other
	; deal with 0-9
	cmp eax, 0x3a
	jl ascii_num
	; deal with all ascii less than A
	cmp eax, 0x41
	jl ascii_other
	; deal with A-F
	cmp eax, 0x47
	jl ascii_high
	;deal with all ascii less than a
	cmp eax, 0x61
	jl ascii_other
	;deal with a-f
	cmp eax, 0x67
	jl ascii_low
	; The rest that remains needs to be ignored
	jmp ascii_other

Second_pass:
	call Read_byte

	; Deal with EOF
	cmp eax, -4
	je Second_pass_done

	; Simply drop the label
	cmp eax, 0x3a
	jne Second_pass_0

	call Read_byte
	jmp Second_pass

Second_pass_0:
	; Deal with  pointer
	cmp eax, 0x25
	jne Second_pass_1

	call StorePointer
	jmp Second_pass

Second_pass_1:
	; Deal with everything else
	call hex                    ; Process our char

	; Deal with EOF
	cmp eax, -4
	je Second_pass_done

	; deal with -1 values
	cmp eax, 0
	jl Second_pass

	; deal with toggle
	cmp ebp, 0
	je print

	; process first byte of pair
	mov esi, eax
	mov ebp, 0
	jmp Second_pass

Second_pass_done:
	ret

EOF:
	ret
ascii_num:
	sub eax, 0x30
	ret
ascii_low:
	sub eax, 0x57
	ret
ascii_high:
	sub eax, 0x37
	ret
ascii_other:
	mov eax, -1
	ret
ascii_comment:
	call Read_byte
	cmp eax, 0xd
	je ascii_comment_cr
	cmp eax, 0xa
	jne ascii_comment
ascii_comment_cr:
	mov eax, -1
	ret

; process second byte of pair
print:
	; update the sum and store in output
	shl esi, 4
	add eax, esi
	mov [table], al

	; flip the toggle
	not ebp

	; Print our first Hex
	mov edx,  1                 ; set the size of chars we want
	call print_chars

	add edi, 1                  ; Increment IP
	jmp Second_pass

Done:
	; program completed Successfully
	mov ebx, 0                  ; All is well
	mov eax, 1                  ; put the exit syscall number in eax
	int 0x80                    ; Call it a good day

Read_byte:
	; Attempt to read 1 byte from STDIN
	mov edx,  1                 ; set the size of chars we want
	mov ecx, table              ; Where to put it
	mov ebx, [fin]              ; Where are we reading from
	mov eax, 3                  ; the syscall number for read
	int 0x80                    ; call the Kernel

	test eax, eax               ; check what we got
	je Read_byte_1              ; Got EOF call it done

	; load byte
	mov al, [table]             ; load char
	movzx eax, al               ; We have to zero extend it to use it
	ret

; Deal with EOF
Read_byte_1:
	mov eax, -4                 ; Put EOF in eax
	ret

print_chars:
	mov ecx, table              ; What we are writing
	mov ebx, [fout]             ; Write to target file
	mov eax, 4                  ; the syscall number for write
	int 0x80                    ; call the Kernel
	ret

Get_table_target:
	call Read_byte              ; Get single char label
	shl eax, 2                  ; Each label in table takes 4 bytes to store
	add eax, table              ; Calculate offset
	ret

StoreLabel:
	call Get_table_target
	mov [eax], edi              ; Write out pointer to table
	ret

StorePointer:
	add edi, 4                  ; Increment IP
	call Get_table_target       ; Get address of pointer
	mov eax, [eax]              ; Get pointer
	sub eax, edi                ; target - ip
	mov [table], eax            ; put value in output
	mov edx,  4                 ; set the size of chars we want
	call print_chars
	ret


section .data
ELF_end:
fin:
	dq 0
fout:
	dq 0

table:
	dq 0
