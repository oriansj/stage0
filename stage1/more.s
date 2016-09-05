:start
	LOADUI R2 10                ; We will be using R2 for our counter
	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ


;; Main loop of more functionality
;; Modifies R0, R1 and R2
;; Does not utilize stack or heap
:main
	;; Read a byte
	LOADUI R1 0x1100
	FGETC

	;; Check for EOF
	CMPSKIP.GE R0 0
	JUMP @main_1

	;; Write the Byte
	FALSE R1
	FPUTC

	;; Check for LF
	CMPSKIP.NE R0 10            ; Skip if not line feed
	SUBI R2 R2 1                ; Decrement on line feed

	;; Loop if not Zero
	CMPSKIP.E R2 0              ; Skip if counter is zero
	JUMP @main

	;; Otherwise provide main loop functionality
	FGETC                       ; Wait for key press
	LOADUI R2 10                ; Reset counter
	JUMP @main                  ; And loop

:main_1
	;; Close up as we are done
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE
	HALT
