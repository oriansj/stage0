;; add_node Function
;; Recieves pointers in R0 R1
;; Alters R0 if NULL
;; Appends nodes together
;; Returns to whatever called it
:add_node
	;; Preserve Registers
	PUSHR R2 R15
	PUSHR R1 R15
	PUSHR R0 R15

	;; Handle if Head is NULL
	JUMP.NZ R0 @add_node_0
	POPR R0 R15
	PUSHR R1 R15
	JUMP @add_node_2

:add_node_0
	;; Handle if Head->next is NULL
	LOAD32 R2 R0 0
	JUMP.NZ R2 @add_node_1
	;; Set head->next = p
	STORE32 R1 R0 0
	;; Set p->prev = head
	STORE32 R0 R1 4
	JUMP @add_node_2

:add_node_1
	;; Handle case of Head->next not being NULL
	LOAD32 R0 R0 0              ; Move to next node
	LOAD32 R2 R0 0              ; Get node->next
	CMPSKIP.E R2 0              ; If it is not null
	JUMP @add_node_1            ; Move to the next node and try again
	JUMP @add_node_0            ; Else simply act as if we got this node
	                            ; in the first place

:add_node_2
	;; Restore registers
	POPR R0 R15
	POPR R1 R15
	POPR R2 R15
	RET R15
