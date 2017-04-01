; Copyright (C) 2016 Jeremiah Orians
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

:start
	LOADUI R10 0x0F             ; Byte mask
	LOADUI R11 1                ; Our toggle
	LOADUI R13 0x600            ; Where we are starting our Stack
	;; R14 is storing our condition code
	;; R15 is storing our nybble

	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE


;; Main program loop
;; Halts when done
:loop
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char

	;; Check for EOF
	CMPI R14 R0 0
	JUMP.GE R14 @.L1
	CALLI R13 @finish

:.L1
	LOADUI R1 0                 ; Write to Char to TTY
	FPUTC                       ; Print the Char
	CALLI R13 @hex              ; Convert it
	CMPI R14 R0 0               ; Check if it is hex
	JUMP.L R14 @loop            ; Don't use nonhex chars
	JUMP.Z R11 @.L99            ; Jump if toggled

	;; Process first byte of pair
	AND R15 R0 R10              ; Store First nibble
	FALSE R11                   ; Flip the toggle
	JUMP @loop

:.L99
	SL0I R15 4                  ; Shift our first nibble
	AND R0 R0 R10               ; Mask out top
	ADD R0 R0 R15               ; Combine nibbles
	LOADI R11 1                 ; Flip the toggle
	LOADUI R1 0x1101            ; Write the combined byte
	FPUTC                       ; To TAPE_02
	JUMP @loop                  ; Try to get more bytes


;; Hex function
;; Converts Ascii chars to their hex values
;; Or -1 if not a hex char
;; Returns to whatever called it
:hex
	;; Deal with line comments starting with #
	CMPUI R14 R0 35
	JUMP.E R14 @ascii_comment
	;; Deal with line comments starting with ;
	CMPUI R14 R0 59
	JUMP.E R14 @ascii_comment
	;; Deal with all ascii less than '0'
	CMPUI R14 R0 48
	JUMP.L R14 @ascii_other
	;; Deal with '0'-'9'
	CMPUI R14 R0 57
	JUMP.LE R14 @ascii_num
	;; Deal with all ascii less than 'A'
	CMPUI R14 R0 65
	JUMP.L R14 @ascii_other
	;; Deal with 'A'-'F'
	CMPUI R14 R0 70
	JUMP.LE R14 @ascii_high
	;; Deal with all ascii less than 'a'
	CMPUI R14 R0 97
	JUMP.L R14 @ascii_other
	;;  Deal with 'a'-'f'
	CMPUI R14 R0 102
	JUMP.LE R14 @ascii_low
	;; Ignore the rest
	JUMP @ascii_other

:ascii_num
	SUBUI R0 R0 48
	RET R13
:ascii_low
	SUBUI R0 R0 87
	RET R13
:ascii_high
	SUBUI R0 R0 55
	RET R13
:ascii_other
	TRUE R0
	RET R13
:ascii_comment
	LOADUI R1 0x1100            ; Read from TAPE_01
	FGETC                       ; Read another char
	CMPUI R14 R0 10             ; Stop at the end of line
	LOADUI R1 0                 ; Write to TTY
	FPUTC                       ; The char we just read
	JUMP.NE R14 @ascii_comment  ; Otherwise keep looping
	JUMP @ascii_other


;; Finish function
;; Cleans up at the end of the program
;; Performs the HALT
:finish
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE
	LOADUI R0 0x1101            ; Close TAPE_02
	FCLOSE
	HALT
