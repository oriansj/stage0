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

.data
# we must export the entry point to the ELF linker or loader.
# They convientionally recognize _start as their entry point.
# Use ld -e main to override the default if you wish
.global _start

_start:
loop:
	# Attempt to read a single byte from STDIN
	mov $1, %rdx		# set the size of chars we want
	mov $input, %rsi	# Where to put it
	mov $0, %rdi		# Where are we reading from
	mov $0, %rax		# the syscall number for read
	syscall		# call the Kernel

	# If we didn't read any bytes jump to Done
	test %rax, %rax		# check what we got
	jz Done			# Got EOF call it done

	# Move our byte into registers for processing
	movb input, %al		# load char
	movzx %al, %r12		# We have to zero extend it to use it
	movzx %al, %r13		# We have to zero extend it to use it

	# Break out the nibbles
	shr $4, %r12		# Purge the bottom 4 bits
	and $0xF, %r13		# Chop off all but the bottom 4 bits

	# add our base pointer
	add $output, %r12	# Use that as our index into our array
	add $output, %r13	# Use that as our index into our array

	# Print our first Hex
	mov $1, %rdx		# set the size of chars we want
	mov %r12, %rsi		# What we are writing
	mov $1, %rdi		# Stdout File Descriptor
	mov $1, %rax		# the syscall number for write
	syscall		# call the Kernel

	# Print our second Hex
	mov $1, %rdx		# set the size of chars we want
	mov %r13, %rsi		# What we are writing
	mov $1, %rdi		# Stdout File Descriptor
	mov $1, %rax		# the syscall number for write
	syscall		# call the Kernel
	jmp loop

Done:
	# program completed Successfully
	mov	$0, %rdi	# All is well
	mov	$60, %rax	# put the exit syscall number in eax
	syscall		# Call it a good day

write_size = 2
output: .byte 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x0A
input:
	.byte write_size
