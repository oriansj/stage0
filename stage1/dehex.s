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
	FALSE R14                   ; R14 will be storing our current address
	LOADUI R15 $end             ; We will be using R15 for our stack


;; Main program functionality
;; Reads in Tape_01 and writes out results to Tape_02
;; Accepts no arguments and HALTS when done
:main
	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE

	;; Perform main loop
:main_0
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char

	;; Check for EOF
	CMPSKIPI.GE R0 0
	JUMP @main_1

	;; Process that byte
	CALLI R15 @dehex

	;; Increment address
	ADDUI R14 R14 1

	;; Get next byte
	JUMP @main_0

:main_1
	;; Close up as we are done
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE
	LOADUI R0 0x1101            ; Close TAPE_02
	FCLOSE
	HALT


;; Dehex functionality
;; Accepts byte in R0
;; Prints address every 4th byte
;; Alters R0
;; Returns to whatever called it
:dehex
	PUSHR R1 R15                ; Preserve R1
	PUSHR R0 R15                ; Save byte until after address
	ANDI R0 R14 3               ; Get mod 4 of address
	LOADUI R1 0x1101            ; We want it on TAPE_02
	CMPSKIPI.E R0 0             ; if not zero
	JUMP @dehex_0               ; Skip placing address

	;; Prepend new line
	LOADUI R0 10                ; First print line feed
	FPUTC                       ; Write it

	;; Write out address
	COPY R0 R14                 ; Prep for call
	CALLI R15 @hex32            ; Let it handle the details

	;; Write out : char
	LOADUI R0 58                ; Prep
	FPUTC                       ; Write it

	;; Write out tab
	LOADUI R0 9                 ; Prep
	FPUTC                       ; Write it
:dehex_0
	POPR R0 R15                 ; Restore byte received
	CALLI R15 @hex8             ; Use a subset

	LOADUI R0 32                ; Prep for writing space
	FPUTC                       ; Write it
	POPR R1 R15                 ; Restore R1
	RET R15                     ; Return to caller


;; hex32 functionality
;; Accepts 32bit value in R0
;; Require R1 to be the device to write the results
;; Returns to whatever called it
:hex32
	PUSHR R0 R15
	SR0I R0 16                  ; Do high word first
	CALLI R15 @hex16
	POPR R0 R15
:hex16
	PUSHR R0 R15
	SR0I R0 8                   ; Do high byte first
	CALLI R15 @hex8
	POPR R0 R15
:hex8
	PUSHR R0 R15
	SR0I R0 4                   ; Do high nybble first
	CALLI R15 @hex4
	POPR R0 R15
:hex4
	ANDI R0 R0 0x000F           ; isolate nybble
	ADDUI R0 R0 48              ; convert to ascii
	CMPSKIPI.LE R0 57           ; If nybble was greater than '9'
	ADDUI R0 R0 7               ; Shift it into 'A' range of ascii
	FPUTC                       ; Print char
	RET R15                     ; Get next nybble or return if done


;; Where we are putting our stack
:end
