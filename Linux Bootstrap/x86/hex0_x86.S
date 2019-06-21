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
	mov edx, 0                  ; Extra sure
	mov eax, 5                  ;·the·syscall·number·for·open()
	int 0x80                    ; Now open that damn file
	mov [fin], eax              ; Preserve the file pointer we were given

	pop ebx                     ;·Get·the·actual·output name
	mov ecx, 577                ; Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov edx, 448                ; Prepare file as RWX for owner only (700 in octal)
	mov eax, 5                  ;·the·syscall·number·for·open()
	int 0x80                    ; Now open that damn file
	mov [fout], eax             ; Preserve the file pointer we were given

	; Our flag for byte processing
	mov ebp, -1

	; temp storage for the sum
	mov edi, 0

loop:
	; Read a byte
	call Read_byte

	; process byte
	call hex

	; Deal with -1 values
	cmp eax, 0
	jl loop

	; deal with toggle
	cmp ebp, 0
	jge print

	; process first byte of pair
	mov edi, eax
	mov ebp, 0
	jmp loop

; process second byte of pair
print:
	; update the sum and store in output
	shl edi, 4
	add eax, edi
	mov [output], al

	; flip the toggle
	mov ebp, -1

	call write_byte

	jmp loop

hex:
	; Purge Comment Lines (#)
	cmp eax, 35
	je purge_comment

	; Purge Comment Lines (;)
	cmp eax, 59
	je purge_comment

	; deal all ascii less than 0
	cmp eax, 48
	jl ascii_other

	; deal with 0-9
	cmp eax, 58
	jl ascii_num

	; deal with all ascii less than A
	cmp eax, 65
	jl ascii_other

	; deal with A-F
	cmp eax, 71
	jl ascii_high

	;deal with all ascii less than a
	cmp eax, 97
	jl ascii_other

	;deal with a-f
	cmp eax, 103
	jl ascii_low

	; The rest that remains needs to be ignored
	jmp ascii_other

purge_comment:
	; Read a byte
	call Read_byte

	; Loop if not LF
	cmp eax, 10
	jne purge_comment

	; Otherwise return -1
	mov eax, -1
	ret

ascii_num:
	sub eax, 48
	ret

ascii_low:
	sub eax, 87
	ret

ascii_high:
	sub eax, 55
	ret

ascii_other:
	mov eax, -1
	ret

Done:
	; program completed Successfully
	mov ebx, 0                  ; All is well
	mov eax, 1                  ; put the exit syscall number in eax
	int 0x80                    ; Call it a good day

write_byte:
	; Print our Hex
	mov edx, 1                  ; set the size of chars we want
	mov ecx, output             ; What we are writing
	mov ebx, [fout]             ; Where are we writing to
	mov eax, 4                  ; the syscall number for write
	int 0x80                    ; call the Kernel
	ret

Read_byte:
	; Attempt to read 1 byte from STDIN
	mov edx,  1                 ; set the size of chars we want
	mov ecx, input              ; Where to put it
	mov ebx, [fin]              ; Where are we reading from
	mov eax, 3                  ; the syscall number for read
	int 0x80                    ; call the Kernel

	test eax, eax               ; check what we got
	je Done                     ; Got EOF call it done

	; load byte
	mov al, [input]             ; load char
	movzx eax, al               ; We have to zero extend it to use it
	ret


section .data
ELF_end:
fin:
	dq 0
fout:
	dq 0

; Where we are putting our output
output:
	; Reserve 4bytes of Zeros
	dq 0

; Where we get our input
input:
	; Reserve 4bytes of Zeros
	dq 0
