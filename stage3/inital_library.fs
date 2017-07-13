\ Copyright (C) 2017 Jeremiah Orians
\ Copyright (C) 2017 Reepca
\ This file is part of stage0.
\
\ stage0 is free software: you can redistribute it and/or modify
\ it under the terms of the GNU General Public License as published by
\ the Free Software Foundation, either version 3 of the License, or
\ (at your option) any later version.
\
\ stage0 is distributed in the hope that it will be useful,
\ but WITHOUT ANY WARRANTY; without even the implied warranty of
\ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
\ GNU General Public License for more details.
\
\ You should have received a copy of the GNU General Public License
\ along with stage0.  If not, see <http://www.gnu.org/licenses/>.

\ Simply cat this file to the top of any forth program that leverages its functionality
\ then execute the resulting out put as so:
\ ./bin/vm --rom roms/forth --memory 1M --tape_01 The_combined_file
\ All writes via WRITE8 will be written to tape_02 or whatever name you prefer via the --tape_02 option
\ However should you wish to leverage readline for interacting with forth use vm-production but be warned
\ WILL see duplicate lines being printed when you hit enter as both readline and the forth are echoing your key strokes

\ Define our CELL size as 4 bytes
: CELL 4 ;

\ Save us from manually calculating how many bytes is a given number of CELLS
: CELLS CELL * ;

\ Setup an easy to reference FLAGS offset Constant
: >FLAGS 2 CELLS + ;

\ Update the flags of the latest defintion to IMMEDIATE
: IMMEDIATE LATEST >FLAGS DUP @ 0x2 OR SWAP ! ;

\ Define ALLOT to allocate a give number of bytes
: ALLOT HERE + DP! ;

\ Read a word, lookup and return pointer to its definition.
: '  WORD DROP FIND >CFA ;

\ Lookup a word and write the address of its definition
: [COMPILE] ' , ; IMMEDIATE

\ The literal code address of LIT. Don't think too hard about it.
: LITERAL [ ' LIT DUP , , ] , , ;

\ Compile the CFA of a word looked up as a literal
: ['] ' LITERAL ; IMMEDIATE

\ CONTROL STRUCTURES

\ Compile a conditional forward branch, to be resolved by THEN or ELSE.
: IF ['] 0BRANCH , HERE 0 , ; IMMEDIATE

\ Get displacement between two address and write the difference to the address first given
: TARGET! OVER - SWAP ! ;

\ equivalent to "ENDIF".
: THEN HERE TARGET! ; IMMEDIATE

\ And our ELSE for our IF
: ELSE HERE 2 CELLS + TARGET! ['] BRANCH , HERE 0 , ; IMMEDIATE

\ A backwards branch destination, to be resolved by AGAIN, UNTIL, or REPEAT.
: BEGIN HERE ; IMMEDIATE

\ This forward conditional branch will be resolved by REPEAT.
: WHILE [COMPILE] IF SWAP ; IMMEDIATE

\ Resolve a backwards branch.
: AGAIN ['] BRANCH , HERE SWAP TARGET! CELL ALLOT ; IMMEDIATE

: UNTIL ['] 0BRANCH , HERE SWAP TARGET! CELL ALLOT ; IMMEDIATE

\ Resolve the latest forward branch and compile a backwards branch.
: REPEAT [COMPILE] AGAIN [COMPILE] THEN ; IMMEDIATE

\ Note that it is possible to use multiple exits from a 
\ BEGIN ... WHILE ... REPEAT loop, as long as you resolve the forward branches
\ manually. For example, BEGIN ... WHILE ... WHILE ... REPEAT THEN will allow
\ an exit from either WHILE. You can even put other stuff between the REPEAT and
\ THEN if you need to handle certain exits specially. Use sparingly unless
\ you're sure you understand how it works.

: [CHAR]   KEY LITERAL ; IMMEDIATE

\ If true put t otherwise put f
: .BOOL IF [CHAR] t ELSE [CHAR] f THEN EMIT ;

\ Writes a Byte to HEAP
: C, HERE C! 1 ALLOT ;

\ addr count -- high low
: BOUNDS   OVER + SWAP ;

\ Prints Memory from address a to a + b when invoked as a b TYPE
: TYPE BOUNDS BEGIN 2DUP > WHILE DUP C@ EMIT 1 + REPEAT 2DROP ;

\ So we don't have to type 10 EMIT for newlines anymore
: CR 10 EMIT ;

\ Makes a string on the HEAP from everything between it and "
: STR" HERE BEGIN KEY DUP [CHAR] " != WHILE C, REPEAT DROP HERE OVER - ;

\ Extends STR" to work in Compile mode
: S" STATE IF ['] BRANCH , HERE 0 , STR" ROT HERE TARGET! SWAP LITERAL LITERAL
	   ELSE STR" THEN ; IMMEDIATE

\ Extends S" to behave the way most users want
: ." [COMPILE] S" STATE IF ['] TYPE , ELSE TYPE THEN ; IMMEDIATE

\ add the ANS keyword for modulus
: MOD % ;

\ add ANS keyword for getting both Quotent and Remainder
: /MOD 2DUP MOD >R / R> ;

\ valid bases are from 2 to 36.
CREATE BASE 10 ,

\ Primitive needed for printing base 10 numbers
: NEXT-DIGIT BASE @ /MOD ;

\ Give us a 400bytes of storage to play with
: PAD HERE 100 CELLS + ;

\ Assuming 2's complement
: NEGATE   NOT 1 + ;

\ Swap the contents of 2 Memory addresses
: CSWAP! 2DUP C@ SWAP C@ ROT C! SWAP C! ;

\ Given an address and a number of Chars, reverses a string (handy for little
\ endian systems that have bytes in the wrong order)
: REVERSE-STRING OVER + 1 -
		 BEGIN 2DUP < WHILE 2DUP CSWAP! 1 - SWAP 1 + SWAP REPEAT 2DROP ;

\ Given an address and number, writeout number at address and increment address
: +C! OVER C! 1 + ;


\ works for hex and stuff
: >ASCII-DIGIT   DUP 10 < IF 48 ELSE 55 THEN + ;

\ Given a number and address write out string form of number at address and
\ returns address and length (address should have at least 10 free bytes).
: NUM>STRING DUP >R OVER 0 < IF SWAP NEGATE SWAP [CHAR] - +C!
			     THEN DUP >R SWAP \ R: str-start digits-start
	     BEGIN NEXT-DIGIT ROT SWAP >ASCII-DIGIT +C! SWAP DUP WHILE REPEAT
	     DROP R> 2DUP - REVERSE-STRING R> SWAP OVER - ;

\ A user friendly way to print a number
: . PAD NUM>STRING TYPE ;

\ A temp constant that is going to be replaced
: STACK-BASE 0x00090000 ;

\ Given current stack pointer calculate and display number of underflowed cells
: .UNDERFLOW   ." Warning: stack is underflowed by "
	       STACK-BASE SWAP - CELL / . ."  cells!" CR ;

\ Display the number of entries on stack in <n> form
: .HEIGHT STACK-BASE - CELL / ." <" . ." > " ;

\ Display count and contents of stack or error message if Underflow
: .S DSP@ DUP STACK-BASE < IF .UNDERFLOW
			   ELSE DUP .HEIGHT STACK-BASE
				BEGIN 2DUP > WHILE DUP @ . 32 EMIT CELL + REPEAT
				2DROP
			   THEN ;

\ Pop off contents of stack to Zero stack
: CLEAR-STACK BEGIN DSP@ STACK-BASE > WHILE .S 10 EMIT DROP REPEAT STACK-BASE DSP! ;
: (   BEGIN KEY [CHAR] ) = UNTIL ; IMMEDIATE
\ Note: for further reading, see brad rodriguez's moving forth stuff.
\ The return address currently on the stack points to the next word to be
\ executed. DOER! should only be compiled by DOES> or other similar words, so
\ the address on the return stack should be right past DOER!'s. Which should be
\ the code to make the action for the latest word. Since we only want to set
\ this code as the latest word's action, not actually execute it at this point,
\ we don't bother putting anything back on the return stack - we'll return
\ straight up past the word we came from.

\ For example: consider this definition
\ : CONSTANT   CREATE , DOES> @ ;
\ This compiles to the sequence: DOCOL CREATE , DOER! @ EXIT
\ DOER! will point the latest word (the CREATEd one) to the code right past it -
\ the @ EXIT - and then exit the definition it's in.
: DOER!   R> SWAP >CFA ! ;
\ This is a tricky one. Basically, we need to compile a little bit of machine
\ code that will invoke the code that follows. Notes: R12 should, at this point,
\ have the address of the place we got here from. So we should just put
\ that+cell on the stack (for use by what follows DOES>) and run DOCOL. (Note:
\ implemented in forth.s)
\ Assumes most significant byte is at lower address
: 2C, DUP 0xFF00 AND 8 RSHIFT C, 0xFF AND C, ;

\ Compiles an assembly-level jump to a location.
\ We may have to compile more than just a jump in the future in order
\ for DOES> to work properly - we'd need to load the address into a register,
\ having the actual address nearby, and then use that coroutine jump thing.
\ CMPSKIP.E R0 R0, the address, LOADRU32 R0 -4, JSR_COROUTINE R0
: JUMP-TO, 0x09030200 , , 0x2E60FFFC , 0x0D010000 , ;

\ Sets the action of the latest word
: DOES>   ['] LATEST , ['] DOER! , 'DODOES JUMP-TO, ; IMMEDIATE
\ Sets the action of a certain word
: DOER>   ['] DOER! , 'DODOES JUMP-TO, ; IMMEDIATE
: TUCK   SWAP OVER ;

: MIN    2DUP < IF SWAP THEN DROP ;
: HEX    16 BASE ! ;
: DECIMAL   10 BASE ! ;

CREATE LINE-SIZE CELL ,
: PRINTABLE?   DUP 127 < SWAP 31 > AND ;
: EMIT-PRINTABLE   DUP PRINTABLE? IF EMIT ELSE DROP [CHAR] . EMIT THEN ;
: DUMP-TYPE    BOUNDS BEGIN 2DUP > WHILE DUP C@ EMIT-PRINTABLE 1 + REPEAT 2DROP ;
\ will always print two characters.
: .HEX-BYTE   DUP 16 / >ASCII-DIGIT EMIT 15 AND >ASCII-DIGIT EMIT ;
: DUMP-LINE   2DUP BOUNDS BEGIN 2DUP > WHILE DUP C@ .HEX-BYTE ."  " 1 + REPEAT
	      2DROP ."    " DUMP-TYPE CR ;
: DUMP-LINES  LINE-SIZE @ * BOUNDS
	      BEGIN 2DUP > WHILE DUP LINE-SIZE @ TUCK DUMP-LINE + REPEAT 2DROP ;
: DUMP   LINE-SIZE @ /MOD -ROT 2DUP DUMP-LINES LINE-SIZE @ * + SWAP DUMP-LINE ;

: VARIABLE   CREATE 0 , ;
: CONSTANT   CREATE , DOES> @ ;
: NOOP ;
: DEFER      CREATE ['] NOOP , DOES> @ EXECUTE ;
: IS         ' CELL + STATE IF LITERAL ['] ! , ELSE ! THEN ; IMMEDIATE


\ emits n spaces.
: SPACES   BEGIN DUP WHILE 32 EMIT 1 - REPEAT DROP ;
' NOOP @ CONSTANT 'DOCOL
\ Starts a definition without a name, leaving the execution token (the thing
\ that can be passed to EXECUTE) on the stack.
: :NONAME   HERE 'DOCOL , ] ;

\ fill n bytes with char.
\ addr n char --
: FILL   >R BOUNDS BEGIN 2DUP > WHILE DUP R@ C! 1 + REPEAT 2DROP R> DROP ;
: <> != ;
