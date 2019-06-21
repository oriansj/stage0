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
	;; EAX, EDX, ECX, EBX => Temps
	;; EDI => IP
	;; EBP => MALLOC
	;; ESI => HEAD

	;; Struct format: (size 24)
	;; NEXT => 0
	;; TARGET => 8
	;; NAME => 16

; Where the ELF Header is going to hit
; Simply jump to _start
; Our main function
_start:
	mov ebx, 0                  ; Get current pointer
	call malloc                 ; Get current HEAP
	mov ebx, eax                ; Using current
	mov ebp, eax                ; Setup MALLOC
	add ebx, 8192000            ; Create space for temp
	call malloc                 ; Give ourselves 8192000 bytes to work with

	pop eax                     ;·Get·the·number·of·arguments
	pop ebx                     ;·Get·the·program·name
	pop ebx                     ;·Get·the·actual·input name
	mov ecx, 0                  ;·prepare·read_only
	mov edx, 0                  ; Really sure
	mov eax, 5                  ;·the·syscall·number·for·open()
	int 0x80                    ; Now open that damn file
	mov [Input], eax            ; Preserve the file pointer we were given

	pop ebx                     ;·Get·the·actual·output name
	mov ecx, 577                ; Prepare file as O_WRONLY|O_CREAT|O_TRUNC
	mov edx, 384                ; Prepare file as RW for owner only (600 in octal)
	mov eax, 5                  ;·the·syscall·number·for·open()
	int 0x80                    ; Now open that damn file
	cmp eax, 0                  ; Check for missing output
	jg _start_out               ; Have real input
	mov eax, 1                  ; Use stdout

_start_out:
	mov [Output], eax           ; Preserve the file pointer we were given


	call ClearScratch           ; Zero scratch
	mov eax, -1                 ; Our flag for byte processing
	mov [Flag], eax             ; Set
	mov eax, 0                  ; temp storage for the sum
	mov [High], eax             ; Set
	mov edi, 0x8048000          ; Our starting IP
	mov esi, 0                  ; HEAD = NULL
	call First_pass             ; Process it

	; rewind input file
	mov ebx, [Input]            ; Using our input file
	mov ecx, 0                  ; Offset Zero
	mov edx, 0                  ; Whence Zero
	mov eax, 19                 ; lseek
	push esi                    ; Protect HEAD
	int 0x80
	pop esi                     ; Restore HEAD

	mov eax, -1                 ; Our flag for byte processing
	mov [Flag], eax             ; Set
	mov eax, 0                  ; temp storage for the sum
	mov [High], eax             ; Set
	mov edi, 0x8048000          ; Our starting IP
	call Second_pass            ; Process it

	jmp Done

First_pass:
	call Read_byte

	; Deal with EOF
	cmp eax, -4
	je First_pass_done

	; Check for :
	cmp eax, 0x3a
	jne First_pass_0

	; Deal with label
	jmp StoreLabel

First_pass_0:
	; Check for !
	cmp eax, 0x21
	je First_pass_pointer

	; Check for @
	cmp eax, 0x40
	je First_pass_pointer

	; Check for $
	cmp eax, 0x24
	je First_pass_pointer

	; Check for %
	cmp eax, 0x25
	je First_pass_pointer

	; Check for &
	cmp eax, 0x26
	je First_pass_pointer

	; Deal with everything else
	call hex                    ; Process our char

	; Deal with EOF
	cmp eax, -4
	je First_pass_done

	; deal with -1 values
	cmp eax, 0
	jl First_pass

	; deal with toggle
	mov eax, [Flag]
	cmp eax, 0
	je First_pass_1
	add edi, 1                  ; Increment IP

First_pass_1:
	not eax
	mov [Flag], eax
	jmp First_pass

Update_Pointer:
	; Check for !
	cmp eax, 0x21
	je Update_Pointer_1

	; Check for @
	cmp eax, 0x40
	je Update_Pointer_2

	; Check for $
	cmp eax, 0x24
	je Update_Pointer_2

	; Check for %
	cmp eax, 0x25
	je Update_Pointer_4

	; Check for &
	cmp eax, 0x26
	je Update_Pointer_4

	;; deal with bad input
	call fail

Update_Pointer_4:
	add edi, 2                  ; Increment IP
Update_Pointer_2:
	add edi, 1                  ; Increment IP
Update_Pointer_1:
	add edi, 1                  ; Increment IP
	ret

First_pass_pointer:
	; Deal with Pointer to label
	call Update_Pointer         ; Increment IP
	mov ebx, table              ; Using scratch
	call consume_token          ; Read token
	call ClearScratch           ; Throw away token
	cmp eax, 0x3E               ; check for '>'
	jne First_pass              ; Loop again

	;; Deal with %label>label case
	mov ebx, table              ; Write to scratch
	call consume_token          ; get token
	call ClearScratch           ; Clean up after ourselves
	jmp First_pass              ; Loop again

First_pass_done:
	RET

hex:
	; deal with EOF
	cmp eax, -4
	je EOF
	; deal with line comments starting with ;
	cmp eax, 0x23
	je ascii_comment
	; deal with line comments starting with ;
	cmp eax, 0x3b
	je ascii_comment
	; deal all ascii less than 0
	cmp eax, 0x30
	jl ascii_other
	; deal with 0-9
	cmp eax, 0x3a
	jl ascii_num
	; deal with all ascii less than A
	cmp eax, 0x41
	jl ascii_other
	; deal with A-F
	cmp eax, 0x47
	jl ascii_high
	;deal with all ascii less than a
	cmp eax, 0x61
	jl ascii_other
	;deal with a-f
	cmp eax, 0x67
	jl ascii_low
	; The rest that remains needs to be ignored
	jmp ascii_other

Second_pass:
	call Read_byte

	; Deal with EOF
	cmp eax, -4
	je Second_pass_done

	; Simply drop the label
	cmp eax, 0x3a
	jne Second_pass_0

	mov ebx, table              ; Using scratch
	call consume_token          ; Read token
	call ClearScratch           ; Throw away token

	jmp Second_pass

Second_pass_0:
	; Deal with % pointer
	cmp eax, 0x25
	je StorePointer_rel4

	; Deal with @ pointer
	cmp eax, 0x40
	je StorePointer_rel2

	; Deal with ! pointer
	cmp eax, 0x21
	je StorePointer_rel1

	; Deal with & pointer
	cmp eax, 0x26
	je StorePointer_abs4

	; Deal with $ pointer
	cmp eax, 0x24
	je StorePointer_abs2

Second_pass_1:
	; Deal with everything else
	call hex                    ; Process our char

	; Deal with EOF
	cmp eax, -4
	je Second_pass_done

	; deal with -1 values
	cmp eax, 0
	jl Second_pass

	; deal with toggle
	mov ebx, [Flag]
	cmp ebx, 0
	je print

	; process first byte of pair
	shl eax, 4
	mov [High], eax
	mov eax, 0
	mov [Flag], eax
	jmp Second_pass

Second_pass_done:
	ret

EOF:
	ret
ascii_num:
	sub eax, 0x30
	ret
ascii_low:
	sub eax, 0x57
	ret
ascii_high:
	sub eax, 0x37
	ret
ascii_other:
	mov eax, -1
	ret
ascii_comment:
	call Read_byte
	cmp eax, 0xd
	je ascii_comment_cr
	cmp eax, 0xa
	jne ascii_comment
ascii_comment_cr:
	mov eax, -1
	ret

; process second byte of pair
print:
	; update the sum and store in output
	add eax, [High]
	mov [table], al

	; flip the toggle
	mov eax, [Flag]
	not eax
	mov [Flag], eax

	; Print our first Hex
	mov edx,  1                 ; set the size of chars we want
	call print_chars

	add edi, 1                  ; Increment IP
	jmp Second_pass

Done:
	; program completed Successfully
	mov ebx, 0                  ; All is well
	mov eax, 1                  ; put the exit syscall number in eax
	int 0x80                    ; Call it a good day


;; Malloc isn't actually required if the program being built fits in the initial memory
;; However, it doesn't take much to add it.
;; Requires a value in EBX
malloc:
	mov eax, 45                 ; the Syscall # for SYS_BRK
	push esi                    ; Protect esi
	push edi                    ; Protect edi
	int 0x80                    ; call the Kernel
	pop edi                     ; Restore edi
	pop esi                     ; Restore esi
	ret


Read_byte:
	; Attempt to read 1 byte from STDIN
	push esi                    ; Protect esi
	push edi                    ; Protect edi
	push ebx                    ; Protect ebx
	push ecx                    ; Protect ecx

	mov edx,  1                 ; set the size of chars we want
	mov ecx, write              ; Where to put it
	mov ebx, [Input]            ; Where are we reading from
	mov eax, 3                  ; the syscall number for read
	int 0x80                    ; call the Kernel
	pop ecx                     ; Restore ecx
	pop ebx                     ; Restore ebx
	pop edi                     ; Restore edi
	pop esi                     ; Restore esi

	test eax, eax               ; check what we got
	je Read_byte_1              ; Got EOF call it done

	; load byte
	mov al, [write]             ; load char
	movzx eax, al               ; We have to zero extend it to use it
	ret

; Deal with EOF
Read_byte_1:
	mov eax, -4                 ; Put EOF in eax
	ret

print_chars:
	push esi                    ; Protect esi
	push edi                    ; Protect edi
	push ebx                    ; Protect ebx
	push ecx                    ; Protect ecx

	mov ecx, table              ; What we are writing
	mov ebx, [Output]           ; Write to target file
	mov eax, 4                  ; the syscall number for write
	int 0x80                    ; call the Kernel

	pop ecx                     ; Restore ecx
	pop ebx                     ; Restore ebx
	pop edi                     ; Restore edi
	pop esi                     ; Restore esi
	ret

;; Recieves pointer in EBX
;; Writes out char and updates EBX
consume_token:
	call Read_byte              ; Consume_token

	; Check for \t
	cmp eax, 0x09
	je consume_token_done

	; Check for \n
	cmp eax, 0x0A
	je consume_token_done

	; Check for ' '
	cmp eax, 0x20
	je consume_token_done

	; Check for '>'
	cmp eax, 0x3E
	je consume_token_done

	;; Looks like we are still reading token
	mov [ebx], al               ; Store char
	add ebx, 1                  ; Point to next spot
	jmp consume_token           ; loop until done

consume_token_done:
	mov ecx, 0                  ; Padd with nulls
	mov [ebx], ecx
	add ebx, 4
	ret

StoreLabel:
	mov eax, ebp                ; ENTRY
	add ebp, 24                 ; CALLOC
	mov [eax+8], edi            ; ENTRY->TARGET = IP
	mov [eax], esi              ; ENTRY->NEXT = JUMP_TABLE
	mov esi, eax                ; JUMP_TABLE = ENTRY
	mov [esi+16], ebp           ; ENTRY->NAME = TOKEN
	mov ebx, ebp                ; Write Starting after struct
	call consume_token          ; Collect whole string
	mov ebp, ebx                ; Update HEAP
	jmp First_pass

GetTarget:
	push ebx                    ; protect ebx
	push ecx                    ; protect ecx
	push edx                    ; protect edx
	push esi                    ; protect JUMP_TABLE
	mov ecx, table              ; Reset scratch
	mov edx, [esi+16]           ; I->NAME
GetTarget_loop:
	mov al, [ecx]               ; I->NAME[0]
	mov bl, [edx]               ; scratch[0]
	movzx ebx, bl               ; Zero extend
	movzx eax, al               ; Zero extend
	cmp al, bl                  ; IF TOKEN == I->NAME
	jne GetTarget_miss          ; Oops

	add ecx, 1
	add edx, 1
	cmp al, 0
	jne GetTarget_loop          ; Loop until
	jmp GetTarget_done          ; Match

	;; Miss
GetTarget_miss:
	mov esi, [esi]              ; I = I->NEXT
	cmp esi, 0                  ; IF NULL == I
	je fail                     ; Abort hard

	mov edx, [esi+16]           ; I->NAME
	mov ecx, table              ; Reset scratch
	jmp GetTarget_loop

GetTarget_done:
	mov eax, [esi+8]            ; Get address
	pop esi                     ; Restore JUMP_TABLE
	pop edx                     ; Restore EDX
	pop ecx                     ; Restore ECX
	pop ebx                     ; Restore EBX
	ret

ClearScratch:
	push eax                    ; Protect against changes
	push ebx                    ; And overwrites
	push ecx                    ; While we work
	mov ebx, table              ; Where our table is
	mov al, 0                   ; Using null

ClearScratch_loop:
	mov ecx, [ebx]              ; Get current value
	mov [ebx], al               ; Because we want null
	add ebx, 1                  ; Increment
	cmp ecx, 0                  ; Check if we hit null
	jne ClearScratch_loop       ; Keep looping

	pop ecx                     ; Restore
	pop ebx                     ; Damage
	pop eax                     ; Entirely
	ret

StorePointer:
	call Update_Pointer         ; Increment IP
	mov ebx, table              ; Write to scratch
	call consume_token          ; get token
	push eax                    ; Protect base_sep_p
	mov eax, table              ; Pointer to scratch
	call GetTarget              ; Get address of pointer
	call ClearScratch           ; Clean up after ourselves
	mov edx, edi                ; base = IP
	pop ebx                     ; Restore base_sep_p
	cmp ebx, 0x3E               ; If base_sep_p == '>'
	jne StorePointer_done       ; If not

	;; Deal with %label>label case
	push eax                    ; We need to preserve main target
	mov ebx, table              ; Write to scratch
	call consume_token          ; get token
	mov eax, table              ; Pointer to scratch
	call GetTarget              ; Get address of pointer
	call ClearScratch           ; Clean up after ourselves
	mov edx, eax                ; Use our new base
	pop eax                     ; Restore main target

StorePointer_done:
	ret

StorePointer_rel4:
	call StorePointer           ; Do Common
	sub eax, edx                ; target - ip
	mov [table], eax            ; put value in output
	mov edx,  4                 ; set the size of chars we want
	call print_chars
	call ClearScratch           ; Clean up after ourselves
	jmp Second_pass

StorePointer_rel2:
	call StorePointer           ; Do Common
	sub eax, edx                ; target - ip
	mov [table], eax            ; put value in output
	mov edx, 2                  ; set the size of chars we want
	call print_chars
	call ClearScratch           ; Clean up after ourselves
	jmp Second_pass

StorePointer_rel1:
	call StorePointer           ; Do Common
	sub eax, edx                ; target - ip
	mov [table], eax            ; put value in output
	mov edx, 1                  ; set the size of chars we want
	call print_chars
	call ClearScratch           ; Clean up after ourselves
	jmp Second_pass

StorePointer_abs4:
	call StorePointer           ; Do Common
	mov [table], eax            ; put value in output
	mov edx, 4                  ; set the size of chars we want
	call print_chars
	call ClearScratch           ; Clean up after ourselves
	jmp Second_pass

StorePointer_abs2:
	call StorePointer           ; Do Common
	mov [table], eax            ; put value in output
	mov edx, 2                  ; set the size of chars we want
	call print_chars
	call ClearScratch           ; Clean up after ourselves
	jmp Second_pass

fail:
	; Some shit went wrong
	mov ebx, 1                  ; All is wrong
	mov eax, 1                  ; put the exit syscall number in eax
	int 0x80                    ; Call it a good day


section .data
ELF_end:
High:
	dd 0
Flag:
	dd 0
Input:
	dd 0
Output:
	dd 0
write:
	dd 0
table:
	dd 66
