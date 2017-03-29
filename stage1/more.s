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
	CMPSKIPI.GE R0 0
	JUMP @main_1

	;; Write the Byte
	FALSE R1
	FPUTC

	;; Check for LF
	CMPSKIPI.NE R0 10           ; Skip if not line feed
	SUBI R2 R2 1                ; Decrement on line feed

	;; Loop if not Zero
	CMPSKIPI.E R2 0             ; Skip if counter is zero
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
