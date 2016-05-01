.text # section declaration
msg:
	.string "needs a proper file name\n"
	len = . - msg # length of our dear string

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
	syscall			# Call it a good day

Bail:
	# first let the user know what was wrong
	mov $len,%rdx 	# third argument: message length
	mov $msg,%rsi 	# second argument: pointer to message to write
	mov $1,%rdi		# first argument: file handle (stdout)
	mov $1,%rax		# system call number (sys_write)
	syscall			# call kernel
	
	# Second terminate with an error
	mov	$1, %rdi	# there was an error
	mov	$60, %rax	# put the exit syscall number in eax
	syscall			# bail out

