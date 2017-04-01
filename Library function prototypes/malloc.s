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

	# We will be using R0 request a number of bytes
	# The pointer to the block of that size is to be
	# passed back in R0, for simplicity sake
	# R15 will be used as the stack pointer
:start
	LOADUI R15 @stack
	LOADUI R0 22                ; Allocate 22 bytes
	CALLI R15 @malloc
	LOADUI R0 42                ; Allocate 42 bytes
	CALLI R15 @malloc
	HALT

;;  Our simple malloc function
:malloc
	;; Preserve registers
	PUSHR R1 R15
	;; Get current malloc pointer
	LOADR R1 @malloc_pointer
	;; Deal with special case
	CMPSKIPI.NE R1 0            ; If Zero set to our start of heap space
	LOADUI R1 0x600

	;; update malloc pointer
	SWAP R0 R1
	ADD R1 R0 R1
	STORER R1 @malloc_pointer

;; Done
	;; Restore registers
	POPR R1 R15
	RET R15
;; Our static value for malloc pointer
:malloc_pointer
	NOP

;; Start stack at end of instructions
:stack
