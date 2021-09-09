/*
 * IDassembly.asm
 *
 *  Created: 9/8/2021 10:08:41 AM
 *   Author: vinic
 */ 


 ;*********************************************************************
;*********************************************************************
;**   IDassembly.asm                                                **
;**                                                                 **
;**   Target uC: Atmel ATmega328P                                   **
;**   X-TAL frequency: 16 MHz                                       **
;**   AVRASM: AVR macro assembler 2.1.57 (build 16 Aug 27 2014 16:39:43)
;**                                                                 **
;**   Description:                                                  **
;**                                                                 **
;**       Sets the USART to operate in asynch mode with:            **
;**            57600 bps,                                          **
;**            1 stop bit,                                          **
;**            no  parity                                           **
;**                                                                 **
;**       The firmware main loop (FOREVER) communicates a message   **
;**       via a terminal which should be connected to the uC's      **
;**       RX and TX ports (USART).                                  **
;**       The loop goes as follows:                                 **
;**            1. Sends a message asking for a key to be pressed    **
;**               in the host keyboard                              **
;**            2. Waits for the incoming char to get received       **
;**            3. Prints a message indicating the received char and **
;**               the correspoding code                             **
;**            4. Back to setp 1.                                   ** 
;**                                                                 **
;**  Created: 2020/08/08 by chiepa                                  **
;**  Modified: 2021/09/08 by viniciusdepadua                        **										  
;*********************************************************************
;*********************************************************************

   ;; constants for baut rates
   .EQU	BAUD_RATE_57600 = 16
 
   .CSEG                         ; FLASH segment code
   .ORG	0                        ; entry point after POWER/RESET
	JMP   RESET

   .ORG	0x100

RESET:
	LDI	R16, LOW(0x8ff)	         ; init stack pointer
	OUT	SPL, R16
	LDI	R16, HIGH(0x8ff)
	OUT	SPH, R16
	CALL USART_INIT		     ; goes to USART init code
	LDI R16, 'i'

	LDI  R18, 0b00111100         ; set PD2 to PD5 as OUTPUTS and the others as INPUTS
    OUT  DDRD, R18               ;
    LDI  R19, 0b00000000         ; resets initial counter
    OUT  PORTD, R19              ; write it to PORT D

;*********************************************************************
;  Subroutine READY_TO_GO
;  Checks if switch is open
;*********************************************************************

READY_TO_GO:                    ; waits for open switch to start couting
   IN   R18,PIND                ;
   ANDI R18,0b10000000          ;
   BREQ READY_TO_GO             ;

FOREVER:
	CALL USART_RECEIVE
	CALL  CHECK_SWITCH
	JMP	  FOREVER

;*********************************************************************
;  Subroutine USART_INIT  
;  Setup for USART: asynch mode, 57600 bps, 1 stop bit, no parity
;  Used registers:
;     - UBRR0 (USART0 Baud Rate Register)
;     - UCSR0 (USART0 Control Status Register B)
;     - UCSR0 (USART0 Control Status Register C)
;*********************************************************************	
USART_INIT:
	LDI	R17, HIGH(BAUD_RATE_57600); sets the baud rate
	STS	UBRR0H, R17
	LDI	R16, LOW(BAUD_RATE_57600)
	STS	UBRR0L, R16
	LDI	R16, (1<<RXEN0)|(1<<TXEN0) ; enables RX and TX

	STS	UCSR0B, R16
	LDI	R16, (0<<USBS0)|(3<<UCSZ00); frame: 8 data bits, 1 stop bit
	STS	UCSR0C, R16            ; no parity bit

	LDI	ZH, HIGH(2*PROMPT)	  ; prints the "PROMPT"
	LDI	ZL, LOW(2*PROMPT)
	CALL	SENDS

	RET

;*********************************************************************
;  Subroutine USART_TRANSMIT  
;  Transmits (TX) R16   
;*********************************************************************
USART_TRANSMIT:
   PUSH R17                     ; saves R17 into stack

WAIT_TRANSMIT:
	LDS	R17, UCSR0A
	SBRS	R17, UDRE0		        ; waits for TX buffer to get empty
	RJMP	WAIT_TRANSMIT
	STS	UDR0, R16	           ; writes data into the buffer

	POP	R17                    ; restores R17
	RET

;*********************************************************************
;  Subroutine USART_RECEIVE
;  Receives the char from USART and places it in the register R16 
;*********************************************************************
USART_RECEIVE:
	PUSH	R17                    ; saves R17 into stack
	LDS	R17, UCSR0A

	SBRS	R17, RXC0
	RJMP	TRASH	        ; waits for the data incomings

	POP	R17                    ; restores R17
	CALL CONFIRMATION
	RET

TRASH:
	POP R17 
	RET 
;*********************************************************************
;  Subroutine CONFIRMATION
;  Sends a message of command confirmation to the prompt
;*********************************************************************
CONFIRMATION:	
	LDS   R16, UDR0		        ; reads the data

	LDI	ZH, HIGH(2*RESULT)     ; prints result message
	LDI	ZL, LOW(2*RESULT)
	CALL	SENDS

	CALL	USART_TRANSMIT    ; prints received char

	LDI	ZH, HIGH(2*CRLF)	    ; prints <carriage return> & <line feed>
	LDI	ZL, LOW(2*CRLF)
	CALL  SENDS
	RET
;*********************************************************************
;  Subroutine SENDS
;  Sends a message pointed by register Z in the FLAHS memory
;*********************************************************************
SENDS:
	PUSH	R16

SENDS_REP:
	LPM	R16, Z+
    CPI	R16, '$'
    BREQ	END_SENDS
    CALL	USART_TRANSMIT
    JMP	SENDS_REP
END_SENDS:
	POP	R16
    RET


;*********************************************************************
;  Subroutine COMMAND
;  Checks USART command
;*********************************************************************
COMMAND:
	CALL  USART_RECEIVE  		 ;  Read command and decides D or I
	CPI R16, 'I'					
	BREQ INCREMENTS
	CPI R16, 'i'
	BREQ INCREMENTS              ;
   	CPI R16, 'D'
	BREQ DECREMENTS
	CPI R16, 'd'
	BREQ DECREMENTS

;*********************************************************************
;  Subroutine CHECK_SWITCH
;  Checks if Switch is pressed
;*********************************************************************
CHECK_SWITCH:
   IN   R18, PIND               ;
   ANDI R18, 0b10000000         ;
   BRNE CHECK_SWITCH            ;
                                
WAIT_SWITCH_RELEASE:            ; waits for switch release
   IN   R18,PIND                ;
   ANDI R18,0b10000000          ;
   BREQ WAIT_SWITCH_RELEASE     ;
   CALL COMMAND

;*********************************************************************
;  Subroutine INCREMENTS
;  Increments Register R19
;*********************************************************************
INCREMENTS:                     ; counter increments and LED update
   INC  R19
   MOV  R20, R19
   LSL  R20
   LSL  R20                      ;
   OUT  PORTD, R20               ;
   JMP FOREVER	

;*********************************************************************
;  Subroutine DECREMENTS
;  Decrements Register R19
;*********************************************************************
DECREMENTS:                     ; counter decrements and LED update
   DEC  R19
   MOV  R20, R19
   LSL  R20
   LSL  R20                     ;
   OUT  PORTD, R20              ;
   JMP FOREVER	

;*********************************************************************
; Hard coded message
;*********************************************************************
PROMPT: 
	.DB  "::Press I for increasing the counter ", 0x0a, 0x0d, "::Press D for decreasing the counter", 0x0a, 0x0d, '$'

RESULT: 
	.DB "You Chose: ", '$', 0x0a, 0x0d

CRLF:
	.DB  " ",  0x0a, 0x0d ,'$'           ; carriage return & line feed chars


;*********************************************************************
; Data segment (RAM)
; Shows how to allocate space in the RAM for variables
; This is not used in this program
;*********************************************************************
.DSEG
   .ORG 0x200
CONTADOR_BYTE:
	.BYTE	1
CONTADOR_WORD:
	.BYTE	2 


   .EXIT
