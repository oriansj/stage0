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
	LOADUI R11 1                ; Our toggle
	;; R14 is storing our condition code
	;; R15 is storing our nybble

	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE

	LOADUI R1 0x1100            ; Read from tape_01

;; Main program loop
;; Halts when done
:loop
	FGETC                       ; Read a Char

	;; Check for EOF
	JUMP.NP R0 @finish

	JUMP @hex                   ; Convert it
:loop_1
	JUMP.NP R0 @loop            ; Don't use nonhex chars
	JUMP.Z R11 @loop_2          ; Jump if toggled

	;; Process first byte of pair
	ANDI R15 R0 0xF             ; Store First nibble
	FALSE R11                   ; Flip the toggle
	JUMP @loop

:loop_2
	SL0I R15 4                  ; Shift our first nibble
	ANDI R0 R0 0xF              ; Mask out top
	ADD R0 R0 R15               ; Combine nibbles
	LOADI R11 1                 ; Flip the toggle
	LOADUI R1 0x1101            ; Write the combined byte
	FPUTC                       ; To TAPE_02
	LOADUI R1 0x1100            ; Read from tape_01
	JUMP @loop                  ; Try to get more bytes


;; Hex function
;; Converts Ascii chars to their hex values
;; Or -1 if not a hex char
;; Returns to whatever called it
:hex
	;; Deal with line comments starting with #
	CMPSKIPI.NE R0 35
	JUMP @ascii_comment
	;; Deal with line comments starting with ;
	CMPSKIPI.NE R0 59
	JUMP @ascii_comment
	;; Deal with all ascii less than '0'
	CMPSKIPI.GE R0 48
	JUMP @ascii_other
	;; Deal with '0'-'9'
	CMPSKIPI.G R0 57
	JUMP @ascii_num
	;; Unset high bit to set everything into uppercase
	ANDI R0 R0 0xDF
	;; Deal with all ascii less than 'A'
	CMPSKIPI.GE R0 65
	JUMP @ascii_other
	;; Deal with 'A'-'F'
	CMPSKIPI.G R0 70
	JUMP @ascii_high
	;; Ignore the rest
	JUMP @ascii_other

:ascii_num
	SUBUI R0 R0 48
	JUMP @loop_1
:ascii_high
	SUBUI R0 R0 55
	JUMP @loop_1
:ascii_comment
	FGETC                       ; Read another char
	CMPSKIPI.E R0 10            ; Stop at the end of line
	JUMP @ascii_comment         ; Otherwise keep looping
:ascii_other
	TRUE R0
	JUMP @loop_1


;; Finish function
;; Cleans up at the end of the program
;; Performs the HALT
:finish
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE
	LOADUI R0 0x1101            ; Close TAPE_02
	FCLOSE
	HALT
