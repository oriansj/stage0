:start
	LOADUI R13 @table           ; Where we are putting our table
	;; We will be using R14 for our condition codes
	LOADUI R15 0x7FFF           ; We will be using R15 for our stack


;; Main program functionality
;; Reads in Tape_01 and writes out results onto Tape_02
;; Accepts no arguments and HALTS when done
:main
	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; Intialize environment
	FALSE R12                   ; Set holder to zero
	FALSE R11                   ; Set PC counter to zero
	LOADUI R10 1                ; Our toggle

	;; Perform first pass
	CALLI R15 @first_pass

	;; We need to rewind tape_01 to perform our second pass
	LOADUI R0 0x1100
	REWIND

	;; Reintialize environment
	FALSE R12                   ; Set holder to zero
	FALSE R11                   ; Set PC counter to zero
	LOADUI R10 1                ; Our toggle
	LOADUI R9 0xFF              ; Byte mask
	LOADUI R8 0x0F              ; nybble mask

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
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char

	;; Check for EOF
	CMPSKIP.GE R0 0
	RET R15

	;; Check for and deal with label (:)
	CMPSKIP.NE R0 58
	JUMP @storeLabel

	;; Check for and deal with pointers to labels
	;; Starting with (@)
	CMPSKIP.NE R0 64
	JUMP @ThrowAwayPointer

	;; Then dealing with ($)
	CMPSKIP.NE R0 36
	JUMP @ThrowAwayPointer

	;; Now check for absolute addresses (&)
	CMPSKIP.NE R0 38
	JUMP @ThrowAwayAddress

	;; Otherwise attempt to process
	CALLI R15 @hex              ; Convert it
	CMPSKIP.GE R0 0             ; Don't record, nonhex values
	JUMP @first_pass            ; Move onto Next char

	;; Determine if we got a full byte
	JUMP.Z R10 @first_pass_0    ; Jump if toggled

	;; Deal with case of first half of byte
	FALSE R10                   ; Flip the toggle
	JUMP @first_pass

:first_pass_0
	;; Deal with case of second half of byte
	TRUE R10                    ; Flip the toggle
	ADDUI R11 R11 1             ; increment PC now that that we have a full byte
	JUMP @first_pass


;; Second pass function
;; Reads from Tape_01 and uses the values in the table
;; To write desired contents onto Tape_02
;; Will Overwrite R0 R10 R11
;; Returns to Main function when done
:second_pass
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char

	;; Check for EOF
	CMPSKIP.GE R0 0
	RET R15

	;; Check for and deal with label
	CMPSKIP.NE R0 58
	JUMP @ThrowAwayLabel

	;; Check for and deal with Pointers to labels
	CMPSKIP.NE R0 64            ; @ for relative
	JUMP @StoreRelativePointer

	CMPSKIP.NE R0 36            ; $ for absolute
	JUMP @StoreAbsolutePointer

	CMPSKIP.NE R0 38            ; & for address
	JUMP @StoreAbsoluteAddress

	;; Process everything else
	CALLI R15 @hex              ; Attempt to Convert it
	CMPSKIP.GE R0 0             ; Don't record, nonhex values
	JUMP @second_pass           ; Move onto Next char

	;; Determine if we got a full byte
	JUMP.Z R10 @second_pass_0   ; Jump if toggled

	;; Deal with case of first half of byte
	AND R12 R0 R8               ; Store our first nibble
	FALSE R10                   ; Flip the toggle
	JUMP @second_pass

:second_pass_0
	;; Deal with case of second half of byte
	SL0I R12 4                  ; Shift our first nybble
	AND R0 R0 R8                ; Mask out top
	ADD R0 R0 R12               ; Combine nybbles
	TRUE R10                    ; Flip the toggle
	LOADUI R1 0x1101            ; Write the combined byte
	FPUTC                       ; To TAPE_02
	ADDUI R11 R11 1             ; increment PC now that that we have a full byte
	JUMP @second_pass


;; Store Label function
;; Writes out the token and the current PC value
;; Its static variable for storing the next index to be used
;; Will overwrite R0
;; Returns to first pass when done
:storeLabel
	LOADR R0 @current_index     ; Get address of first open index
	CMPSKIP.NE R0 0             ; If zero intialize from R13
	COPY R0 R13

	;; Store the PC of the label
	STORE32 R11 R0 0

	;; Store the name of the Label
	ADDUI R0 R0 4               ; Increment the offset of the index
	CALLI R15 @writeout_token

	;; Update our index
	ADDUI R0 R0 60              ; Hopefully our tokens are less than 60 bytes long
	STORER R0 @current_index
	;; And be done
	JUMP @first_pass

;; Where we are storing the location of the next free table entry
:current_index
	NOP


;; StoreRelativepointer function
;; Deals with the special case of relative pointers
;; Clears Temp
;; Stores string in Temp
;; Finds match in Table
;; Writes out the offset
;; Modifies R0 R11
;; Jumps back into Pass2
:StoreRelativePointer
	;; Correct the PC to reflect the size of the pointer
	ADDUI R11 R11 2             ; Exactly 2 bytes
	LOADUI R0 $Temp             ; Set where we want to shove our string
	CALLI R15 @Clear_string     ; Clear it
	CALLI R15 @writeout_token   ; Write it
	CALLI R15 @Match_string     ; Find the Match
	LOAD32 R0 R0 -4             ; Get the value we care about
	SUB R0 R0 R11               ; Determine the difference
	ADDUI R0 R0 4               ; Adjust for relative positioning
	CALLI R15 @ProcessImmediate ; Write out the value
	JUMP @second_pass


;; StoreAbsolutepointer function
;; Deals with the special case of absolute pointers
;; Clears Temp
;; Stores string in Temp
;; Finds match in Table
;; Writes out the absolute address of match
;; Modifies R0 R11
;; Jumps back into Pass2
:StoreAbsolutePointer
	;; Correct the PC to reflect the size of the pointer
	ADDUI R11 R11 2             ; Exactly 2 bytes
	LOADUI R0 $Temp             ; Set where we want to shove our string
	CALLI R15 @Clear_string     ; Clear it
	CALLI R15 @writeout_token   ; Write it
	CALLI R15 @Match_string     ; Find the Match
	LOAD32 R0 R0 -4             ; Get the value we care about
	CALLI R15 @ProcessImmediate ; Write out the value
	JUMP @second_pass


;; StoreAbsoluteAddress function
;; Deal with the special case of absolute Addresses
;; Clear Temp
;; Stores string in Temp
;; Finds match in Table
;; Writes out the full absolute address [32 bit machine]
;; Modifies R0 R11
;; Jumpbacs back into Pass2
:StoreAbsoluteAddress
	;; COrrect the PC to reflect the size of the address
	ADDUI R11 R11 4             ; 4 Bytes on 32bit machines
	LOADUI R0 $Temp             ; Set where we ant to shove our string
	CALLI R15 @Clear_string     ; Clear it
	CALLI R15 @writeout_token   ; Write it
	CALLI R15 @Match_string     ; Find the Match
	PUSHR R14 R15               ; Get a temp storage place
	LOAD32 R14 R0 -4            ; Get the value we care about
	COPY R0 R14                 ; We need to print the top 2 bytes first
	SARI R0 16                  ; Drop bottom 16 bits
	CALLI R15 @ProcessImmediate ; Write out top 2 bytes
	LOADUI R0 0xFFFF            ; Provide mask to keep bottom 2 bytes
	AND R0 R0 R14               ; Drop top 16 bits
	POPR R14 R15                ; Restore R14
	CALLI R15 @ProcessImmediate ; Write out bottom 2 bytes
	JUMP @second_pass


;; Writeout Token Function
;; Writes the Token [minus first char] to the address
;; It recieves in R0 until it reaches a delimiter
;; All register values are preserved
;; Returns to whatever called it
:writeout_token
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15

	;; Initialize
	MOVE R2 R0                  ; Set R2 as our index
	LOADUI R1 0x1100            ; Read from tape_01

	;; Our core loop
:writeout_token_0
	FGETC                       ; Get another byte

	;; Deal with termination cases
	CMPSKIP.NE R0 32            ; Finished if space
	JUMP @writeout_token_done
	CMPSKIP.NE R0 9             ; Finished if tab
	JUMP @writeout_token_done
	CMPSKIP.NE R0 10            ; Finished if newline
	JUMP @writeout_token_done

	;; Deal with valid input
	STORE8 R0 R2 0              ; Write out the byte
	ADDUI R2 R2 1               ; Increment
	JUMP @writeout_token_0      ; Keep looping

	;; Clean up now that we are done
:writeout_token_done
	;; Restore registers
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	;; And be done
	RET R15


;; Clear string function
;; Clears string pointed at by the value of R0
;; Until a null character is reached
;; Doesn't alter any registers
;; Returns to the function that calls it
:Clear_string
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	PUSHR R3 R15
	;; Setup registers
	MOVE R1 R0
	LOADUI R2 0
	LOADUI R3 0
:clear_byte
	LOADXU8 R0 R1 R2            ; Get the byte
	STOREX8 R3 R1 R2            ; Overwrite with a Zero
	ADDUI R2 R2 1               ; Prep for next loop
	JUMP.NZ R0 @clear_byte      ; Stop if byte is NULL
;; Done
	;; Restore registers
	POPR R3 R15
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	RET R15


;; Match string function
;; Walks down table until match is found
;; Then returns address of matching string in R0
;; Returns to whatever called it
:Match_string
	;; Preserve registers
	PUSHR R1 R15
	PUSHR R2 R15

	;; Initialize for Loop
	LOADUI R1 $Temp             ; We always compare against Temp
	LOADUI R2 $table            ; Begin at start of table
	ADDUI R2 R2 4               ; Where the string is located

;; Loop until we find a match
:Match_string_0
	COPY R0 R2                  ; Set R0 to our current string
	CALLI R15 @strcmp
	JUMP.E R0 @Match_string_1   ; It is a match!
	;; Prepare for next loop
	LOADUI R1 $Temp             ; That function clears R1
	ADDUI R2 R2 64              ; Each Index is 64 bytes
	JUMP @Match_string_0        ; Keep looping

:Match_string_1
	;; Store the correct answer
	MOVE R0 R2
	;; Restore registers
	POPR R2 R15
	POPR R1 R15
	RET R15


;; Our simple string compare function
;; Recieves two pointers in R0 and R1
;; Returns the difference between the strings in R0
;; Clears R1
;; Returns to whatever called it
:strcmp
	;; Preserve registers
	PUSHR R2 R15
	PUSHR R3 R15
	PUSHR R4 R15
	;; Setup registers
	MOVE R2 R0
	MOVE R3 R1
	LOADUI R4 0
:cmpbyte
	LOADXU8 R0 R2 R4        ; Get a byte of our first string
	LOADXU8 R1 R3 R4        ; Get a byte of our second string
	ADDUI R4 R4 1           ; Prep for next loop
	CMP R1 R0 R1            ; Compare the bytes
	CMPSKIP.E R0 0          ; Stop if byte is NULL
	JUMP.E R1 @cmpbyte      ; Loop if bytes are equal
;; Done
	MOVE R0 R1              ; Prepare for return
	;; Restore registers
	POPR R4 R15
	POPR R3 R15
	POPR R2 R15
	RET R15


;; Processimmediate Function
;; Recieves an integer value in R0
;; Writes out the values to Tape_02
;; Doesn't modify registers
;; Returns to whatever called it
:ProcessImmediate
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	;; Break up Immediate
	AND R2 R0 R9            ; Put lower byte in R2
	SARI R0 8               ; Drop Bottom byte from R0
	AND R0 R0 R9            ; Maskout everything outside of top byte
	;; Write out Top Byte
	LOADUI R1 0x1101            ; Write the byte
	FPUTC                       ; To TAPE_02

	;; Write out bottom Byte
	MOVE R0 R2                  ; Put Lower byte in R0
	LOADUI R1 0x1101            ; Write the byte
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
	LOADUI R1 0x1100            ; Read from tape_01
	FGETC                       ; Read a Char

	;; Stop looping if space
	CMPSKIP.NE R0 32
	RET R15

	;; Stop looping if tab
	CMPSKIP.NE R0 9
	RET R15

	;; Stop looping if newline
	CMPSKIP.NE R0 10
	RET R15

	;; Otherwise keep looping
	JUMP @throwAwayToken


;; Hex function
;; This function is serving three purposes:
;; Identifying hex characters
;; Purging line comments
;; Returning the converted value of a hex character
;; This function will alter the values of R0 R14
;; Returns back to whatever called it
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
	RET R15
:ascii_low
	SUBUI R0 R0 87
	RET R15
:ascii_high
	SUBUI R0 R0 55
	RET R15
:ascii_other
	TRUE R0
	RET R15
:ascii_comment
	LOADUI R1 0x1100            ; Read from TAPE_01
	FGETC                       ; Read another char
	CMPUI R14 R0 10             ; Stop at the end of line
	JUMP.NE R14 @ascii_comment  ; Otherwise keep looping
	JUMP @ascii_other


;; Where we are storing our Temp
:Temp
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP


;; Where we will putting our Table
:table
