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

	# We will be using R0 and R1 to pass values to the function
	# R15 will be used as the stack pointer
:start
	LOADUI R0 @string
	LOADUI R1 0x100
	LOADUI R2 33
	LOADUI R3 44
	LOADUI R4 55
	LOADUI R15 0x600
	CALLI R15 @copy_string
	HALT
:string
	HALT
	HALT
	NOP

;;  Our simple string copy function
:copy_string
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	PUSHR R3 R15
	;; Setup registers
	MOVE R2 R1
	MOVE R1 R0
	LOADUI R3 0
:copy_byte
	LOADXU8 R0 R1 R3			; Get the byte
	STOREX8 R0 R2 R3			; Store the byte
	ADDUI R3 R3 1				; Prep for next loop
	JUMP.NZ R0 @copy_byte	; Stop if byte is NULL
;; Done
	;; Restore registers
	POPR R3 R15
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	RET R15
