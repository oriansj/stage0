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
	TRUE R11                    ; Our toggle
	LOADUI R13 0x600            ; Where we are starting our Stack
	;;  R14 will be storing our condition
	FALSE R15                   ; Our holder

	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_WRITE

	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE

:loop
	FALSE R1                    ; Read from tty
	FGETC                       ; Read a Char

	CMPSKIPI.NE R0 13           ; Replace all CR
	LOADUI R0 10                ; WIth LF

	FPUTC                       ; Display the Char to User

	;; Check for Ctrl-D
	CMPSKIPI.NE R0 4
	JUMP @finish

	;; Check for EOF
	JUMP.NP R0 @finish

	;; Write out unprocessed byte
	LOADUI R1 0x1101            ; Write to TAPE_02
	FPUTC                       ; Print the Char

	;; Convert byte to nybble
	CALLI R13 @hex              ; Convert it

	;; Get another byte if nonhex
	JUMP.NP R0 @loop            ; Don't use nonhex chars

	;; Deal with the case of second nybble
	JUMP.Z R11 @second_nybble   ; Jump if toggled

	;; Process first byte of pair
	ANDI R15 R0 0x0F            ; Store First nibble
	FALSE R11                   ; Flip the toggle
	JUMP @loop

	;; Combined second nybble in pair with first
:second_nybble
	SL0I R15 4                  ; Shift our first nibble
	ANDI R0 R0 0x0F             ; Mask out top
	ADD R0 R0 R15               ; Combine nibbles

	;; Writeout and prepare for next cycle
	TRUE R11                    ; Flip the toggle
	LOADUI R1 0x1100            ; Write the combined byte
	FPUTC                       ; To TAPE_01
	JUMP @loop                  ; Try to get more bytes

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
	FALSE R1                    ; Read from tty
	FGETC                       ; Read another char
	CMPSKIPI.NE R0 13           ; Replace all CR
	LOADUI R0 10                ; WIth LF
	FPUTC                       ; Let the user see it
	CMPUI R14 R0 10             ; Stop at the end of line
	LOADUI R1 0x1101            ; Write to TAPE_02
	FPUTC                       ; The char we just read
	JUMP.NE R14 @ascii_comment  ; Otherwise keep looping
	JUMP @ascii_other

:finish
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE
	LOADUI R0 0x1101            ; Close TAPE_02
	FCLOSE
	HALT
