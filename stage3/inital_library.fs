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

\ Read a word, lookup and return pointer to its definition and don't use up HEAP space doing it
: ' HERE WORD DROP FIND >CFA SWAP DP! ;

\ Lookup a word and write the address of its definition
: [COMPILE] ' , ; IMMEDIATE

\ The literal code address of LIT. Don't think too hard about it.
: LITERAL [ ' LIT DUP , , ] , , ;

\ Lookup a word and append some literals
: ['] ' LITERAL ; IMMEDIATE

\ Define IF as if top of stack is false branch to Literal value not yet written
: IF [ ' 0BRANCH LITERAL ] , HERE 0 , ; IMMEDIATE

\ Get displacement between two address and write the difference to the address first given
: TARGET! OVER - SWAP ! ;

\ equivalent to "ENDIF".
: THEN HERE TARGET! ; IMMEDIATE

\ And our ELSE for our IF
: ELSE HERE 2 CELLS + TARGET! ['] BRANCH , HERE 0 , ; IMMEDIATE

\ Put here on the stack for the while to pickup and turn into an immediate jump
: BEGIN HERE ; IMMEDIATE

\ Use stack value from begin to loop if still true
: WHILE [COMPILE] IF ; IMMEDIATE

\ Who doesn't love repeat?
: REPEAT HERE 2 CELLS + TARGET! ['] BRANCH , HERE SWAP TARGET! CELL ALLOT ; IMMEDIATE

\ Writes our repetition target
: AGAIN HERE SWAP TARGET! ; IMMEDIATE

\ If true put t otherwise put f
: .BOOL IF 116 EMIT ELSE 102 EMIT THEN ;

\ Writes a Byte to HEAP
: C, HERE C! 1 ALLOT ;

\ Prints Memory from address a to a + b when invoked as a b TYPE
: TYPE OVER + SWAP BEGIN 2DUP > WHILE DUP C@ EMIT 1 + REPEAT 2DROP ;

\ So we don't have to type 10 EMIT for newlines anymore
: CR 10 EMIT ;

\ Makes a string on the HEAP from everything between it and "
: STR" HERE BEGIN KEY DUP 34 != WHILE C, REPEAT DROP HERE OVER - ;

\ Extends STR" to work in Compile mode
: S" STATE IF ['] BRANCH , HERE 0 , STR" ROT HERE TARGET! SWAP LITERAL LITERAL ELSE STR" THEN ; IMMEDIATE

\ Extends S" to behave the way most users want "
: ." [COMPILE] S" STATE IF ['] TYPE , ELSE TYPE THEN ; IMMEDIATE

\ add the ANS keyword for modulus
: MOD % ;

\ add ANS keyword for getting both Quotent and Remainder
: /MOD 2DUP MOD >R / R> ;

\ Primitive needed for printing base 10 numbers
: NEXT-DIGIT 10 /MOD ;

\ Give us a 400bytes of storage to play with
: PAD HERE 100 CELLS + ;

\ Assuming 2's complement
: NEGATE   NOT 1 + ;

\ Swap the contents of 2 Memory addresses
: CSWAP! 2DUP C@ SWAP C@ ROT C! SWAP C! ;

\ Given an address and a number of Chars, reverses a string (handy for little endian systems that have bytes in the wrong order)
: REVERSE-STRING OVER + 1 - BEGIN 2DUP < WHILE 2DUP CSWAP! 1 - SWAP 1 + SWAP REPEAT 2DROP ;

\ Given an address and number, writeout number at address and increment address
: +C! OVER C! 1 + ;

\ Given a number and address write out string form of number at address and returns address and length (address should have at least 10 free bytes).
: NUM>STRING DUP >R OVER 0 < IF SWAP NEGATE SWAP 45 +C! THEN DUP >R SWAP BEGIN NEXT-DIGIT ROT SWAP 48 + +C! SWAP DUP WHILE REPEAT DROP R> 2DUP - REVERSE-STRING R> SWAP OVER - ;

\ A user friendly way to print a number
: . PAD NUM>STRING TYPE ;

\ A temp constant that is going to be replaced
: STACK-BASE 0x00090000 ;

\ Given current stack pointer calculate and display number of underflowed cells
: .UNDERFLOW   ." Warning: stack is underflowed by " STACK-BASE SWAP - CELL / . ."  cells!" CR ;

\ Display the number of entries on stack in <n> form
: .HEIGHT STACK-BASE - CELL / ." <" . ." > " ;

\ Display count and contents of stack or error message if Underflow
: .S DSP@ DUP STACK-BASE < IF .UNDERFLOW ELSE DUP .HEIGHT STACK-BASE BEGIN 2DUP > WHILE DUP @ . 32 EMIT CELL + REPEAT 2DROP THEN ;

\ Pop off contents of stack to Zero stack
: CLEAR-STACK BEGIN DSP@ STACK-BASE > WHILE .S 10 EMIT DROP REPEAT STACK-BASE DSP! ;
