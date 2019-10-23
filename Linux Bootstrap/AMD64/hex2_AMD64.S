;; Copyright (C) 2017 Jeremiah Orians
;; This file is part of stage0.
;;
;; stage0 is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; stage0 is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with stage0.  If not, see <http://www.gnu.org/licenses/>.

	section .text
	global _start

	;; Register usage:
	;; RAX, RDX, RSI, RDI => Temps
	;; R15 => Flag
	;; R14 => High bits
	;; R13 => IP
	;; R12 => MALLOC
	;; R11 => HEAD

	;; Struct format: (size 24)
	;; NEXT => 0
	;; TARGET => 8
	;; NAME => 16

; Where the ELF Header is going to hit
; Simply jump to _start
; Our main function
_start:
	mov rdi, 0                  ; Get current pointer
	call malloc                 ; Get current HEAP
	mov rdi, rax                ; Using current
	mov r12, rax                ; Setup MALLOC
	add rdi, 81920              ; Create space for temp
	call malloc                 ; Give ourselves 81920 bytes to work with

	pop rax                     ;·Get·the·number·of·arguments
	pop rdi                     ;·Get·the·program·name
	pop rdi                     ;·Get·the·actual·input name
	mov rsi, 0                  ;·prepare·read_only
	mov rax, 2                  ;·the·syscall·number·for·open()
	syscall                     ; Now open that damn file
	mov r9, rax                 ; Preserve the file pointer we were given

	pop rdi                     ;·Get·the·actual·output name
	mov rsi, 577                ; Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov rdx, 448                ; Prepare file as RWX for owner only (700 in octal)
	mov rax, 2                  ;·the·syscall·number·for·open()
	syscall                     ; Now open that damn file
	cmp rax, 0                  ; Check for missing output
	jg _start_out               ; Have real input
	mov rax, 1                  ; Use stdout

_start_out:
	mov r10, rax                ; Preserve the file pointer we were given

	call ClearScratch           ; Zero scratch
	mov r15, -1                 ; Our flag for byte processing
	mov r14, 0                  ; temp storage for the sum
	mov r13, 0x00600000         ; Our starting IP
	mov r11, 0                  ; HEAD = NULL
	call First_pass             ; Process it

	; rewind input file
	mov rdi, r9                 ; Using our input file
	mov rsi, 0                  ; Offset Zero
	mov rdx, 0                  ; Whence Zero
	mov rax, 8                  ; lseek
	push r11                    ; Protect HEAD
	syscall
	pop r11                     ; Restore HEAD

	mov r15, -1                 ; Our flag for byte processing
	mov r14, 0                  ; temp storage for the sum
	mov r13, 0x00600000         ; Our starting IP
	call Second_pass            ; Process it

	jmp Done

First_pass:
	call Read_byte

	; Deal with EOF
	cmp rax, -4
	je First_pass_done

	; Check for :
	cmp rax, 0x3a
	jne First_pass_0

	; Deal with label
	jmp StoreLabel

First_pass_0:
	; Check for !
	cmp rax, 0x21
	je First_pass_pointer

	; Check for @
	cmp rax, 0x40
	je First_pass_pointer

	; Check for $
	cmp rax, 0x24
	je First_pass_pointer

	; Check for %
	cmp rax, 0x25
	je First_pass_pointer

	; Check for &
	cmp rax, 0x26
	je First_pass_pointer

	; Deal with everything else
	call hex                    ; Process our char

	; Deal with EOF
	cmp rax, -4
	je First_pass_done

	; deal with -1 values
	cmp rax, 0
	jl First_pass

	; deal with toggle
	cmp r15, 0
	je First_pass_1
	add r13, 1                  ; Increment IP

First_pass_1:
	not r15
	jmp First_pass

Update_Pointer:
	; Check for !
	cmp rax, 0x21
	je Update_Pointer_1

	; Check for @
	cmp rax, 0x40
	je Update_Pointer_2

	; Check for $
	cmp rax, 0x24
	je Update_Pointer_2

	; Check for %
	cmp rax, 0x25
	je Update_Pointer_4

	; Check for &
	cmp rax, 0x26
	je Update_Pointer_4

	;; deal with bad input
	call fail

Update_Pointer_4:
	add r13, 2                  ; Increment IP
Update_Pointer_2:
	add r13, 1                  ; Increment IP
Update_Pointer_1:
	add r13, 1                  ; Increment IP
	ret

First_pass_pointer:
	; Deal with Pointer to label
	call Update_Pointer         ; Increment IP
	mov rbx, table              ; Using scratch
	call consume_token          ; Read token
	call ClearScratch           ; Throw away token
	cmp rax, 0x3E               ; check for '>'
	jne First_pass              ; Loop again

	;; Deal with %label>label case
	mov rbx, table              ; Write to scratch
	call consume_token          ; get token
	call ClearScratch           ; Clean up after ourselves
	jmp First_pass              ; Loop again

First_pass_done:
	RET

hex:
	; deal with EOF
	cmp rax, -4
	je EOF
	; deal with line comments starting with ;
	cmp rax, 0x23
	je ascii_comment
	; deal with line comments starting with ;
	cmp rax, 0x3b
	je ascii_comment
	; deal all ascii less than 0
	cmp rax, 0x30
	jl ascii_other
	; deal with 0-9
	cmp rax, 0x3a
	jl ascii_num
	; deal with all ascii less than A
	cmp rax, 0x41
	jl ascii_other
	; deal with A-F
	cmp rax, 0x47
	jl ascii_high
	;deal with all ascii less than a
	cmp rax, 0x61
	jl ascii_other
	;deal with a-f
	cmp rax, 0x67
	jl ascii_low
	; The rest that remains needs to be ignored
	jmp ascii_other

Second_pass:
	call Read_byte

	; Deal with EOF
	cmp rax, -4
	je Second_pass_done

	; Simply drop the label
	cmp rax, 0x3a
	jne Second_pass_0

	mov rbx, table              ; Using scratch
	call consume_token          ; Read token
	call ClearScratch           ; Throw away token

	jmp Second_pass

Second_pass_0:
	; Deal with % pointer
	cmp rax, 0x25
	je StorePointer_rel4

	; Deal with @ pointer
	cmp rax, 0x40
	je StorePointer_rel2

	; Deal with ! pointer
	cmp rax, 0x21
	je StorePointer_rel1

	; Deal with & pointer
	cmp rax, 0x26
	je StorePointer_abs4

	; Deal with $ pointer
	cmp rax, 0x24
	je StorePointer_abs2

Second_pass_1:
	; Deal with everything else
	call hex                    ; Process our char

	; Deal with EOF
	cmp rax, -4
	je Second_pass_done

	; deal with -1 values
	cmp rax, 0
	jl Second_pass

	; deal with toggle
	cmp r15, 0
	je print

	; process first byte of pair
	mov r14, rax
	mov r15, 0
	jmp Second_pass

Second_pass_done:
	ret

EOF:
	ret
ascii_num:
	sub rax, 0x30
	ret
ascii_low:
	sub rax, 0x57
	ret
ascii_high:
	sub rax, 0x37
	ret
ascii_other:
	mov rax, -1
	ret
ascii_comment:
	call Read_byte
	cmp rax, 0xd
	je ascii_comment_cr
	cmp rax, 0xa
	jne ascii_comment
ascii_comment_cr:
	mov rax, -1
	ret

; process second byte of pair
print:
	; update the sum and store in output
	shl r14, 4
	add rax, r14
	mov [table], al

	; flip the toggle
	not r15

	; Print our first Hex
	mov rdx,  1                 ; set the size of chars we want
	call print_chars

	add r13, 1                  ; Increment IP
	jmp Second_pass

Done:
	; program completed Successfully
	mov rdi, 0                  ; All is well
	mov rax, 0x3c               ; put the exit syscall number in eax
	syscall                     ; Call it a good day


;; Malloc isn't actually required if the program being built fits in the initial memory
;; However, it doesn't take much to add it.
;; Requires a value in RDI
malloc:
	mov rax, 12                 ; the Syscall # for SYS_BRK
	push r11                    ; Protect r11
	syscall                     ; call the Kernel
	pop r11                     ; Restore r11
	ret


Read_byte:
	; Attempt to read 1 byte from STDIN
	mov rdx,  1                 ; set the size of chars we want
	mov rsi, write              ; Where to put it
	mov rdi, r9                 ; Where are we reading from
	mov rax, 0                  ; the syscall number for read
	push r11                    ; Protect r11
	syscall                     ; call the Kernel
	pop r11                     ; Restore r11

	test rax, rax               ; check what we got
	je Read_byte_1              ; Got EOF call it done

	; load byte
	mov al, [write]             ; load char
	movzx rax, al               ; We have to zero extend it to use it
	ret

; Deal with EOF
Read_byte_1:
	mov rax, -4                 ; Put EOF in rax
	ret

print_chars:
	mov rsi, table              ; What we are writing
	mov rdi, r10                ; Write to target file
	mov rax, 1                  ; the syscall number for write
	push r11                    ; Protect HEAD
	syscall                     ; call the Kernel
	pop r11                     ; Restore HEAD
	ret

	;; Receives pointer in RBX
	;; Writes out char and updates RBX
consume_token:
	call Read_byte              ; Consume_token

	; Check for \t
	cmp rax, 0x09
	je consume_token_done

	; Check for \n
	cmp rax, 0x0A
	je consume_token_done

	; Check for ' '
	cmp rax, 0x20
	je consume_token_done

	; Check for '>'
	cmp rax, 0x3E
	je consume_token_done

	;; Looks like we are still reading token
	mov [rbx], al               ; Store char
	add rbx, 1                  ; Point to next spot
	jmp consume_token           ; loop until done

consume_token_done:
	mov rcx, 0                  ; Padd with nulls
	mov [rbx], rcx
	add rbx, 8
	ret

StoreLabel:
	mov rax, r12                ; ENTRY
	add r12, 24                 ; CALLOC
	mov [rax+8], r13            ; ENTRY->TARGET = IP
	mov [rax], r11              ; ENTRY->NEXT = JUMP_TABLE
	mov r11, rax                ; JUMP_TABLE = ENTRY
	mov [r11+16], r12           ; ENTRY->NAME = TOKEN
	mov rbx, r12                ; Write Starting after struct
	call consume_token          ; Collect whole string
	mov r12, rbx                ; Update HEAP
	jmp First_pass

GetTarget:
	mov rdi, table              ; Reset scratch
	mov rcx, r11                ; Grab JUMP_TABLE
	mov rsi, [rcx+16]           ; I->NAME
GetTarget_loop:
	mov al, [rsi]               ; I->NAME[0]
	mov bl, [rdi]               ; scratch[0]
	movzx rbx, bl               ; Zero extend
	movzx rax, al               ; Zero extend
	cmp al, bl                  ; IF TOKEN == I->NAME
	jne GetTarget_miss          ; Oops

	add rsi, 1
	add rdi, 1
	cmp al, 0
	jne GetTarget_loop          ; Loop until
	jmp GetTarget_done          ; Match

	;; Miss
GetTarget_miss:
	mov rcx, [rcx]              ; I = I->NEXT
	cmp rcx, 0                  ; IF NULL == I
	je fail                     ; Abort hard

	mov rsi, [rcx+16]           ; I->NAME
	mov rdi, table              ; Reset scratch
	jmp GetTarget_loop

GetTarget_done:
	mov rax, [rcx+8]            ; Get address
	ret

ClearScratch:
	push rax                    ; Protect against changes
	push rbx                    ; And overwrites
	push rcx                    ; While we work
	mov rbx, table              ; Where our table is
	mov al, 0                   ; Using null

ClearScratch_loop:
	mov rcx, [rbx]               ; Get current value
	mov [rbx], al               ; Because we want null
	add rbx, 1                  ; Increment
	cmp rcx, 0                   ; Check if we hit null
	jne ClearScratch_loop       ; Keep looping

	pop rcx
	pop rbx                     ; Restore Damage
	pop rax                     ; Entirely
	ret

StorePointer:
	call Update_Pointer         ; Increment IP
	mov rbx, table              ; Write to scratch
	call consume_token          ; get token
	push rax                    ; Protect base_sep_p
	mov rax, table              ; Pointer to scratch
	call GetTarget              ; Get address of pointer
	call ClearScratch           ; Clean up after ourselves
	mov rdx, r13                ; base = IP
	pop rbx                     ; Restore base_sep_p
	cmp rbx, 0x3E               ; If base_sep_p == '>'
	jne StorePointer_done       ; If not

	;; Deal with %label>label case
	push rax                    ; We need to preserve main target
	mov rbx, table              ; Write to scratch
	call consume_token          ; get token
	mov rax, table              ; Pointer to scratch
	call GetTarget              ; Get address of pointer
	call ClearScratch           ; Clean up after ourselves
	mov rdx, rax                ; Use our new base
	pop rax                     ; Restore main target

StorePointer_done:
	ret

StorePointer_rel4:
	call StorePointer           ; Do Common
	sub rax, rdx                ; target - ip
	mov [table], rax            ; put value in output
	mov rdx,  4                 ; set the size of chars we want
	call print_chars
	call ClearScratch           ; Clean up after ourselves
	jmp Second_pass

StorePointer_rel2:
	call StorePointer           ; Do Common
	sub rax, rdx                ; target - ip
	mov [table], rax            ; put value in output
	mov rdx, 2                  ; set the size of chars we want
	call print_chars
	call ClearScratch           ; Clean up after ourselves
	jmp Second_pass

StorePointer_rel1:
	call StorePointer           ; Do Common
	sub rax, rdx                ; target - ip
	mov [table], rax            ; put value in output
	mov rdx, 1                  ; set the size of chars we want
	call print_chars
	call ClearScratch           ; Clean up after ourselves
	jmp Second_pass

StorePointer_abs4:
	call StorePointer           ; Do Common
	mov [table], rax            ; put value in output
	mov rdx, 4                  ; set the size of chars we want
	call print_chars
	call ClearScratch           ; Clean up after ourselves
	jmp Second_pass

StorePointer_abs2:
	call StorePointer           ; Do Common
	mov [table], rax            ; put value in output
	mov rdx, 2                  ; set the size of chars we want
	call print_chars
	call ClearScratch           ; Clean up after ourselves
	jmp Second_pass

fail:
	; Some shit went wrong
	mov rdi, 1                  ; All is wrong
	mov rax, 0x3c               ; put the exit syscall number in eax
	syscall                     ; Call it a good day


section .data
ELF_end:
write:
	dq 0
table:
	dq 66
