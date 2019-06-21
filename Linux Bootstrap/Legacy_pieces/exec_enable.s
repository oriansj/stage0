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

.text # section declaration

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

	# Load our preferred mode
	mov	$0755, %rsi

	# Load the syscall number for chmod
	mov	$90, %rax

	# Call the kernel
	syscall

Done:
	# program completed Successfully
	mov	$0, %rdi	# All is well
	mov	$60, %rax	# put the exit syscall number in eax
	syscall		# Call it a good day

Bail:
	# Second terminate with an error
	mov	$1, %rdi	# there was an error
	mov	$60, %rax	# put the exit syscall number in eax
	syscall		# bail out
