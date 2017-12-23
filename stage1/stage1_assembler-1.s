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
	LOADUI R11 0x200            ; Where we are putting our address pointers
	TRUE R12                    ; Our toggle
	FALSE R13                   ; Our PC counter
	LOADUI R14 $getLables_2     ; our first iterator
	;; We will be using R15 for holding our processed nybbles

	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE

	LOADUI R1 0x1100            ; Read from tape_01

;; Function for collecting the address of all labels
:getLables
	FGETC                       ; Read a Char

	;; Check for EOF
	JUMP.NP R0 @stage2

	;; Check for Label
	CMPSKIPI.NE R0 58           ; If the Char is : the next char is the label
	JUMP @storeLabel

	;; Check for pointer to label
	CMPSKIPI.NE R0 64           ; If the Char is @ the next char is the pointer to a label
	JUMP @ignorePointer

	;; Otherwise attempt to process
	JUMP @hex                   ; Convert it
:getLables_2
	JUMP.NP R0 @getLables       ; Don't record, nonhex values
	NOT R12 R12                 ; Flip the toggle
	JUMP.Z R12 @getLables       ; First half doesn't need anything

	;; Deal with case of second half of byte
	ADDUI R13 R13 1             ; increment PC now that we have a full byte
	JUMP @getLables

:ignorePointer
	;; Ignore the pointer for now
	FGETC                       ; Read a Char
	ADDUI R13 R13 2             ; The pointer will end up taking 2 bytes
	JUMP @getLables

;; Function for storing the address of the label
:storeLabel
	;; Get the char of the Label
	FGETC                       ; Read a Char

	;; We require 2 bytes to store the pointer values
	SL0I R0 1                   ; Thus we multiply our label by 2

	;; Store the current Program counter
	STOREX16 R13 R11 R0

	;; Label is safely stored, return
	JUMP @getLables


;; Now that we have all of the label addresses,
;; We can process input to produce our output
:stage2
	;; We first need to rewind tape_01 to perform our second pass
	LOADUI R0 0x1100
	REWIND

	;; Reset our toggle and counter
	LOADUI R9 0x1101            ; Where to write the combined byte
	TRUE R12                    ; Our toggle
	FALSE R13                   ; Our PC counter
	LOADUI R14 $loop_hex        ; The hex return target

:loop
	FGETC                       ; Read a Char

	;; Check for EOF
	JUMP.NP R0 @finish

	;; Check for Label
	CMPSKIPI.NE R0 58           ; Make sure we jump over the label
	JUMP @ignoreLabel

	;; Check for Pointer
	CMPSKIPI.NE R0 64            ; If it is a pointer Deal with it
	JUMP @storePointer

	;; Process Char
	JUMP @hex                   ; Convert it

:loop_hex
	JUMP.NP R0 @loop            ; Don't use nonhex chars
	NOT R12 R12                 ; Flip the toggle
	JUMP.NZ R12 @loop_second_nybble ; Jump if toggled

	;; Process first byte of pair
	ANDI R15 R0 0xF             ; Store First nibble
	JUMP @loop

:loop_second_nybble
	SL0I R15 4                  ; Shift our first nibble
	ANDI R0 R0 0xF              ; Mask out top
	ADD R0 R0 R15               ; Combine nibbles
	SWAP R1 R9                  ; Set to write to tape_2
	FPUTC                       ; To TAPE_02
	SWAP R1 R9                  ; Restore from tape_1
	ADDUI R13 R13 1             ; increment PC now that we have a full byte
	JUMP @loop                  ; Try to get more bytes

:ignoreLabel
	;; Consume next char
	FGETC                       ; Read a Char
	JUMP @loop

:storePointer
	;; Correct the PC to reflect the size of the pointer
	ADDUI R13 R13 2             ; Exactly 2 bytes

	;; Get the char of the Label
	FGETC                       ; Read a Char

	;; Since we stored a short pointer taking up 2 bytes
	SL0I R0 1                   ; Thus we multiply our label by 2 to get where it is stored
	LOADXU16 R3 R11 R0          ; Load the address of the label

	;; We now have to calculate the distance and store the 2 bytes
	SUB R3 R3 R13               ; First determine the difference between the current PC and the stored PC of the label
	ADDUI R3 R3 4               ; Adjust for relative positioning

	;; Store Upper byte
	ANDI R0 R3 0xFF00           ; Mask out everything but top byte
	SARI R0 8                   ; Drop the bottom 8 bits
	SWAP R1 R9                  ; Write the byte
	FPUTC                       ; To TAPE_02

	;; Store Lower byte
	ANDI R0 R3 0xFF             ; Preserve bottom half for later
	FPUTC                       ; Write the byte to TAPE_02
	SWAP R1 R9                  ; Restore Read
	JUMP @loop


;; Hex function
;; Returns hex value of ascii char
;; Or -1 if not a hex char
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
	;; Deal with all ascii less than 'A'
	CMPSKIPI.GE R0 65
	JUMP @ascii_other
	;; Unset high bit to set everything into uppercase
	ANDI R0 R0 0xDF
	;; Deal with 'A'-'F'
	CMPSKIPI.G R0 70
	JUMP @ascii_high
	;; Ignore the rest
	JUMP @ascii_other

:ascii_num
	SUBUI R0 R0 48
	JSR_COROUTINE R14
:ascii_high
	SUBUI R0 R0 55
	JSR_COROUTINE R14
:ascii_comment
	FGETC                       ; Read another char
	CMPSKIPI.E R0 10            ; Stop at the end of line
	JUMP @ascii_comment         ; Otherwise keep looping
:ascii_other
	TRUE R0
	JSR_COROUTINE R14

:finish
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE
	LOADUI R0 0x1101            ; Close TAPE_02
	FCLOSE
	HALT

;; Where all of our pointers will be stored for our locations
:table
