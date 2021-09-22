/*
 * usart_int.asm
 *
 *  Created: 9/22/2021 4:45:01 PM
 *   Author: vinic
 */ 


 ;*********************************************************************
;*   Projeto ATMega2560 USART Interrupt                              *
;*                                                                   *
;*   Compilador:                                                     *
;*   AVRASM: AVR macro assembler 2.1.57 (build 16 Aug 27 2014 16:39:43) *
;*   MCU alvo: Atmel ATmega2560 a 16 MHz com                         *
;*       - Módulos de Leds de 7 segmentos conectados ao PORTH;       *
;*       - Terminal alfanumérico "TERM1" conectado à USART1.         *
;*       - Terminal alfanumérico "TERM0" conectado à USART0.         *
;*                                                                   *
;*   Exemplifica interrupções do receptor da USART1                  *
;*   Descricao:                                                      *
;*                                                                   *
;*       Inicializa o Stack Pointer com RAMEND;                      *
;*       Configura  PORTH como saída e emite 0x00;                   *
;*       Configura a USART1 para operar no modo assincrono com       *
;*            9600 bps,                                              *
;*            1 stop bit,                                            *
;*            sem paridade,                                          *
;*            COM INTERRUPÇÕES DO RECEPTOR HABILITADAS;              *
;*       Habilita interrupções com "SEI";                            *
;*                                                                   *
;*       Parte principal fica em loop imprimindo o TERM0             *
;*       a mensagem "Hello World!".                                  *
;*                                                                   *
;*       Quando é acionada uma tecla do terminal, o interrupt        *
;        driver da USART1 é ativado e                                *
;*            Lê o caracter;                                         *
;*            Imprime o caracter em TERM1.                           *
;*            Apresenta o código hexadecimal nos displays de         *
;                7 segmentos;                                        *
;*            Retorna da interrupção com "RETI".                     * 
;*                                                                   *
;* Created: 20/08/2021 23:36:23 by chiepa                            *
;* Modified: 10/09/2021 11:19:20 by dloubach                         *   
;*********************************************************************

;***************
;* Constantes  *
;***************
; Constantes para configurar baud rate (2400:416, 9600:103, 57600:16, 115200:8).
   .equ  BAUD_RATE = 103           
   .equ  RETURN = 0x0A          ; Retorno do cursor.
   .equ  LINEFEED = 0x0D        ; Descida do cursor.
   .equ  USART1_RXC1_vect = 0x0048 ; Vetor para atendimento a interrupções RXC1.

;*****************************
; Segmento de código (FLASH) *
;*****************************
   .cseg

; Ponto de entrada para RESET.
   .org  0 
   jmp   RESET

;*************************************************************
;  PONTO DE ENTRADA DAS INTERRUPÇÕES DO RECEPTOR DA USART1   *
;*************************************************************
   .org  USART1_RXC1_vect
VETOR_USART1RX:
   jmp   USART1_RX1_INTERRUPT

   .org  0x100
RESET:
   ldi   r16, low(ramend)       ; Inicializa Stack Pointer.
   out   spl, r16               ; Para ATMega328 RAMEND=08ff.
   ldi   r16, high(ramend)
   out   sph, r16

   call  INIT_PORTS             ; Inicializa PORTH.
   call  USART0_INIT            ; Inicializa USART0.
   call  USART1_INIT            ; Inicializa USART1.

   sei                          ; Habilita interrupções.


;****************************************************************************************
;*                         PARTE PRINCIPAL DO PROGRAMA                                  *
;*                       ( Loop imprimindo para sempre a mensagem "Hello, World!" )     *
; Para imprimir o strings "Hello, World!" o Registrador Z é carregado com o dobro
; do endereço do string, pois no segmento de código os endereços correspondem a WORDs.
; Situação semelhante ocorre com outros strings armazenados no segmento de código.
LOOP_PRINCIPAL:
   ldi   zh, high(2*MensHello)   
   ldi   zl, low(2*MensHello)
   call  PRINT_USART0
   jmp   LOOP_PRINCIPAL

;*                         FIM DA PARTE PRINCIPAL DO PROGRAMA                           *
;****************************************************************************************


;****************************************************************************************
;*                        INTERRUPT DRIVER DO RECEPTOR DA USART1                        *
;                                USART1_RX1_INTERRUPT                                   * 


USART1_RX1_INTERRUPT:
   push  r16

; Esta interrupção foi disparada porque a USART1 recebeu um caracter
;   e este já está disponível em UDR1 podendo ser lido imediatamente,
;   sem a necessidade de testar o bit RXC1 do registrador UCSR1A.
   lds   r16,udr1               ; R16 <-- caractere recebido.
   sts   CARACTERE, r16

   call  USART1_TRANSMIT        ; Imprime caractere recebido.

   lds   r16, CARACTERE
   sts   porth, r16             ; Emite para módulos 7 segmentos.

   pop   r16
   reti

;*                         FIM DO INTERRUPT DRIVER DO RECEPTOR DA USAR11                *
;****************************************************************************************


;**************************************************
;  PRINT_USART0                                   *
;  Subrotina                                      *
;  Envia através da USART0 a mensagem apontada    *
;     por Z em CODSEG.                            *
;  O caractere '$' indica o término da mensagem.  *
;**************************************************
PRINT_USART0:
   push  r16
   lds   r16,sreg
   push  r16
   push  r17
   push  zh
   push  zl

PRINT_USART0_REP:
   lpm   r16, z+
   cpi   r16, '$'
   breq  FIM_PRINT_USART0
   call  USART0_Transmit
   jmp   PRINT_USART0_REP

FIM_PRINT_USART0:
   pop   zl
   pop   zh
   pop   r17
   pop   r16
   sts   sreg, r16
   pop   r16
   ret
            
;**************************************************
;  ASC_TO_HEX                                     *
;  Subrotina                                      *
;  Constroi em (R16,R17) a representacao do byte  *
;  contido em R16 para sua representacao          *
;  hexadecimal com dois caracteres ASCII.         *
;**************************************************
ASC_TO_HEX:
   mov   r17, r16
   andi  r17, 0b00001111
   lsr   r16
   lsr   r16
   lsr   r16
   lsr   r16
CONVERT_R16:
   cpi   r16, 10
   brsh  LETRAR_R16
   ldi   r18, '0'
   add   r16, r18
   jmp   CONVERT_R17
LETRAR_R16:
   ldi   r18, 'A'-10
   add   r16, r18

CONVERT_R17:
   cpi   r17, 10
   brsh  LETRAR_R17
   ldi   r18, '0'
   add   r17, r18
   jmp   FIM_ASC_TO_HEX
LETRAR_R17:
   ldi   r18, 'A'-10
   add   r17, r18

FIM_ASC_TO_HEX:
   ret

;***********************************
;  INIT_PORTS                      *
;  Inicializa PORTH como saída     *
;    e emite 0x00 em ambos.        *
;***********************************
INIT_PORTS:
   ldi   r16, 0b11111111
   sts   ddrh, r16
   ldi   r16, 0b00000000
   sts   porth, r16
   ret

;*****************************************
;  USART0_INIT                           *
;  Subrotina para inicializar a USART0.  *
;*****************************************
; Inicializa USART0: modo assincrono, 9600 bps, 1 stop bit, sem paridade.  
; Os registradores são:
;     - UBRR0 (USART0 Baud Rate Register)
;     - UCSR0 (USART0 Control Status Register B)
;     - UCSR0 (USART0 Control Status Register C)
USART0_INIT:
   ldi   r17, high(BAUD_RATE)   ;Estabelece Baud Rate.
   sts   ubrr0h, r17
   ldi   r16, low(BAUD_RATE)
   sts   ubrr0l, r16
   ldi   r16, (1<<rxen0)|(1<<txen0)   ;Habilita receptor e transmissor.

   sts   ucsr0b,r16
   ldi   r16,(0<<usbs0)|(1<<ucsz01)| (1<<ucsz00)   ;Frame: 8 bits dado, 1 stop bit,
   sts   ucsr0c, r16            ;sem paridade.

   ret

;*************************************
;  USART0_TRANSMIT                   *
;  Subrotina para transmitir R16.    *
;*************************************
USART0_TRANSMIT:
   push  r17                    ; Salva R17 na pilha.

WAIT_TRANSMIT0:
   lds   r17, ucsr0a
   sbrs  r17, udre0             ;Aguarda BUFFER do transmissor ficar vazio.      
   rjmp  WAIT_TRANSMIT0
   sts   udr0, r16              ;Escreve dado no BUFFER.


   pop   r17                    ; Restaura R17 e retorna.
   ret

;*******************************************
;  USART0_RECEIVE                          *
;  Subrotina                               *
;  Aguarda a recepção de dado pela USART0  *
;  e retorna com o dado em R16.            *
;*******************************************
USART0_RECEIVE:
   push  r17                    ; Salva R17 na pilha.

WAIT_RECEIVE0:
   lds   r17,ucsr0a
   sbrs  r17,rxc0
   rjmp  WAIT_RECEIVE0          ;Aguarda chegada do dado.
   lds   r16,udr0               ;Le dado do BUFFER e retorna.

   pop   r17                    ;; Restaura R17 e retorna.
   ret


;****************************************
;  USART1_INIT                          *
;  Subrotina para inicializar a USART.  *
;****************************************
; Inicializa USART1: modo assincrono, 9600 bps, 1 stop bit, sem paridade.  
; Os registradores são:
;     - UBRR1 (USART1 Baud Rate Register)
;     - UCSR1 (USART1 Control Status Register B)
;     - UCSR1 (USART1 Control Status Register C)
USART1_INIT:
   ldi   r17, high(BAUD_RATE)   ;Estabelece Baud Rate.
   sts   ubrr1h, r17
   ldi   r16, low(BAUD_RATE)
   sts   ubrr1l, r16


;**************************************************************************************************
; ICSRB1 inicializado com interrupções RXCIE1 (interrompe quando recebe caractere) habilitadas.   *
;**************************************************************************************************
   ldi   r16,(1<<rxcie1)|(1<<rxen1)|(1<<txen1)   ;Interrupções do receptor,
                                                 ;  receptor e transmissor.
   sts   ucsr1b,r16
   ldi   r16,(0<<usbs1)|(1<<ucsz11)| (1<<ucsz10)   ;Frame: 8 bits dado, 1 stop bit,
   sts   ucsr1c,r16             ;sem paridade.

   ret

;*************************************
;  USART1_TRANSMIT                   *
;  Subrotina para transmitir R16.    *
;*************************************

USART1_TRANSMIT:
   push  r17                    ; Salva R17 na pilha.

WAIT_TRANSMIT1:
   lds   r17, ucsr1a
   sbrs  r17, udre1             ;Aguarda BUFFER do transmissor ficar vazio.      
   rjmp  WAIT_TRANSMIT1
   sts   udr1, r16              ;Escreve dado no BUFFER.

   pop   r17                    ;Restaura R17 e retorna.
   ret

;*******************************************
;  USART1_RECEIVE                           *
;  Subrotina                               *
;  Aguarda a recepção de dado pela USART   *
;  e retorna com o dado em R16.            *
;*******************************************

USART1_RECEIVE:
   push  r17                    ; Salva R17 na pilha.

WAIT_RECEIVE1:
   lds   r17,ucsr1a
   sbrs  r17,rxc1
   rjmp  WAIT_RECEIVE1          ;Aguarda chegada do dado.
   lds   r16,udr1               ;Le dado do BUFFER e retorna.

   pop   r17                    ;Restaura R17 e retorna.
   ret

;*******************************************
; Strings e mensagens a serem impressas.   *
;    '$' é usado como terminador.          *
;*******************************************
MensHello:
   .db "hm   ",RETURN,LINEFEED,'$'

;************************************
; Segmento de dados (RAM)           *
; Mostra como alocar espaço na RAM  *
; para variaveis.                   *
;************************************
   .dseg
   .org   0x200
CARACTERE:
   .byte   1

;*****************************
; Finaliza o programa fonte  *
;*****************************
   .exit
