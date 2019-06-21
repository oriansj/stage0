## Copyright (C) 2016 Jeremiah Orians
## This file is part of stage0.
##
## stage0 is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## stage0 is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with stage0.  If not, see <http://www.gnu.org/licenses/>.

# Our writable space
.data
.global _start
hex:
	# Purge Comment Lines
	cmp $35, %rax
	je purge_comment
	# deal all ascii less than 0
	cmp $48, %rax
	jl ascii_other
	# deal with 0-9
	cmp $58, %rax
	jl ascii_num
	# deal with all ascii less than A
	cmp $65, %rax
	jl ascii_other
	# deal with A-F
	cmp $71, %rax
	jl ascii_high
	#deal with all ascii less than a
	cmp $97, %rax
	jl ascii_other
	#deal with a-f
	cmp $103, %rax
	jl ascii_low
	# The rest that remains needs to be ignored
	jmp ascii_other

purge_comment:
	# Attempt to read 1 byte from STDIN
	mov $1, %rdx		# set the size of chars we want
	mov $input, %rsi	# Where to put it
	mov $0, %rdi		# Where are we reading from
	mov $0, %rax		# the syscall number for read
	syscall		# call the Kernel

	test %rax, %rax	# check what we got
	jz Done		# Got EOF call it done

	# load byte
	movb input, %al	# load char
	movzx %al, %rax	# We have to zero extend it to use it

	# Loop if not LF
	cmp $10, %rax
	jne purge_comment

	# Otherwise return -1
	mov $-1, %rax
	ret

ascii_num:
	sub $48, %rax
	ret
ascii_low:
	sub $87, %rax
	ret
ascii_high:
	sub $55, %rax
	ret
ascii_other:
	mov $-1, %rax
	ret

_start:
	# Our flag for byte processing
	mov $-1, %r15

	# temp storage for the sum
	mov $0, %r14
loop:

	# Attempt to read 1 byte from STDIN
	mov $1, %rdx		# set the size of chars we want
	mov $input, %rsi	# Where to put it
	mov $0, %rdi		# Where are we reading from
	mov $0, %rax		# the syscall number for read
	syscall		# call the Kernel

	test %rax, %rax	# check what we got
	jz Done		# Got EOF call it done

	# load byte
	movb input, %al	# load char
	movzx %al, %rax	# We have to zero extend it to use it

	# process byte
	call hex

	# deal with -1 values
	cmp $0, %rax
	jl loop

	# deal with toggle
	cmp $0, %r15
	jge print

	# process first byte of pair
	mov %rax, %r14
	mov $0, %r15
	jmp loop

# process second byte of pair
print:
	# update the sum and store in output
	shl $4, %r14
	add %r14, %rax
	mov %al, output

	# flip the toggle
	mov $-1, %r15

	# Print our first Hex
	mov $1, %rdx		# set the size of chars we want
	mov $output, %rsi	# What we are writing
	mov $1, %rdi		# Stdout File Descriptor
	mov $1, %rax		# the syscall number for write
	syscall		# call the Kernel

	jmp loop

Done:
	# program completed Successfully
	mov	$0, %rdi	# All is well
	mov	$60, %rax	# put the exit syscall number in eax
	syscall		# Call it a good day


read_size = 2
input:
	.byte read_size
output:
	.byte 0x00
