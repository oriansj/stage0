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

BITS 16
	;; Steps for building
	;; nasm -o stage1_hex_compiler stage1_hex_compiler
	;;
	;; Steps for testing
	;; qemu -fda stage0
	;; manually toggle in program hex
	;; or
	;; qemu -fda stage1_loader -fdb output
	;; then change floppy0 to the compiled version of this file
start:
	mov sp, 256		; Allocate 256B for stack
	mov ax, 7e00h		; Which is much more than we need
	mov ss, ax		; And stopping before this code

	;; Prompt user to press any key after loading desire source into A:
	mov ax, MSG0
	call print_string

	;; Wait until the user presses a key
	call read_key

	;; Inform the user that we are starting to read
	mov ax, MSG1
	call print_string

	;; Read A: into memory
	call read_floppy

	;; Inform the user that we completed reading A: and are starting to compile
	mov ax, MSG2
	call print_string

	;; Actually compile
	call compile

	;; Inform that user that we completed Compiling and are starting to write to B:
	mov ax, MSG3
	call print_string

	;; Start writing memory into B:
	call write_floppy2

	;; Inform the user that we completed writing to B:
	mov ax, MSG4
	call print_string
	jmp start

;; Our glourious strings
MSG0 db 'Load source into A: and hit any key',10,13,0
MSG1 db 'Starting to read A:',10,13,0
MSG2 db 'Read Complete, Starting to compile',10,13, 0
MSG3 db 'Compile Complete, Starting to write B:',10,13,0
MSG4 db 'Write Complete',10,13, 0

;; Deal with the problem of printing the above strings
print_string:
	pusha
	mov bx, ax
.L0:
	mov al, [cs:bx]
	cmp al, 0
	je .L99
	call print_char
	add bx, 1
	jmp .L0
.L99:
	popa
	ret

print_char:
	pusha
	; Routine: output char in al to screen
	mov ah, 0Eh		; int 10h 'print char' function
	int 10h		; print it
	popa
	ret

read_floppy:
	pusha
.L0:
	;; Read bytes from floppy
	push 02000h		; Use The read space
	pop es			; ES is needed to be set for bios call
	mov al, 128		; Read 2^15 Bytes from diskette
	mov ah, 02h		; Read Sectors to Memory
	mov ch, 0		; Cylinder Number
	mov cl, 1		; Starting sector number
	mov dh, 0		; Drive head number
	mov dl, 00h		; Drive number [first floppy]
	mov bx, 0h		; Starting address
	int 13h		; Make the function call

	jc .L0
	popa
	ret

read_key:
	pusha
	;; Routine: read a char into al
	mov ah, 00h
	int 16h
	popa
	ret

write_floppy2:
	pusha
.L0:
	;; Write bytes onto floppy2
	push 03000h		; Use the write space
	pop es			; ES is needed to be set for bios all
	mov al, 128		; Write 2^15 Bytes to diskette
	mov ah, 03h		; Write Sectors from Memory
	mov ch, 0		; Cylinder Number
	mov cl, 1		; Starting sector number
	mov dh, 0		; Drive head number
	mov dl, 01h		; Drive number [second floppy]
	mov bx, 0h		; Starting address
	int 13h		; Make the function call

	jc .L0
	popa
	ret

compile:
	pusha
	;; Initialize our pointers
	mov ax, 0
	mov [Read_Pointer], ax
	mov [Write_Pointer], ax

	;; Initialize variables
	mov di, 1		; Our toggle
	mov si, 0		; Our holder

.L0:
	call read_char		; Read a byte
	cmp al, 0		; Check for NULL
	je .L99		; Be done at NULL
	call hex		; Otherwise try to convert hex
	cmp al, 0		; Check if it is hex
	jl .L0			; Don't use nonhex chars
	cmp di, 0		; Check if toggled
	je .L1

	;; Process first byte of pair
	mov si, 0Fh		; Mask out top
	and si, ax		; Store first nibble
	mov di, 0		; Flip the toggle
	jmp .L0

.L1:
	shl si, 4		; shift our first nibble
	and ax, 0Fh		; Mask out top
	add ax, si		; Combine nibbles
	mov di, 1		; Flip the toggle
	call write_char	; Write our byte out
	jmp .L0
.L99:
	popa
	ret

Read_Pointer dw 0
read_char:
	push bx
	push es
	push 02000h
	pop es
	mov bx, [cs:Read_Pointer]
	mov al, [es:bx]
	add bx, 1
	mov [cs:Read_Pointer], bx
	pop es
	pop bx
	ret

Write_Pointer dw 0
write_char:
	pusha
	push 03000h
	pop es
	mov bx, [cs:Write_Pointer]
	mov [es:bx], al
	add bx, 1
	mov [cs:Write_Pointer], bx
	popa
	ret


hex:
	; deal with line comments starting with #
	cmp al, 35
	je ascii_comment
	; deal with line comments starting with ;
	cmp al, 59
	je ascii_comment
	; deal all ascii less than 0
	cmp al, 48
	jl ascii_other
	; deal with 0-9
	cmp al, 58
	jl ascii_num
	; deal with all ascii less than A
	cmp al, 65
	jl ascii_other
	; deal with A-F
	cmp al, 71
	jl ascii_high
	; deal with all ascii less than a
	cmp al, 97
	jl ascii_other
	; deal with a-f
	cmp al, 103
	jl ascii_low
	; The rest that remains needs to be ignored
	jmp ascii_other

ascii_num:
	sub al, 48
	ret
ascii_low:
	sub al, 87
	ret
ascii_high:
	sub al, 55
	ret
ascii_other:
	mov al, -1
	ret
ascii_comment:
	call read_char		; Read until end of Line
	cmp al, 13		; Carriage return counts
	je ascii_other
	cmp al, 10		; So does line feed
	je ascii_other
	cmp al, 0		; Nulls are probably a safe stopping point too
	je ascii_other
	jmp ascii_comment	; Otherwise keep dropping input
