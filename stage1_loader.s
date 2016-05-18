BITS 16
	;; Steps for building
	;; nasm -o stage1_loader stage1_loader.s
	;;
	;; Steps for testing
	;; qemu -fda stage1_loader
	;; Then insert another program to load and run
start:
	;; Wait for user input before running
	mov ah, 00h
	int 16h

	;; Clear the screen to be nice
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

read_floppy:
	;; Read bytes from floppy
	mov al, 128		; Number of sectors to read
	mov ah, 02h		; Read sectors to memory
	mov ch, 0		; Cylinder Number
	mov cl, 1		; Starting sector number
	mov dh, 0		; Drive head number
	mov dl, 00h		; Drive number [floppy A:]
	mov bx, 01000h		; Starting segment
	mov es, bx		; Loaded into the required segment register
	mov bx, 0		; At the exact start of the segment
	int 13h		; Make the function call

	jc read_floppy

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

	;; Prepare to Jump to the code we loaded
	push 01000h
	push 0h

	;; Using intersegment return
	iret

done:
	hlt
	times 510-($-$$) db 90h	; Pad remainder of boot sector with NOPs
	dw 0xAA55		; The standard PC boot signature
