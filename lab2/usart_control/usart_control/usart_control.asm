/*
 * usart_control.asm
 *
 *  Created: 9/22/2021 3:15:35 AM
 *   Author: vinic
 */ 

 ;*********************************************************************
;*********************************************************************
;**   usart-control.asm                                             **
;**                                                                 **
;**   Target uC: Atmel ATmega328P                                   **
;**   X-TAL frequency: 16 MHz                                       **
;**   AVRASM: AVR macro assembler 2.1.57 (build 16 Aug 27 2014 16:39:43)
;**                                                                 **
;**   Description:                                                  **
;**                                                                 **
;**   In DSEG the following variables are declared:                 **
;**       COUNTER: 1 byte, number of transmissions of each char     **
;**                in the USART interface                           **
;**       DATA:    1 byte, char code to be transmited in each       **
;**                main loop execution                              **
;**       DELAY:  2 bytes, used in the subroutine DELAY_100US        **
;**               this is to store the 16-bit number (unsigned)     **
;**                                                                 **
;**   In CSEG the code is briefly the following:                    **
;**   RESET:                                                        **
;**   Sets the stack pointer                                        **
;**   Sets the USART to operate in asynch mode with:                **
;**            57600 bps,                                           **
;**            1 stop bit,                                          **
;**            no  parity                                           **
;**   MAIN_LOOP:                                                    **
;**          sets the variables COUNTER and DATA,                   **
;**          DATA <-- 0b00000000 (first byte to b ser transmitido), **
;**          COUNTER <-- NCHARS (number of printes of each char     **
;**                      in an main loop's execution                **
;**   PRINT_CHAR:                                                   **
;**          IF COUNTER == 0, goes to CHANGE_CHAR                   **
;**          Transmits DATA throught the USART interface            **
;**          Delay of 100 micro seconds                             **
;**          COUNTER <-- COUNTER-1                                  **
;**          jumps to   PRINT_CHAR                                  **
;**                                                                 **
;**   CHANGE_CHAR:                                                  **
;**          IF DATA == 0b11111111, goes to MAIN_LOOP               **
;**              DATA <-- DATA+1                                    **
;**              COUNTER <-- NCHARS                                 **
;**          jumps to  PRINT_CHAR                                   **
;**                                                                 **
;**  Created: 2020/08/08 by chiepa                                  **
;**  Modified: 2021/08/13 by dloubach                               **
;*********************************************************************
;*********************************************************************

   ;; constants for baut rates
   .EQU  BAUD_RATE_2400 = 416
   .EQU  BAUD_RATE_9600 = 103
   .EQU  BAUD_RATE_57600 = 16
   .EQU  BAUD_RATE_115200 = 8
   
   .EQU  NCHARS = 255           ; number of tx for each char
   .EQU  DELAY_CONST_100US = 9650    ; constant for subroutine DELAY_100US
   .EQU  INITIAL_DATA = '0'     ; initial data '0'.


   .CSEG                        ; FLASH segment code
   .ORG  0                      ; entry point after POWER/RESET
   JMP   RESET

   .ORG  0x100

RESET:
   LDI   R16, LOW(0x8ff)        ; setup stack pointer       
   OUT   SPL, R16
   LDI   R16, HIGH(0x8ff)
   OUT   SPH, R16

   CALL  USART_INIT             ; setup of the USART

MAIN_LOOP:
   LDI   R16, INITIAL_DATA
   STS   DATA, R16
   LDI   R16, NCHARS
   STS   COUNTER, R16

PRINT_CHAR:
   LDS   R16, COUNTER
   OR    R16, R16
   BREQ  CHANGE_CHAR
 
   LDS   R16,DATA
   CALL  USART_TRANSMIT
   CALL  DELAY_100US
   LDS   R16,COUNTER
   DEC   R16
   STS   COUNTER, R16
   JMP   PRINT_CHAR

CHANGE_CHAR:
   LDS   R16, DATA
   CPI   R16, 0b11111111        ; alterady tx   0b11111111?
   BREQ  MAIN_LOOP
   INC   R16                    ; did not reached to 0b11111111 yet
   STS   DATA, R16
   LDI   R16, NCHARS
   STS   COUNTER, R16
   JMP   PRINT_CHAR             ; go forward with the next char      


;*********************************************************************
;  Subroutine USART_INIT  
;  Setup for USART: asynch mode, 57600 bps, 1 stop bit, no parity
;  Used registers:
;     - UBRR0 (USART0 Baud Rate Register)
;     - UCSR0 (USART0 Control Status Register B)
;     - UCSR0 (USART0 Control Status Register C)
;*********************************************************************   
USART_INIT:
   LDI   R17, HIGH(BAUD_RATE_57600); sets the baud rate
   STS   UBRR0H, R17

   LDI   R16, LOW(BAUD_RATE_57600)
   STS   UBRR0L, R16

   LDI   R16, (1<<RXEN0)|(1<<TXEN0) ; enables RX and TX
   STS   UCSR0B, R16

   LDI   R16, (0<<USBS0)|(3<<UCSZ00); frame: 8 data bits, 1 stop bit
   STS   UCSR0C, R16            ; no parity bit

   RET

;*********************************************************************
;  Subroutine USART_TRANSMIT  
;  Transmits (TX) R16   
;*********************************************************************
USART_TRANSMIT:
   PUSH  R17                    ; saves R17 into stack

WAIT_TRANSMIT:
   LDS   R17, UCSR0A
   SBRS  R17, UDRE0             ; waits for TX buffer to get empty
   RJMP  WAIT_TRANSMIT
   STS   UDR0, R16              ; writes data into the buffer

   POP   R17                    ; restores R17
   RET

;*********************************************************************
;  Subroutine USART_RECEIVE
;  Receives the char from USAR and places it in the register R16 
;*********************************************************************
USART_RECEIVE:
   PUSH  R17                    ; saves R17 into stack

WAIT_RECEIVE:
   LDS   R17, UCSR0A
   SBRS  R17, RXC0
   RJMP  WAIT_RECEIVE           ; waits for the data incomings
   LDS   R16, UDR0              ; reads the data

   POP   R17                    ; restores R17
   RET

;*********************************************************************
;  Subroutine DELAY_100US
;  This takes about 100 us (micro seconds)
;  It setups the 16-bit variable DELAY with a constant
;  and decrements the variable untill ZERO
;  
;  The variable value (16-bit number) is stored within two bytes from
;  variable starting address, following LSB and MSB
;*********************************************************************

DELAY_100US:
   PUSH  R16
   PUSH  R17

   LDI   XH, HIGH(DELAY)
   LDI   XL, LOW(DELAY)
   LDI   R16, LOW(DELAY_CONST_100US)
   ST    X+, R16
   LDI   R16, HIGH(DELAY_CONST_100US)
   ST    X, R16

LOOP_DELAY:
   LDI   XH, HIGH(DELAY)
   LDI   XL, LOW(DELAY)
   
   LD    R16, X
   SUBI  R16, 1
   ST    X+, R16
   LD    R16, X
   SBCI  R16, 0
   ST    X, R16
   OR    R16, R17
   BREQ  FIM_DELAY
   JMP   LOOP_DELAY

FIM_DELAY:
   POP   R17
   POP   R16
   RET

;*********************************************************************
; Data segment (RAM)
; Shows how to allocate space in the RAM for variables
;*********************************************************************
   .DSEG
   .ORG  0x200
COUNTER:
   .BYTE 1
DATA:
   .BYTE 1             
DELAY:
   .BYTE 2
   
   .EXIT

