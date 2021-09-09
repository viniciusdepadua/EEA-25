/*
 * led_blink.asm
 *
 *  Created: 8/7/2021 7:43:01 PM
 *   Author: vinic
 */ 

 ;*********************************************************************
;*********************************************************************
;**   led-blink.asm                                                 **
;**                                                                 **
;**   Target uC: Atmel ATmega328P                                   **
;**   X-TAL frequency: 16 MHz                                       **
;**   AVRASM: AVR macro assembler 2.1.57 (build 16 Aug 27 2014 16:39:43)
;**                                                                 **
;**   Description:                                                  **
;**                                                                 **
;**       PORTs PD3 to PD0 connected to LEDs D4 to D1               **
;**       PD7 receiving input via the connect switch in the circuit **
;**                                                                 **
;**       The program configures the STACK POINTER and the PORTs    **
;**       from PDD7 to PD0 reseting all LEDs, next, it executes     **
;**       a loop without stoping.                                   **
;**       The loop goes as follows:                                 **
;**            1. Sets the LEDs                                     **
;**            2. Call the subroutine DELAY_500 for a 500ms delay   **
;**            3. Resets the LEDs                                   **
;**            4. Call the subroutine DELAY_500 for a 500ms delay   **
;**            5. Jumps to LOOP                                     **
;**                                                                 **
;**  Created: 2020/08/15 by chiepa                                  **
;**  Modified: 2021/08/16 by dloubach                               **
;*********************************************************************
;*********************************************************************

   ;; constant for 500ms delay in ATmega328 @ 16 MHz
   .EQU DELAY_CONST_500 = 375600

   .CSEG                        ; code segment in FLASH
   .ORG 0                       ; entry point after POWER/RESET

RESET:
   JMP   STARTUP
   .ORG  0x0100                 ; code starts after reserved
                                ; interrupt vector space address

STARTUP:
   LDI   R16, LOW(RAMEND)
   OUT   SPL, R16               ; SPL receives RAM end low part
   LDI   R16, HIGH(RAMEND)
   OUT   SPH, R16               ; SPH receives RAM end high part

   CALL  PORTD_INIT

LOOP:
   LDS   R16, LEDS
   ORI   R16, 0b00001111        ; PD3..PD0 to HIGH
   STS   LEDS, R16
   OUT   PORTD, R16

   CALL   DELAY_500              ; call our fixed delay

   LDS   R16, LEDS
   ANDI  R16, 0b11110000         ; PD3..PD0 to LOW
   STS   LEDS, R16
   OUT   PORTD, R16

   CALL  DELAY_500               ; call our fixed delay

   JMP   LOOP                    ; back to LOOP


;*********************************************************************
;  Subroutine PORTD_INIT
;  Configures PD7 to PD4 as INPUTS and PD3 to PD0 as OUTPUTS
;  Resets all four LEDs by writing 0s in PD3 to PD0, and holds the 
;  value of LEDs in the <LEDS> variable
;*********************************************************************
PORTD_INIT:
   LDI   R16, 0b00001111
   OUT   DDRD, R16
   LDI   R16, 0b00000000
   STS   LEDS, R16
   OUT   PORTD, R16
   RET

;*********************************************************************
; Subroutine DELAY_500
; Delay of 0.1 seconds for the ATmeag328 @ 16 MHz
; Makes COUNTER_3BYTES <-- 0x010E00 and decreases untill  0x000000
; Saves and restores from the STACK all used registers
;*********************************************************************
DELAY_500:
   PUSH  R16
   PUSH  R17
   PUSH  R18
   PUSH  XL
   PUSH  XH
   IN    R18, SREG
   PUSH  R18

LOADS_INIT_VALUE:
   LDI   XH, HIGH(COUNTER_3BYTES) ; X points to COUNTER_3BYTES
   LDI   XL, LOW(COUNTER_3BYTES)

   LDI   R16, DELAY_CONST_500>>16 ; value in COUNTER_3BYTES
   ST    X+, R16
   LDI   R16, (DELAY_CONST_500>>8) & 0xFF   ; value in COUNTER_3BYTES+1
   ST    X+, R16                   ;saves and increments the pointer X
   LDI   R16, DELAY_CONST_500 & 0xFF; value in COUNTER_3BYTES+2
   ST    X+, R16

   LDI   XH, HIGH(COUNTER_3BYTES)
   LDI   XL, LOW(COUNTER_3BYTES)

   ;; it returns if the value pointed by X is equal to ZERO
   ;; (number of three bytes from the MOST to LEAST significative byte)
ZERO_TEST:
   LD    R16, X+
   LD    R17, X+
   LD    R18, X+
   OR    R16, R16
   BRNE  DECREMENT
   OR    R17, R17
   BRNE  DECREMENT
   OR    R18, R18
   BRNE  DECREMENT
   JMP   DELAY_500_EXIT_POINT

DECREMENT:
   SUBI  R18, 1
   ST    -X, R18
   SBCI  R17, 0
   ST    -X, R17
   SBCI  R16, 0
   ST    -X, R16
   JMP   ZERO_TEST

DELAY_500_EXIT_POINT:
   POP   R18
   OUT   SREG, R18
   POP   XH
   POP   XL
   POP   R18
   POP   R17
   POP   R16
   RET


   .DSEG                 ; data segment in RAM
   .ORG  0x200           ; starting in 0x200, avoiding address
                         ; spaces from registers and I/O
COUNTER_3BYTES:
   .BYTE   3
LEDS:
   .BYTE   1

   .EXIT

