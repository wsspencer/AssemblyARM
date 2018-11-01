;---------------------------------------------------------------------
; File:     armkey.s
;
; Function: This program writes 'hello world' to the file hello.out (currently)
;			This program was made using the "ARM assembler" and uses ARM Software
;			Interrupts (SWI) to access ASCII files.  
;			This program WILL open an input file named "key.in" and an output
;			file named "key.out" and subsequently read a line of ASCII text with
;			printable characters and control characters (00h-7fh) from the file
;			key.in into an input string.  The read string "ARM SWI" will remove
;			any end of line indication or characters and replace them with a
;			single binary 0.  If there are no more lines the read string "ARM
;			SWI" will return a count of zero for the number of bytes read.
;
;			The program processes the characters in that line.  For each
;			character the program performs the following:
;			- If the character is an upper case letter (A-Z) then move it to the
;			output string.
;			- If the character is a lower case letter (a-z) then convert it to
;			an uppercase letter and move it to the output string.
;			- If the character is a blank (20h) then move it to the output
;			string.
;			- If the character is a hex zero (00h) then move it to the output
;			string.  This also signifies the end of the input string.
;			- If the character is anything else then do not move it to the
;			output string, just throw the character away.  This includes any
;			control characters in the range of 01-1Fh including the DOS end of
;			file character 1Ah.
;
;			After processing all characters on the input line, write the output
;			string and a carriage return and line feed to the output file.
;			The program continues to read and process input lines until the read
;			string ARM Software Interrupt returns a count of zero for the number
;			of bytes read which is an end of file indication.  The program closes
;			the input and output file and halts.
;
;
;			NOTE:  
;			Jumps in ARM architecture are "branches" from greater, less, and equal
;			compares. (e.g. bgt, blt, beq
;
;			Reference the projections file for ARM Architecture/programming.
;			ARM Programmers Model:  
;			- Memory address space is 4 Gigabytes
;			- Data sizes: Byte (8bit), Halfword (16bit), Word (32bit) {unsigned,
;			twos complement}
;			- 16 registers, all 32bit:
;				r0: general purpose
;				r12: general purpose
;				r13: Stack Pointer
;				r14: Link Registers
;				r15: Program Counter
;			- Status Register: 4 left bits are the Condition Code (N, Z, V same as 
;			x86 but C is different)
;				N | Z | C | V |  |  | ...
;				N: Left-most bit of the result for signed numbers 0=pos 1=neg
;				Z: 1=result zero 0=result not zero
;				C: 1= carry out of msb on add (same as x86...unsigned overflow)
;				V: 1=signed overflow 0=no signed overflow
;
; Author:   W. Scott Spencer
;
; Changes:  Date        Reason
;           ----------------------------------------------------------
;           04/05/2018  Original version/creation
;			04/06/2018  Added test cases, presumed working...
;			04/06/2018  Program working, needs efficiency work
;---------------------------------------------------------------------

;----------------------------------
; Software Interrupt values
;----------------------------------
         .equ SWI_Open,  0x66     ;Open  a file
         .equ SWI_Close, 0x68     ;Close a file
         .equ SWI_PrStr, 0x69     ;Write a null-ending string
         .equ SWI_RdStr, 0x6a     ;Read a string and terminate with null char
         .equ SWI_Exit,  0x11     ;Stop execution
;----------------------------------
                                  ;
         .global   _start         ;start will be known to external programs
         .text                    ;start instructions
                                  ;
;----------------------------------
; open output and input files
; - r0 points to the file name
; - r1 1 for output
; - the open swi is 66h
; - after the open r0 will have the file handle
;----------------------------------
_start:                           ;
         ldr  r0, =InFileName     ;r0 points to the file name
         ldr  r1, =0              ;r1 = 0 specifies the file is input
         swi  SWI_Open            ;open the file ... r0 will be the file handle
         ldr  r1, =InFileHandle   ;r1 points to input file handle location
         str  r0, [r1]            ;store the file handle
		 
		 ldr  r0, =OutFileName    ;r0 points to the output file name
		 ldr  r1, =1			  ;r1 = 1 specifies the file is output
		 swi  SWI_Open			  ;open the output file ... r0 will be file handle
		 ldr  r1, =OutFileHandle  ;r1 points to output file handle location
		 str  r0, [r1]			  ;store the file handle
		 
;----------------------------------
; Initialize Instring and Outstring into r0 and r1
;----------------------------------
_read:
		 ldr r0, =InFileHandle
		 ldr r0, [r0]
		 ldr r1, =InString
		 ldr r2, =80
		 swi SWI_RdStr			  ;read string from input file
		 
		 cmp r0,#0				  ;if ARM software interrupt reports a count of zero for
		 beq _exit				  ;# bytes read from input, we've hit an EOF, so jump to _exit
		 
		 ldr r0, =InString		  ;r0 points to input string
		 ldr r1, =OutString		  ;r1 points to output string

;----------------------------------
; Continually load the next byte and then increasing the input pointer
;----------------------------------
_nextByte:
		 ldrb  r2, [r0], #1		  ;load next input byte into r2 and increment input pointer

;----------------------------------
; Test case for blank (ascii 20h [or 32d] move it to output)
;----------------------------------		 
		  cmp  r2,#32			  ;compare to ascii 32d (20h)...
		  beq  _strBuild		  ;if equal in compare, branch to string build
		  
;----------------------------------
; Test case for end of line character (ascii 00h [or 0d]) {anything outside of these tests, we throw away}
;----------------------------------	
		  cmp  r2,#0			  ;compare to ascii 0d (00h)...
		  beq  _strBuild		  ;if equal in compare, branch to string build

;----------------------------------
; Test case for capital letter (move to output)
;----------------------------------	
 _testCap:
		 cmp  r2,#90			  ;compare to #90...
		 bgt  _testLowerC		  ;branch to capitalize/throw away if greater
		 cmp  r2,#64			  ;compare to #64 (since we want >64 to branch to strBuild, not >=65)
		 bgt  _strBuild			  ;branch to add to our string build if greater (else fall through to capitalize)
 
;----------------------------------
; Capitalize for lower-case letter (capitalize by subtracting #32 and move to output)
;----------------------------------
 _testLowerC:
		  cmp r2,#122			  ;compare to 122..
		  bgt _nextByte			  ;if greater, branch to _nextByte
		  cmp r2,#97			  ;compare 97
		  blt _nextByte			  ;if less, branch to _nextByte (if we get passed these cases, we fall through)...

		  sub r2,r2,#32			  ;subtract 32d (because if we reach this point it's lower-case ASCII and
								  ;subtracting 32d will capitalize it, and we will fall through to _strBuild.)
;----------------------------------
; Build string by storing byte and incrementing pointer
;----------------------------------
_strBuild:
		 strb r2,[r1],#1		  ; store the byte and increment input pointer
		 cmp r2,#0				  ; compare r2 with end of line, if it isn't, jump back to nextByte
		 bne _nextByte

;----------------------------------
; Write the output string
;----------------------------------
_write:
         ldr  r0, =OutFileHandle  ;r0 points to the output file handle
         ldr  r0, [r0]            ;r0 has the output file handle
         ldr  r1, =OutString      ;r1 points to the output string (test string for now)
         swi  SWI_PrStr           ;write the null terminated string
		 ldr  r1, =CRLF			  ;r1 has the carriage return + line feed
		 swi  SWI_PrStr			  ;write the carriage return + line feed
		 
		 b _read				  ;branch back to _read here
;----------------------------------

;----------------------------------
; Close output and input files
; Terminate the program
;----------------------------------
_exit:                            ;
         ldr  r0, =InFileHandle   ;r0 points to the input file handle
         ldr  r0, [r0]            ;r0 has the input file handle
         swi  SWI_Close           ;close the file

         ldr  r0, =OutFileHandle  ;r0 points to the output file handle
         ldr  r0, [r0]            ;r0 has the output file handle
         swi  SWI_Close           ;close the file
                                  ;
         swi  SWI_Exit            ;terminate the program
;----------------------------------

;----------------------------------
         .data                    ; start data
;----------------------------------
InFileHandle:  .skip 4			  ;4 byte field to hold the input file handle
OutFileHandle: .skip 4            ;4 byte field to hold the output file handle
                                  ;
InString:	 .skip 128			  ;128 bytes for input string
OutString:   .skip 128		 	  ;128 bytes for output string
TestString:  .asciz "testing 123" ;for testing purposes
                                  ;
CRLF:		 .byte 13, 10, 0	  ;Carriage return, line feed (for skipline)
								  ;
InFileName:  .asciz "KEY.IN"	  ;Input file name, null terminated
OutFileName: .asciz "KEY.OUT"     ;Output file name, null terminated

;----------------------------------

         .end
