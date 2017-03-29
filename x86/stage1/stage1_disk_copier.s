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
	;; nasm -o stage1_disk_copier stage1_disk_copier.s
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

	;; Inform the user that we completed reading A: and are starting to write B:
	mov ax, MSG2
	call print_string

	;; Start writing memory into B:
	call write_floppy2

	;; Inform the user that we completed writing to B:
	mov ax, MSG3
	call print_string
	jmp start

;; Our glourious strings
MSG0 db 'Load source into A: and hit any key',10,13,0
MSG1 db 'Starting to read A:',10,13,0
MSG2 db 'Read Complete, Starting to write B:',10,13,0
MSG3 db 'Write Complete',10,13, 0

;; Deal with the problem of printing the above strings
print_string:
	push bx
	mov bx, ax
.L0:
	mov al, [cs:bx]
	cmp al, 0
	je .L99
	call print_char
	add bx, 1
	jmp .L0
.L99:
	pop bx
	ret

print_char:
	; Routine: output char in al to screen
	mov ah, 0Eh		; int 10h 'print char' function
	int 10h		; print it
	ret

read_floppy:
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

	jc read_floppy
	ret

read_key:
	;; Routine: read a char into al
	mov ah, 00h
	int 16h
	ret

write_floppy2:
	;; Write bytes onto floppy2
	push 02000h		; Use the read space
	pop es			; ES is needed to be set for bios all
	mov al, 128		; Write 2^15 Bytes to diskette
	mov ah, 03h		; Write Sectors from Memory
	mov ch, 0		; Cylinder Number
	mov cl, 1		; Starting sector number
	mov dh, 0		; Drive head number
	mov dl, 01h		; Drive number [second floppy]
	mov bx, 0h		; Starting address
	int 13h		; Make the function call

	jc write_floppy2
	ret
