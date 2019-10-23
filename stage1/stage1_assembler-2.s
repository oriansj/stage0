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

;; Node format:
;; PREV->pointer (register size)
;; Address (register size)
;; NULL terminated string (strln + 1)

:start
	;; R1 is reserved for reading/writing bytes (don't touch)
	;; We will be using R8 for our malloc pointer
	;; We will be using R9 for our header size in bytes
	;; We will be using R10 for our toggle
	;; We will be using R11 for our PC counter
	;; We will be using R12 for holding our nybble
	;; We will be using R13 for our register size in bytes
	;; We will be using R14 for our head-node
	LOADUI R15 $stack           ; We will be using R15 for our stack


;; Main program functionality
;; Reads in Tape_01 and writes out results onto Tape_02
;; Accepts no arguments and HALTS when done
:main
	;; Initialize header info
	READSCID R0                 ; Get process capabilities
	ANDI R1 R0 0xF              ; We only care about size nybble
	LOADUI R0 1                 ; Assume we are 8bit
	SL0 R13 R0 R1               ; Let size nybble correct answer
	COPY R9 R13                 ; Prepare Header size
	SL0I R9 1                   ; Double to make proper size

	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; Intialize environment
	LOADUI R1 0x1100            ; Read from tape_01
	FALSE R12                   ; Set holder to zero
	FALSE R11                   ; Set PC counter to zero
	FALSE R10                   ; Our toggle
	LOADUI R8 0x700             ; Where we want our heap to start

	;; Perform first pass
	CALLI R15 @first_pass

	;; We need to rewind tape_01 to perform our second pass
	LOADUI R0 0x1100
	REWIND

	;; Reintialize environment
	FALSE R12                   ; Set holder to zero
	FALSE R11                   ; Set PC counter to zero
	FALSE R10                   ; Our toggle

	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE

	CALLI R15 @second_pass

	;; Close up as we are done
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE
	LOADUI R0 0x1101            ; Close TAPE_02
	FCLOSE
	HALT


;; First pass function
;; Reads Tape_01 and creates our label table
;; Will Overwrite R0 R10 R11
;; Returns to Main function when done
:first_pass
	FGETC                       ; Read a Char

	;; Check for EOF
	CMPSKIPI.GE R0 0
	RET R15

	;; Check for and deal with label (:)
	CMPSKIPI.NE R0 58
	JUMP @storeLabel

	;; Check for and deal with pointers to labels
	;; Starting with (@)
	CMPSKIPI.NE R0 64
	JUMP @ThrowAwayPointer

	;; Then dealing with ($)
	CMPSKIPI.NE R0 36
	JUMP @ThrowAwayPointer

	;; Now check for absolute addresses (&)
	CMPSKIPI.NE R0 38
	JUMP @ThrowAwayAddress

	;; Otherwise attempt to process
	CALLI R15 @hex              ; Convert it
	JUMP.NP R0 @first_pass      ; Don't record, nonhex values

	;; Flip the toggle
	NOT R10 R10
	JUMP.Z R10 @first_pass      ; Jump if toggled

	;; Deal with case of second half of byte
	ADDUI R11 R11 1             ; increment PC now that that we have a full byte
	JUMP @first_pass


;; Second pass function
;; Reads from Tape_01 and uses the values in the table
;; To write desired contents onto Tape_02
;; Will Overwrite R0 R10 R11
;; Returns to Main function when done
:second_pass
	FGETC                       ; Read a Char

	;; Check for EOF
	CMPSKIPI.GE R0 0
	RET R15

	;; Check for and deal with label
	CMPSKIPI.NE R0 58
	JUMP @ThrowAwayLabel

	;; Check for and deal with Pointers to labels
	CMPSKIPI.NE R0 64           ; @ for relative
	JUMP @StoreRelativePointer

	CMPSKIPI.NE R0 36           ; $ for absolute
	JUMP @StoreAbsolutePointer

	CMPSKIPI.NE R0 38           ; & for address
	JUMP @StoreAbsoluteAddress

	;; Process everything else
	CALLI R15 @hex              ; Attempt to Convert it
	CMPSKIPI.GE R0 0            ; Don't record, nonhex values
	JUMP @second_pass           ; Move onto Next char

	;; Determine if we got a full byte
	NOT R10 R10
	JUMP.Z R10 @second_pass_0   ; Jump if toggled

	;; Deal with case of first half of byte
	ANDI R12 R0 0x0F            ; Store our first nibble
	JUMP @second_pass

:second_pass_0
	;; Deal with case of second half of byte
	SL0I R12 4                  ; Shift our first nybble
	ANDI R0 R0 0x0F             ; Mask out top
	ADD R0 R0 R12               ; Combine nybbles
	LOADUI R1 0x1101            ; Write the combined byte
	FPUTC                       ; To TAPE_02
	LOADUI R1 0x1100            ; Read from tape_01
	ADDUI R11 R11 1             ; increment PC now that that we have a full byte
	JUMP @second_pass


;; Store Label function
;; Writes out the token and the current PC value
;; Its static variable for storing the next index to be used
;; Will overwrite R0
;; Returns to first pass when done
:storeLabel
	COPY R0 R8                  ; get current malloc
	ADD R8 R8 R9                ; update malloc

	;; Add node info
	STOREX R11 R0 R13           ; Store the PC of the label
	STORE R14 R0 0              ; Store the Previous Head
	MOVE R14 R0                 ; Update Head

	;; Store the name of the Label
	CALLI R15 @writeout_token

	;; And be done
	JUMP @first_pass


;; StoreRelativepointer function
;; Deals with the special case of relative pointers
;; Stores string
;; Finds match in Table
;; Writes out the offset
;; Modifies R0 R11
;; Jumps back into Pass2
:StoreRelativePointer
	;; Correct the PC to reflect the size of the pointer
	ADDUI R11 R11 2             ; Exactly 2 bytes
	CALLI R15 @Match_string     ; Find the Match
	SUB R0 R0 R11               ; Determine the difference
	CALLI R15 @ProcessImmediate ; Write out the value
	JUMP @second_pass


;; StoreAbsolutepointer function
;; Deals with the special case of absolute pointers
;; Stores string
;; Finds match in Table
;; Writes out the absolute address of match
;; Modifies R0 R11
;; Jumps back into Pass2
:StoreAbsolutePointer
	;; Correct the PC to reflect the size of the pointer
	ADDUI R11 R11 2             ; Exactly 2 bytes
	CALLI R15 @Match_string     ; Find the Match
	CALLI R15 @ProcessImmediate ; Write out the value
	JUMP @second_pass


;; StoreAbsoluteAddress function
;; Deal with the special case of absolute Addresses
;; Stores string
;; Finds match in Table
;; Writes out the full absolute address [32 bit machine]
;; Modifies R0 R11
;; Jumpbacs back into Pass2
:StoreAbsoluteAddress
	;; COrrect the PC to reflect the size of the address
	ADDUI R11 R11 4             ; 4 Bytes on 32bit machines
	CALLI R15 @Match_string     ; Find the Match
	ANDI R2 R0 0xFFFF           ; Save bottom half for next function
	SARI R0 16                  ; Drop bottom 16 bits
	CALLI R15 @ProcessImmediate ; Write out top 2 bytes
	MOVE R0 R2                  ; Use the saved 16bits
	CALLI R15 @ProcessImmediate ; Write out bottom 2 bytes
	JUMP @second_pass


;; Writeout Token Function
;; Writes the Token [minus first char] to the address
;; given by malloc and updates malloc pointer
;; Returns starting address of string
:writeout_token
	;; Preserve registers
	PUSHR R1 R15
	PUSHR R2 R15

	;; Initialize
	COPY R2 R8                  ; Get current malloc pointer

	;; Our core loop
:writeout_token_0
	FGETC                       ; Get another byte

	;; Deal with termination cases
	CMPSKIPI.NE R0 32           ; Finished if space
	JUMP @writeout_token_done
	CMPSKIPI.NE R0 9            ; Finished if tab
	JUMP @writeout_token_done
	CMPSKIPI.NE R0 10           ; Finished if newline
	JUMP @writeout_token_done
	CMPSKIPI.NE R0 -1           ; Finished if EOF
	JUMP @writeout_token_done

	;; Deal with valid input
	STORE8 R0 R8 0              ; Write out the byte
	ADDUI R8 R8 1               ; Increment
	JUMP @writeout_token_0      ; Keep looping

	;; Clean up now that we are done
:writeout_token_done
	;; Fix malloc
	ADDUI R8 R8 1
	;; Prepare for return
	MOVE R0 R2
	;; Restore registers
	POPR R2 R15
	POPR R1 R15
	;; And be done
	RET R15


;; Match string function
;; Walks down list until match is found or returns -1
;; Reads a token
;; Then returns address of match in R0
;; Returns to whatever called it
:Match_string
	;; Preserve registers
	PUSHR R1 R15
	PUSHR R2 R15

	;; Initialize for Loop
	CALLI R15 @writeout_token   ; Get our desired string
	MOVE R1 R0                  ; Position our desired string
	COPY R2 R14                 ; Begin at our head node

;; Loop until we find a match
:Match_string_0
	ADD R0 R2 R9                ; Where the string is located
	CALLI R15 @strcmp
	JUMP.E R0 @Match_string_1   ; It is a match!
	;; Prepare for next loop
	LOAD R2 R2 0                ; Move to next node
	JUMP.NZ R2 @Match_string_0  ; Keep looping
	TRUE R2                     ; Set result to -1 if not found

:Match_string_1
	;; Store the correct answer
	CMPSKIPI.E R2 -1            ; Otherwise get the value
	LOADX R0 R2 R13             ; Get the value we care about
	;; Restore registers
	POPR R2 R15
	POPR R1 R15
	RET R15


;; Our simple string compare function
;; Receives two pointers in R0 and R1
;; Returns the difference between the strings in R0
;; Returns to whatever called it
:strcmp
	;; Preserve registers
	PUSHR R1 R15
	PUSHR R2 R15
	PUSHR R3 R15
	PUSHR R4 R15
	;; Setup registers
	MOVE R2 R0
	MOVE R3 R1
	LOADUI R4 0
:cmpbyte
	LOADXU8 R0 R2 R4            ; Get a byte of our first string
	LOADXU8 R1 R3 R4            ; Get a byte of our second string
	ADDUI R4 R4 1               ; Prep for next loop
	CMP R1 R0 R1                ; Compare the bytes
	CMPSKIPI.E R0 0             ; Stop if byte is NULL
	JUMP.E R1 @cmpbyte          ; Loop if bytes are equal
;; Done
	MOVE R0 R1                  ; Prepare for return
	;; Restore registers
	POPR R4 R15
	POPR R3 R15
	POPR R2 R15
	POPR R1 R15
	RET R15


;; Processimmediate Function
;; Receives an integer value in R0
;; Writes out the values to Tape_02
;; Doesn't modify registers
;; Returns to whatever called it
:ProcessImmediate
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	;; Break up Immediate
	ANDI R2 R0 0xFF             ; Put lower byte in R2
	SARI R0 8                   ; Drop Bottom byte from R0
	ANDI R0 R0 0xFF             ; Maskout everything outside of top byte
	;; Write out Top Byte
	LOADUI R1 0x1101            ; Write the byte
	FPUTC                       ; To TAPE_02

	;; Write out bottom Byte
	MOVE R0 R2                  ; Put Lower byte in R0
	FPUTC                       ; To TAPE_02

	;; Restore registers
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	;; Be Done
	RET R15


;; ThrowAwaypointer function
;; Handle the special case of a generic problem
;; for Pass1, Will update R11 and modify R0
;; Will return to the start of first_pass
;; Never call this function, only jump to it
:ThrowAwayPointer
	ADDUI R11 R11 2             ; Pointers always take up 2 bytes
	CALLI R15 @throwAwayToken   ; Get rid of rest of token
	JUMP @first_pass            ; Then return to the proper place


;; ThrowAwayAddress function
;; Handle the case of a 32bit absolute address storage
;; for Pass1, Will update R11 and modify R0
;; Will return to the start of first_pass
;; Never call this function, conly jump to it
:ThrowAwayAddress
	ADDUI R11 R11 4             ; Addresses on 32bit systems take up 4 bytes
	CALLI R15 @throwAwayToken   ; Get rid of rest of token
	JUMP @first_pass            ; Then return to the proper place


;; ThrowAwaylabel function
;; Handle the special case of a generic problem
;; for Pass2, Will update R11 and modify R0
;; Will return to the start of second_pass
;; Never call this function, only jump to it
:ThrowAwayLabel
	CALLI R15 @throwAwayToken   ; Get rid of rest of token
	JUMP @second_pass

;; Throw away token function
;; Deals with the general case of not wanting
;; The rest of the characters in a token
;; This Will alter the values of R0 R1
;; Returns back to whatever called it
:throwAwayToken
	FGETC                       ; Read a Char

	;; Stop looping if space
	CMPSKIPI.NE R0 32
	RET R15

	;; Stop looping if tab
	CMPSKIPI.NE R0 9
	RET R15

	;; Stop looping if newline
	CMPSKIPI.NE R0 10
	RET R15

	;; Stop looping if EOF
	CMPSKIPI.NE R0 -1
	RET R15

	;; Otherwise keep looping
	JUMP @throwAwayToken


;; Hex function
;; This function is serving three purposes:
;; Identifying hex characters
;; Purging line comments
;; Returning the converted value of a hex character
;; This function will alter the values of R0
;; Returns back to whatever called it
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
	RET R15
:ascii_high
	SUBUI R0 R0 55
	RET R15
:ascii_comment
	FGETC                       ; Read another char
	JUMP.NP R0 @ascii_other     ; Stop with EOF
	CMPSKIPI.E R0 10            ; Stop at the end of line
	JUMP @ascii_comment         ; Otherwise keep looping
:ascii_other
	TRUE R0
	RET R15


;; Where we will putting our stack
:stack
