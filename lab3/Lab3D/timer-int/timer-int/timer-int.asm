/*
 * timer_int.asm
 *
 *  Created: 9/22/2021 5:10:29 PM
 *   Author: vinic
 */ 


 ;************************************************************************
;*   Projeto ATMega2560 TIMER Interrupt                                 *
;*                                                                      *
;*   Compilador:                                                        *
;*   AVRASM: AVR macro assembler 2.1.57 (build 16 Aug 27 2014 16:39:43) *
;*                                                                      *
;*   MCU alvo: Atmel ATmega2560 a 16 MHz com                            *
;*       - Módulos de Leds de 7 segmentos conectados ao PORTH;          *
;*       - Terminal alfanumérico "TERM0" conectado à USART0.            *
;*                                                                      *
;*   Exemplifica interrupções periódicas do TIMER1 operando             *
;*     no modo 4 (Clear on Terminal Count).  O TIMER1 recebe pulsos     *
;*     da saída Clk=16MHz/1024 do PRESCALER e conta pulsos de           *
;*     0 a 15625, valor com o qual OCR1A é inicializado.  Assim,        *
;*     de 1024 X 15625 = 16000000 em 16000000 pulsos é produzida uma    *
;*     interrupção (uma interrupção por segundo).                       *
;*                                                                      *
;*   Descricao:                                                         *
;*                                                                      *
;*       Inicializa o Stack Pointer com RAMEND;                         *
;*       Configura  PORTH como saída e emite 0x00;                      *
;*       Configura a USART0 para operar no modo assincrono com          *
;*            9600 bps,                                                 *
;*            1 stop bit,                                               *
;*            sem paridade;                                             *
;*       Inicializa o TIMER1 para operar no Modo 4 para gerar um        *
;          pedido de interrupção por segundo.                           *
;*       Habilita interrupções com "SEI";                               *
;*                                                                      *
;*       A parte principal do programa fica em loop imprimindo o TERM0  *
;*       a mensagem "Hello, World!".                                    *
;*                                                                      *
;*       Quando TIMER1 atinge o valor em OCR1A, o elemento              *
;*       de contagem TCNT1 é zerado, o nível emitido em OC1A (PB5)      * 
;        é comoutado, interrupçao por OCR1A match                       *
;*       é gerada, o Interrupt driver é acionado e:                     *
;*                                                                      *
;*            Incrementa o valor emitido no PORTH, no qual estão        *
;*              conectados displays de 7 segmentos;                     *
;*            Retorna da interrupção com "RETI".                        * 
;*                                                                      *
;* Created: 07/09/2021 18:33:28 by chiepa                               *
;* Modified: 10/09/2021 10:32:20 by dloubach                            *   
;************************************************************************

;***************
;* Constantes  *
;***************
; Constantes para configurar baud rate (2400:416, 9600:103, 57600:16, 115200:8).

   .equ  BAUD_RATE = 103
   .equ  RETURN = 0x0A          ; Retorno do cursor.
   .equ  LINEFEED = 0x0D        ; Descida do cursor.
   .equ  TIMER1_COMPA_vect = 0x0022  ; Vetor para atendimento a interrupções TIMRE1_COMPA match.
   .equ  CONST_OCR1A = 15625    ; Constante para o registrador OCR1A do TIMER1.
   
;*****************************
; Segmento de código (FLASH) *
;*****************************
   .cseg

; Ponto de entrada para RESET.
   .org  0 
   jmp   RESET

;*************************************************
;  PONTO DE ENTRADA DAS INTERRUPÇÕES DO TIMER1   *
;*************************************************
   .org  TIMER1_COMPA_vect
VETOR_TIMER1_COMPA:
   jmp   TIMER1_COMPA_INTERRUPT


   .org  0x100
RESET:
   ldi   r16, low(ramend)       ; Inicializa Stack Pointer.
   out   spl, r16               ; Para ATMega328 RAMEND=08ff.
   ldi   r16, high(ramend)
   out   sph, r16

   call  INIT_PORTS             ; Inicializa PORTH.
   call  USART0_INIT            ; Inicializa USART0.
   call  TIMER1_INIT_MODE4      ; Inicializa TIMER1.
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
;*                        INTERRUPT DRIVER DO do TIMER1_COMPA match                     *
;                                TIMER1_COMPA_INTERRUPT                                 * 
TIMER1_COMPA_INTERRUPT:
   push   r16
   lds    r16, sreg
   push   r16

; Esta interrupção foi disparada porque a TCNT1 atingiu o valor de OCR1A.
; TCNT1 é automaticamente zerado pelo TIMER e a contagem recomeça.
; Incrementa PORTH   e retorna.
   lds    r16, porth
   inc    r16
   sts    porth, r16
   
   pop    r16
   sts    sreg, r16
   pop    r16
   reti

;*                         FIM DO INTERRUPT DRIVER DO TIMER1                            *
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
   lds   r16, sreg
   push  r16
   push  r17
   push  zh
   push  zl

PRINT_USART0_REP:
   lpm   r16,z+
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
            
;***********************************
;  INIT_PORTS                      *
;  Inicializa PORTB como saída     *
;    em PB5 e entrada nos demais   *
;    terminais.                    *
;  Inicializa PORTH como saída     *
;    e emite 0x00 em ambos.        *
;***********************************
INIT_PORTS:
   ldi   r16, 0b00100000        ; Para emitir em PB5 a onda quadrada gerada pelo TIMER1.
   out   ddrb, r16
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
   ldi   r16, (1<<rxen0)|(1<<txen0)  ;Habilita receptor e transmissor.
   
   sts   ucsr0b, r16
   ldi   r16, (0<<usbs0)|(1<<ucsz01)|(1<<ucsz00)   ;Frame: 8 bits dado, 1 stop bit,
   sts   ucsr0c, r16            ;sem paridade.
   
   ret

;*************************************
;  USART0_TRANSMIT                   *
;  Subrotina para transmitir R16.    *
;*************************************
USART0_TRANSMIT:
   push  r17                    ;Salva R17 na pilha.

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
   push  r17						  ; Salva R17 na pilha.

WAIT_RECEIVE0:
   lds   r17,ucsr0a
   sbrs  r17,rxc0
   rjmp  WAIT_RECEIVE0          ;Aguarda chegada do dado.
   lds   r16,udr0               ;Le dado do BUFFER e retorna.

   pop   r17						  ; Restaura R17 e retorna.
   ret

;*********************************
; TIMER1_INIT_MODE4              *
; OCR1A =15625, PRESCALER/1024   *
;*********************************
TIMER1_INIT_MODE4:
; OCR1A = 15625
   ldi   r16, CONST_OCR1A>>8
   sts   ocr1ah, r16
   ldi   r16, CONST_OCR1A & 0xff		  ; ldi   r16, 15625 & 0xff
   sts   ocr1al, r16

; Modo 4, CTC: (WGM13, WGM12, WGM11, WGM10)=(0,1,0,0)
; Comutar OC1A para gerar onda quadrada: (COM1A1,COM1A0)=(0,1), (Tabela 3)
   ldi   r16, (0<<com1a1) | (1<<com1a0) | (0<<com1b1) | (0<<com1b0) | (0<<com1c1) | (0<<com1c0) | (0<<wgm11) | (0<<wgm10)
   sts   tccr1a, r16

; Modo 4, CTC: (WGM13, WGM12, WGM11, WGM10)=(0,1,0,0), (Tabela 2)
; Clock select: (CS12,CS11,CS10)=(1,0,1), PRESCALER/1024, (Tabela 1)
; No input capture: (ICNC1) | (0<<ICES1)
   ldi   r16,(0<<icnc1) | (0<<ices1) | (0<<wgm13) | (1<<wgm12) | (1<<cs12) |(0<<cs11) | (1<<cs10)
   sts   tccr1b, r16

; Timer/Counter 1 Interrupt(s) initialization
; Aqui, por exemplo, pede interrupcao sempre que contagem=OCR1A
   ldi   r16, (0<<icie1) | (0<<ocie1c) | (0<<ocie1b) | (1<<ocie1a) | (0<<toie1)
   sts   timsk1, r16

   ret

;*******************************************
; Strings e mensagens a serem impressas.   *
;    '$' é usado como terminador.          *
;*******************************************
MensHello:
   .db   "Timer interrrupt hello world!",RETURN,LINEFEED,'$'

;************************************
; Segmento de dados (RAM)           *
; Mostra como alocar espaço na RAM  *
; para variaveis.                   *
;   - NÃO USADAS NESTE PROGRAMA -   *
;************************************
.dseg
   .org  0x200
CARACTERE:
   .byte 1

;*****************************
; Finaliza o programa fonte  *
;*****************************
   .exit
