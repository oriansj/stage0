:start
	LOADUI R15 $stack           ; Put stack at end of program
	;; We will be using R14 for our condition codes
	;; We will be using R13 for storage of Head


;; Main program
;; Reads contents of Tape_01 and writes desired contents onto Tape_02
;; Accepts no arguments and HALTS when done
:main
	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ

	;; Prepare to Read File
	FALSE R14
	FALSE R1
	CALLI R15 @ReadFile

	;; Done reading File
	LOADUI R0 0x1100            ; Close TAPE_01
	FCLOSE

	;; Enter Editor Loop
	MOVE R13 R1                 ; Set R13 to Head
	CALLI R15 @EditorLoop

	;; And We are Done
	HALT


;; Readfile function
;; Recieves pointer to head in R1
;; Creates Nodes and imports text until EOF
;; Alters R0 R1 R14
;; Returns to whatever called it
:ReadFile
	;; Allocate another Node
	LOADUI R0 12
	CALLI R15 @malloc
	;; Get another line into list
	PUSHR R1 R15
	LOADUI R1 0x1100            ; Read from tape_01
	CALLI R15 @Readline
	POPR R1 R15
	SWAP R0 R1
	CALLI R15 @addline
	SWAP R0 R1
	;; Loop if not reached EOF
	JUMP.Z R14 @ReadFile
	RET R15


;; Readline function
;; Recieves Pointer to node in R0
;; And Input in R1
;; Allocates Text segment on Heap
;; Sets node's pointer to Text segment
;; Sets R14 to True if EOF reached
;; Returns to whatever called it
:Readline
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	PUSHR R3 R15
	PUSHR R4 R15
	;; Initialize
	MOVE R4 R0
	FALSE R0                    ; Get where space is free
	CALLI R15 @malloc
	MOVE R2 R0
	FALSE R3
:Readline_0
	FGETC                       ; Read a Char

	;; Flag if reached EOF
	CMPSKIP.GE R0 0
	TRUE R14

	;; Stop if EOF
	CMPSKIP.GE R0 0
	JUMP @Readline_2

	;; Handle Backspace
	CMPSKIP.E R0 127
	JUMP @Readline_1

	;; Move back 1 character if R3 > 0
	CMPSKIP.LE R3 0
	SUBUI R3 R3 1

	;; Hopefully they keep typing
	JUMP @Readline_0

:Readline_1
	;; Replace all CR with LF
	CMPSKIP.NE R0 13
	LOADUI R0 10

	;; Store the Byte
	STOREX8 R0 R2 R3

	;; Prep for next loop
	ADDUI R3 R3 1

	;; Check for EOL
	CMPSKIP.NE R0 10
	JUMP @Readline_2

	;; Otherwise loop
	JUMP @Readline_0

:Readline_2
	;; Set Text pointer
	CMPSKIP.E R3 0              ; Don't bother for Empty strings
	STORE32 R2 R4 8
	;; Correct Malloc
	MOVE R0 R3                  ; Ensure actually allocates exactly
	CALLI R15 @malloc           ; the amount of space required
	;; Restore Registers
	POPR R4 R15
	POPR R3 R15
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	RET R15


;; addline Function
;; Recieves pointers in R0 R1
;; Alters R0 if NULL
;; Appends nodes together
;; Returns to whatever called it
:addline
	;; Preserve Registers
	PUSHR R2 R15
	PUSHR R1 R15
	PUSHR R0 R15

	;; Handle if Head is NULL
	JUMP.NZ R0 @addline_0
	POPR R0 R15
	PUSHR R1 R15
	JUMP @addline_2

:addline_0
	;; Handle if Head->next is NULL
	LOAD32 R2 R0 0
	JUMP.NZ R2 @addline_1
	;; Set head->next = p
	STORE32 R1 R0 0
	;; Set p->prev = head
	STORE32 R0 R1 4
	JUMP @addline_2

:addline_1
	;; Handle case of Head->next not being NULL
	LOAD32 R0 R0 0              ; Move to next node
	LOAD32 R2 R0 0              ; Get node->next
	CMPSKIP.E R2 0              ; If it is not null
	JUMP @addline_1             ; Move to the next node and try again
	JUMP @addline_0             ; Else simply act as if we got this node
	                            ; in the first place

:addline_2
	;; Restore registers
	POPR R0 R15
	POPR R1 R15
	POPR R2 R15
	RET R15


;; Primative malloc function
;; Recieves number of bytes to allocate in R0
;; Returns pointer to block of that size in R0
;; Returns to whatever called it
:malloc
	;; Preserve registers
	PUSHR R1 R15
	;; Get current malloc pointer
	LOADR R1 @malloc_pointer
	;; Deal with special case
	CMPSKIP.NE R1 0             ; If Zero set to our start of heap space
	LOADUI R1 0x4000

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


;; Editor Loop
;; Provides user interaction
;; Requires R13 to be pointer to Head
;; Internally loops
;; Returns nothing
:EditorLoop
	FALSE R1                    ; Read from tty
	FGETC                       ; Read a Char

	;; Quit if q
	CMPSKIP.NE R0 113
	RET R15

	;; Print if p
	CMPUI R14 R0 112
	JUMP.NE R14 @EditorLoop_0
	LOAD32 R0 R13 8
	FALSE R1
	CALLI R15 @PrintLine
	JUMP @EditorLoop

:EditorLoop_0
	;; Move forward if f
	CMPUI R14 R0 102
	JUMP.NE R14 @EditorLoop_1
	LOAD32 R0 R13 0             ; Load head->next

	;; If head->next isn't null make it the new head
	CMPSKIP.E R0 0
	MOVE R13 R0
	JUMP @EditorLoop

:EditorLoop_1
	;; Move backward if b
	CMPUI R14 R0 98
	JUMP.NE R14 @EditorLoop_2
	LOAD32 R0 R13 4             ; Load head->prev

	;; If head->prev isn't null make it the new head
	CMPSKIP.E R0 0
	MOVE R13 R0
	JUMP @EditorLoop

:EditorLoop_2
	;; Edit Line if e
	CMPUI R14 R0 101
	JUMP.NE R14 @EditorLoop_3

	;; Change Head's Text
	COPY R0 R13
	FALSE R1                    ; Read from tty
	CALLI R15 @Readline

	JUMP @EditorLoop

:EditorLoop_3
	;; Writeout to tape_02 if w
	CMPUI R14 R0 119
	JUMP.NE R14 @EditorLoop_4

	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE

	COPY R0 R13
	LOADUI R1 0x1101
	CALLI R15 @GetRoot
	CALLI R15 @PrintAll

	LOADUI R0 0x1101            ; Close TAPE_02
	FCLOSE
	JUMP @EditorLoop

:EditorLoop_4
	;; Append node if a
	CMPUI R14 R0 97
	JUMP.NE R14 @EditorLoop_5
	COPY R0 R13
	CALLI R15 @AppendLine
	JUMP @EditorLoop

:EditorLoop_5
	;; Insert node if i
	CMPUI R14 R0 105
	JUMP.NE R14 @EditorLoop_6
	COPY R0 R13
	CALLI R15 @InsertLine
	JUMP @EditorLoop

:EditorLoop_6
	;; Delete node if d
	CMPUI R14 R0 100
	JUMP.NE R14 @EditorLoop_7
	COPY R0 R13
	CALLI R15 @RemoveLine
	MOVE R13 R0
	JUMP @EditorLoop

:EditorLoop_7
	JUMP @EditorLoop


;; GetRoot function
;; Walks backwards through nodes until beginning
;; Recieves node pointer in R0 and Returns result in R0
;; Returns to whatever called it
:GetRoot
	;; Preserve registers
	PUSHR R1 R15
:GetRoot_0
	;; Get Head->Prev
	LOAD32 R1 R0 4

	CMPSKIP.NE R1 0
	JUMP @GetRoot_1

	MOVE R0 R1
	JUMP @GetRoot_0

:GetRoot_1
	;; Restore registers
	POPR R1 R15
	RET R15


;; Printall Function
;; Prints all lines to Interface in R1
;; Starting at node in R0
;; Does not alter registers
;; Returns to whatever called it
:PrintAll
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
:PrintAll_0
	LOAD32 R2 R0 0              ; Store Head->Next in R2
	LOAD32 R0 R0 8              ; Set R0 to Head->Text
	CALLI R15 @PrintLine        ; Prints Head->Text
	CMPSKIP.NE R2 0             ; If Head->Next is NULL
	JUMP @PrintAll_1            ; Stop Looping
	MOVE R0 R2                  ; Otherwise Move to Next Node
	JUMP @PrintAll_0            ; And Loop
:PrintAll_1
	;; Restore registers
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	RET R15


;; Printline function
;; Recieves a string pointer in R0
;; Prints string interface specified in R1
;; Does not alter registers
;; Returns to whatever called it
:PrintLine
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	PUSHR R3 R15
	;; Initialize
	MOVE R2 R0
	FALSE R3
	;; Deal with NULL Pointer
	CMPSKIP.NE R2 0
	JUMP @PrintLine_1
:PrintLine_0
	LOADXU8 R0 R2 R3            ; Load char from string
	;; Don't print NULLs
	CMPSKIP.NE R0 0
	JUMP @PrintLine_1

	FPUTC                       ; Print the char
	ADDUI R3 R3 1               ; Prep for next loop
	JUMP @PrintLine_0

:PrintLine_1
	;; Restore registers
	POPR R3 R15
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	RET R15


;; AppendLine Function
;; Recieves a Node in R0
;; Creates a new Node and appends it
;; Does not alter registers
;; Returns to whatever calls it
:AppendLine
	;; Preserve registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	;; Initialize
	MOVE R1 R0
	;; Allocate another Node
	LOADUI R0 12
	CALLI R15 @malloc

	;; Check if head->Next is null
	LOAD32 R2 R1 0
	CMPSKIP.E R2 0              ; If head->Next is something
	STORE32 R0 R2 4             ; Set head->next->prev to p

	;; Setup p and head
	STORE32 R2 R0 0             ; p->next = head->next
	STORE32 R1 R0 4             ; p->prev = head
	STORE32 R0 R1 0             ; head->next = p

	;; Restore Registers
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	RET R15


;; InsertLine Function
;; Recieves a Node in R0
;; Creates a new Node and prepends it
;; Does not alter registers
;; Returns to whatever called it
:InsertLine
	;; Preserve Registers
	PUSHR R0 R15
	PUSHR R1 R15
	PUSHR R2 R15
	;; Initialize
	MOVE R1 R0
	;; Allocate another Node
	LOADUI R0 12
	CALLI R15 @malloc

	;; Check if Head->Prev is Null
	LOAD32 R2 R1 4
	CMPSKIP.E R2 0              ; If head->prev is something
	STORE32 R0 R2 0             ; Set head->prev->next to p

	;; Setup p and head
	STORE32 R2 R0 4             ; p->prev = head->prev
	STORE32 R1 R0 0             ; p->next = head
	STORE32 R0 R1 4             ; head->prev = p

	;; Restore Registers
	POPR R2 R15
	POPR R1 R15
	POPR R0 R15
	RET R15


;; RemoveLine Function
;; Recieves Node in R0
;; Returns replacement node in R0
;; Returns to whatever called it
:RemoveLine
	;; Preserve Registers
	PUSHR R1 R15
	PUSHR R2 R15
	;; Initialize
	MOVE R1 R0
	LOAD32 R0 R1 4              ; put p->prev in R0
	LOAD32 R2 R1 0              ; put p->next in R2

	;; Keep links
	CMPSKIP.E R0 0              ; If p->prev is not null
	STORE32 R2 R0 0             ; p->prev->next = p->next

	CMPSKIP.E R2 0              ; If p->next is not null
	STORE32 R0 R2 4             ; p->next->prev = p->prev

	;; Attempt to save what is left of the list
	CMPSKIP.NE R0 0             ; If p->prev is null
	MOVE R0 R2                  ; return p->next

	;; Restore Registers
	POPR R2 R15
	POPR R1 R15
	RET R15


;; Where our stack begins
:stack
