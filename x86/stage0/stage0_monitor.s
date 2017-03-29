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
	;; nasm -o stage0_monitor stage0_monitor.s
	;;
	;; Steps for testing
	;; qemu -fda stage0_monitor
start:
	mov sp, 256		; Allocate 256B for stack
	mov ax, 07E00h		; Which is much more than we need
	mov ss, ax		; And stopping before this code

	mov ax, 01000h		; Select Wide open segment via ES
	mov es, ax		; Where we will be shoving things
	mov bp, 0		; Starting at index 0

	mov ax, 0
	mov di, 1		; Our toggle
	mov si, 0		; Our holder

loop:
	call read_char

	;; Check for C-d
	cmp al, 4
	jne .L0
	call execute_code
	jmp loop

.L0:
	;; Check for C-l
	cmp al, 12
	jne .L1
	call clear_screen
	jmp loop

.L1:
	;; Check for [Enter]
	cmp al, 13
	jne .L2
	call display_newline
	jmp loop

.L2:
	;; Otherwise just print the char
	call print_char		; Show the user what they input
	call hex			; Convert to what we want
	cmp al, 0			; Check if it is hex
	jl loop			; Don't use nonhex chars
	cmp di, 0			; Check if toggled
	je .L99			; Jump if toggled

	;; Process first byte of pair
	mov si, 0Fh		; Mask out top
	and si, ax		; Store first nibble
	mov di, 0		; Flip the toggle
	jmp loop
.L99:
	shl si, 4		; shift our first nibble
	and ax, 0Fh		; Mask out top
	add ax, si		; Combine nibbles
	mov di, 1		; Flip the toggle
	mov bx, bp		; Index registers are weird
	mov [es:bx], al	; Write our byte out
	add bp, 1		; Increment our pointer by 1

	call insert_spacer
	jmp loop

print_char:
	; Routine: output char in al to screen
	mov ah, 0Eh		; int 10h 'print char' function
	int 10h		; print it
	ret

read_char:
	;; Routine: read a char into al
	mov ah, 00h
	int 16h
	ret

clear_screen:
	;; Routine: clears the display
	mov al, 0		; Clear screen
	mov ah, 06h		; Scroll up
	mov bh, 07h		; Move Color
	mov cl, 0		; UL x coordinate
	mov ch, 0		; UL y coordinate
	mov dl, 80		; LR x coordinate
	mov dh, 24		; LR y coordinate
	int 10h
	;; Routine: reset the cursor
	mov ah, 02h		; Set cursor position
	mov bh, 0		; Set Page number to 0
	mov dh, 0		; Set Row Number
	mov dl, 0		; Set Column Number
	int 10h
	ret

display_newline:
	;; Routine for determining if we should scroll or move cursor
	call get_cursor_position
	cmp ah, 12
	jle .L0
	call scroll_window
	ret
.L0:
	;; Routine: Move the cursor down
	mov dh, 1		; How many rows we want to move
	add dh, ah		; Add our current Row Number
	mov ah, 02h		; Set cursor position
	mov bh, 0		; Set Page number to 0
	mov dl, 0		; Set Column Number
	int 10h
	mov al, 13		; Print a new line
	call print_char
	ret

get_cursor_position:
	;; Routine for getting cursor position
	mov ah, 03h		; Request Cursor position
	mov bh, 0		; For page 0
	int 10h
	mov ax, dx		; Mov the row and column into ax
	ret

scroll_window:
	;; Routine scroll window up
	mov al, 1		; Move the line up one
	mov ah, 06h		; Scroll up
	mov bh, 07h		; Move Color
	mov cl, 0		; UL x coordinate
	mov ch, 0		; UL y coordinate
	mov dl, 80		; LR x coordinate
	mov dh, 24		; LR y coordinate
	int 10h
	mov al, 13		; Print a new line
	call print_char
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
	call read_char
	call print_char
	cmp al, 13
	jne ascii_comment
	call scroll_window
	jmp ascii_other

execute_code:
	;; Clear the screen to be nice
	call clear_screen

	;; Zero all registers and segments before jump
	mov ax, 0
	mov bx, 0
	mov cx, 0
	mov dx, 0
	mov si, 0
	mov di, 0
	mov bp, 0
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	;; Load the code that we input by hand
	push 01000h
	push 0h

	;; Using intersegment return
	iret

insert_spacer:
	mov al, 32
	call print_char
	ret

done:
	hlt
	times 510-($-$$) db 90h	; Pad remainder of boot sector with NOPs
	dw 0xAA55		; The standard PC boot signature
