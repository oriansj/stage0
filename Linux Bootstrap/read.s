## Copyright (C) 2016 Jeremiah Orians
## This file is part of stage0.
##
## stage0 is free software: you an redistribute it and/or modify
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

.data
# we must export the entry point to the ELF linker or loader.
# They convientionally recognize _start as their entry point.
# Use ld -e main to override the default if you wish
.global _start

_start:

	# first check that we got the correct number of inputs
	pop	%rax		# Get the number of arguments
	pop	%rdi		# Get the program name
	pop	%rdi		# Get the actual argument

	# Check if we have the correct number of inputs
	cmp	$2, %rax

	# Jump to Bail if the number is not correct
	jne	Bail

	# attempt to open the file for reading
	mov	$0, %rsi	# prepare read_only
				# we already have what we need in ebx
	mov $2, %rax		# the syscall number for open()
	syscall		# call the Kernel

	# Check if we have a valid file
	test	%rax, %rax

	# Jump to Bail_file if not actual file
	js	Bail

	mov %rax, %rdi	# move the pointer to the right location

Circle:	#print contents of file

	mov $read_size, %rdx	# set the size of chars we want
	mov $buffer, %rsi	# Where to put it
				# We already have what we need in ebx
	mov $0, %rax		# the syscall number for read
	syscall		# call the Kernel

	test %rax, %rax	# check what we got
	jz Done		# Got EOF call it done

	# Make sure we don't write a bunch of NULLs
	mov %rax, %rdx

	# get file pointer out of the way
	movq %rdi, %rsp

				# edx was already setup
	mov $1, %rdi		# setup stdout write
	mov $1, %rax		# setup the write
	syscall			# call the Kernel

	#now to prepare for next loop
	movq %rsp, %rdi
	jmp Circle

Done:
	# program completed Successfully
	mov	$0, %rdi	# All is well
	mov	$60, %rax	# put the exit syscall number in eax
	syscall		# Call it a good day

Bail:
	# terminate with an error
	mov	$1, %rdi	# there was an error
	mov	$60, %rax	# put the exit syscall number in eax
	syscall		# bail out

# Our writable space
# 2^ 30 Should be enough per read
read_size = 1073741824
buffer:
	.space 1
