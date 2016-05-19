BITS 16
	;; Steps for building
	;; nasm -o stage1_raw_writer stage1_raw_writer.s
	;;
	;; Steps for testing
	;; qemu -fda stage0
	;; manually toggle in program hex
	;; or
	;; qemu -fda stage1_loader -fdb output
	;; then change floppy0 to the compiled version of this file
start:
	mov ax, 02000h		; Set ES segment to where our working space is
	mov es, ax

	mov ax, 0h		; Set stack space in 0x0000:0x7e00 <- 0x0000:0xffff
	mov ss, ax
	mov sp, 0FFFFh

	mov ax, 01000h		; Set data segment to where we're loaded
	mov ds, ax
	mov bp, 0h		; Our Index should be Zero

loop:
	call read_char

	;; Check for C-d
	cmp al, 4
	jne .L0
	call write_floppy2
	mov bp, 0h		; Reset our index as we finished
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
	mov al, 10		; Add the Line feed char
	call append_char
	mov al, 13		; And the Carriage return for legacy systems
	call append_char
	jmp loop

.L2:
	;; Otherwise just print the char
	call print_char	; Show the user what they input
	call append_char
	jmp loop

append_char:
	;; Write char out to Memory
	mov bx, bp		; Index registers are weird
	mov [es:bx], al	; Write our char out
	add bp, 1		; Increment our pointer by 1
	ret

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

write_floppy2:
	;; Clear the screen to be nice
	call clear_screen

	;; Write bytes onto floppy2
	mov al, 128		; Write 2^16 Bytes to diskette
	mov ah, 03h		; Write Sectors from Memory
	mov ch, 0		; Cylinder Number
	mov cl, 1		; Starting sector number
	mov dh, 0		; Drive head number
	mov dl, 01h		; Drive number [second floppy]
	mov bx, 0h		; Starting address
	int 13h		; Make the function call

	jc write_floppy2
	ret
