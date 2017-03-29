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
	LOADUI R8 @table            ; Where we are putting our address pointers
	LOADUI R9 0xFF              ; Byte mask
	LOADUI R10 0x0F             ; nybble mask
	LOADUI R11 1                ; Our toggle
	FALSE R12                   ; Our PC counter
	LOADUI R13 0x600            ; Where we are starting our Stack
	;; We will be using R14 for our condition codes
	;; We will be using R15 for holding our processed nybbles

	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE


;; Function for collecting the address of all labels
:getLables
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char

	;; Check for EOF
	CMPSKIPI.GE R0 0
	JUMP @stage2

	;; Check for Label
	CMPSKIPI.NE R0 58           ; If the Char is : the next char is the label
	CALLI R13 @storeLabel

	;; Check for pointer to label
	CMPUI R14 R0 64             ; If the Char is @ the next char is the pointer to a label
	JUMP.NE R14 @.L0

	;; Ignore the pointer for now
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char

	ADDUI R12 R12 2             ; The pointer will end up taking 2 bytes
	JUMP @getLables

:.L0
	;; Otherwise attempt to process
	CALLI R13 @hex              ; Convert it
	CMPSKIPI.GE R0 0            ; Don't record, nonhex values
	JUMP @getLables             ; Move onto Next char

	;; Determine if we got a full byte
	JUMP.Z R11 @.L1             ; Jump if toggled

	;; Deal with case of first half of byte
	FALSE R11                   ; Flip the toggle
	JUMP @getLables

:.L1
	;; Deal with case of second half of byte
	TRUE R11                    ; Flip the toggle
	ADDUI R12 R12 1             ; increment PC now that we have a full byte
	JUMP @getLables

;; Function for storing the address of the label
:storeLabel
	;; Get the char of the Label
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char

	;; We require 4 bytes to store the pointer values
	SL0I R0 2                   ; Thus we multiply our label by 4

	;; Store the current Program counter
	STOREX R12 R8 R0

	;; Label is safely stored, return
	RET R13

;; Main Functionality
:stage2
	;; We first need to rewind tape_01 to perform our second pass
	LOADUI R0 0x1100
	REWIND

	;; Reset our toggle and counter, just in case
	LOADUI R11 1                ; Our toggle
	FALSE R12                   ; Our PC counter

:loop
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char

	;; Check for EOF
	CMPSKIPI.GE R0 0
	JUMP @finish

	;; Check for Label
	CMPUI R14 R0 58             ; Make sure we jump over the label
	JUMP.NE R14 @.L97

	;; Consume next char
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char
	JUMP @loop

:.L97
	;; Check for Pointer
	CMPUI R14 R0 64             ; If it is a pointer Deal with it
	JUMP.NE R14 @.L98           ; Otherwise attempt to process it
	CALLI R13 @storePointer
	JUMP @loop

:.L98
	;; Process Char
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
	TRUE R11                    ; Flip the toggle
	LOADUI R1 0x1101            ; Write the combined byte
	FPUTC                       ; To TAPE_02
	ADDUI R12 R12 1             ; increment PC now that we have a full byte
	JUMP @loop                  ; Try to get more bytes

:storePointer
	;; Correct the PC to reflect the size of the pointer
	ADDUI R12 R12 2             ; Exactly 2 bytes

	;; Get the char of the Label
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char

	;; Since we stored a full pointer taking up 4 bytes
	SL0I R0 2                   ; Thus we multiply our label by 4 to get where it is stored
	LOADX R2 R8 R0              ; Load the address of the label

	;; We now have to calculate the distance and store the 2 bytes
	SUB R2 R2 R12               ; First determine the difference between the current PC and the stored PC of the label
	ADDUI R2 R2 4               ; Adjust for relative positioning

	;; Store Upper byte
	COPY R0 R2
	SARI R0 8                   ; Drop the bottom 8 bits
	AND R0 R0 R9                ; Mask out everything but bottom bits
	LOADUI R1 0x1101            ; Write the byte
	FPUTC                       ; To TAPE_02

	;; Store Lower byte
	AND R0 R2 R9                ; Drop everything but the bottom 8 bits
	FPUTC                       ; Write the byte to TAPE_02
	RET R13


;; Hex function
;; Returns hex value of ascii char
;; Or -1 if not a hex char
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

:finish
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE
	LOADUI R0 0x1101            ; Close TAPE_02
	FCLOSE
	HALT


;; Where all of our pointers will be stored for our locations
:table
