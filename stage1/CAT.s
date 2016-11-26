;; CAT program
;; Concatinates multiple tapes into a single tape output
;; Read tapes in tape_01 and writes the assembled result
;; Into tape_02 and stops when user precesses C-d
:start
	;; Prep TAPE_02
	LOADUI R0 0x1101
	FOPEN_WRITE


;; Read_file function
;; Primary work function
;; Copies contents of TAPE_01 to TAPE_02
;; Then calls a user interaction function at EOF
:Read_file
	;; Prep TAPE_01
	LOADUI R0 0x1100
	FOPEN_READ
:Read_Loop
	;; Read Byte
	LOADUI R1 0x1100            ; Reading from TAPE_01
	FGETC                       ; Get a byte

	;; Check for EOF
	CMPSKIPI.GE R0 0
	JUMP @Read_Cleanup

	;; Write the Byte
	LOADUI R1 0x1101            ; Write to TAPE_02
	FPUTC                       ; That byte

	JUMP @Read_Loop             ; Loop until EOF

:Read_Cleanup
	;; Close up TAPE_01
	LOADUI R0 0x1100
	FCLOSE
	JUMP @Prompt_User           ; See if user wants to read another


;; Closeup function
;; A minimal cleanup function to ensure we end
;; In a known good state
:Closeup
	;; Close up TAPE_02
	LOADUI R0 0x1101
	FCLOSE
	HALT


;; Prompt_User function
;; Displays message to user
;; Jumps to Read_file if [ENTER]
;; Otherwise Closeup to register
;; All done reading tapes and to start closeout
:Prompt_User
	FALSE R1                    ; Using TTY
	FALSE R3                    ; Starting at beginning
	LOADUI R4 $Prompt_Text      ; of the prompt text

:Prompt_Loop
	LOADXU8 R0 R3 R4            ; Get a char
	CMPSKIPI.NE R0 0            ; If NULL
	JUMP @Prompt_Done           ; We reached the end
	FPUTC                       ; Write it to TTY
	ADDUI R3 R3 1               ; Move to next char
	JUMP @Prompt_Loop           ; And loop again

:Prompt_Done
	LOADUI R0 10                ; Using LF
	FPUTC                       ; Terminate Line
	FGETC                       ; Get user input

	;; Check for Ctrl-D
	CMPSKIPI.NE R0 4            ; If user hit Ctrl-D
	JUMP @Closeup

	;; Otherwise assume user wants to read another tape from TAPE_01
	JUMP @Read_file

:Prompt_Text
"Press [Enter] to read next tape or Ctrl-d to be done"
