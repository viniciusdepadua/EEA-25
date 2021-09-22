;**************************************************************************************
;    jigsaw.asm                                                                      **
;                                                                                    **
;    Demonstra o uso das interrupções externas INTn em um ATMega2560.                **
;                                                                                    **
;    Os pedidos de interrupção são produzidos por umde pulsos conectado              **
;    ao terminal INT7.                                                               **
;                                                                                    **
;    Cada transição de nível alto para nível baixo no terminal INT7 determina um     **
;    pedido de  interrupção e o interrupt driver emite uma amostra de onda           **
;    triangular no PORTK, ao qual está conectado um conversor digital-analógico      **
;    DAC0808 para produzir a onda.                                                   **
;                                                                                    **
;    O programa inicializa o sistema e entra em um loop no qual:                     **
;        - De 100 em 100 milissegundos imprime a mensagem                            **
;                 "Gerando onda dente de serra.".                                    **
;                                                                                    **
;    O interrupt driver de INT7 emite uma amostras da onda triangular                **
;    (simplesmente incrementa PORTK).                                                **
;                                                                                    **
;                                                  Created: 08/10/2020 14:36:23      **
;                                                                                    **
;**************************************************************************************

;***************
;* Constantes  *
;***************
; Constantes para configurar baud rate (2400:416, 9600:103, 57600:16, 115200:8).
   .EQU  BAUD_RATE = 103  
   .EQU  CONST_ATRASO = 4732   ; Constante para atraso de 25ms em DELAY
   .EQU  INT_I7_vect = 0x0010
   .EQU  RETURN = 0x0A
   .EQU  LINEFEED = 0x0D

;*****************************
; Segmento de código (FLASH) *
;*****************************
   .CSEG
   .ORG   0 
;*******************************
; Ponto de entrada para reset  *
; driver de INT7.              *
;*******************************         
RESET:
   JMP   PARTIDA

   .ORG  INT_I7_vect
;*************************************
; Ponto de entrada para o interrupt  *
; driver de INT7.                    *
;*************************************         
INT7_ENTRADA:
   JMP   INT7_DRIVER

   .ORG  0x100
PARTIDA:
   LDI   R16, LOW(RAMEND)       ; Inicializa Stack Pointer
   OUT   SPL, R16
   LDI   R16, HIGH(RAMEND)
   OUT   SPH, R16

   CALL  USART_INIT             ; Inicializa USART
   CALL  INIT_PORTS             ; Inicializa PORTB e PORTL como saídas
   CALL  INIT_INTS              ; Inicializa interrupções INT7
   SEI                          ; Habilita interrupções

PARA_SEMPRE:
   LDI   ZH, HIGH(2*MENSAGEM)   ; Imprime mensagem
   LDI   ZL, LOW(2*MENSAGEM)
   CALL   ENVIAR

   LDI   R16, 20
REP_DELAY:
   CALL  DELAY
   DEC   R16
   BRNE  REP_DELAY
   JMP   PARA_SEMPRE   


;******************************************
; Interrupt driver para INT7              *
; Importante observar:                    *
;   - O interrupt driver deve             *
;     preservar todos os registradores;   *
;   - Reabilitar interrupções antes       *
;     de retornar.                        *
;******************************************
INT7_DRIVER:
   PUSH  R16
   LDS   R16, SREG
   PUSH  R16

   LDS   R16, PORTK
   INC   R16
   STS   PORTK, R16

   POP   R16
   STS   SREG,R16
   POP   R16
   RETI

;**********************************
;  ENVIAR                         *
;  Envia mensagem apontada por Z  *
;  na memoria FLASH               *
;  Subrotina                      *
;**********************************
ENVIAR:
   PUSH   R16

ENVIAR_REP:
   LPM   R16,Z+
   CPI   R16,'$'
   BREQ  FIM_ENVIAR
   CALL  USART_Transmit
   JMP   ENVIAR_REP
FIM_ENVIAR:
   POP   R16
   RET
            
;*************************************************************
;  DELAY                                                     *
;  Subrotina para atraso de                                  *
;  aproximadamente 50 ms (50 milisegundos).                  *
;  Simplesmente inicializa a variável ATRASO, de 16 bits     *
;  com a constante CONST_ATRASO e a decrementa até zero.     *
;                                                            *
;  Notar que o numero de 16 bits é armazenado em uma cadeia  *
;  de dois bytes a partir do endereço ATRASO, na ordem       *
;  (Byte Menos Significativo,Byte Mais Significativo).       *
;  Observar como decrementar um número de 16 bits (2 bytes). *
;*************************************************************
DELAY:
   PUSH  R16
   PUSH  R17

   LDI   XH, HIGH(ATRASO)
   LDI   XL, LOW(ATRASO)
   LDI   R16, LOW(CONST_ATRASO)
   ST    X+, R16
   LDI   R16, HIGH(CONST_ATRASO)
   ST    X, R16

LOOP_DELAY:
   LDI   XH,HIGH(ATRASO)
   LDI   XL,LOW(ATRASO)
         
   LD    R16,X
   SUBI  R16,1
   ST    X+,R16
   LD    R16,X
   SBCI  R16,0
   ST    X,R16
   OR    R16,R17
   BREQ  FIM_DELAY
   JMP   LOOP_DELAY

FIM_DELAY:
   POP   R17
   POP   R16
   RET

;***************
;  USART_INIT  *
;  Subrotina   *
;***************
; Inicializa USART: modo assincrono, 9600 bps, 1 stop bit, sem paridade.  
; Os registradores são:
;     - UBRR0 (USART0 Baud Rate Register)
;     - UCSR0 (USART0 Control Status Register B)
;     - UCSR0 (USART0 Control Status Register C)
USART_INIT:
   LDI   R17, HIGH(BAUD_RATE)         ;Estabelece Baud Rate.
   STS   UBRR0H, R17
   LDI   R16, LOW(BAUD_RATE)
   STS   UBRR0L, R16
   LDI   R16, (1<<RXEN0)|(1<<TXEN0)   ;Habilita receptor e transmissor.

   STS   UCSR0B, R16
   LDI   R16, (0<<USBS0)|(3<<UCSZ00)  ;Frame: 8 bits dado, 1 stop bit,
   STS   UCSR0C, R16                  ;sem paridade.

   RET

;*******************
;  USART_TRANSMIT  *
;  Transmite R16   *
;  Subrotina       *
;*******************
USART_TRANSMIT:
;Salva R17 na pilha.
   PUSH   R17

WAIT_TRANSMIT:
   LDS   R17, UCSR0A
   SBRS  R17, UDRE0            ;Aguarda BUFFER do transmissor ficar vazio.      
   RJMP  WAIT_TRANSMIT
   STS   UDR0, R16             ;Escreve dado no BUFFER.

; Restaura R17 e retorna.
   POP   R17
   RET

;*****************************
;  USART_RECEIVE             *
;  Subrotina                 *
;  Coloca em R16 o caracter  *
;  recebido pela USART.      *
;*****************************
USART_RECEIVE:
;Salva R17 na pilha.
   PUSH  R17

WAIT_RECEIVE:
   LDS   R17, UCSR0A
   SBRS  R17, RXC0
   RJMP  WAIT_RECEIVE           ;Aguarda chegada do dado.
   LDS   R16, UDR0              ;Le dado do BUFFER e retorna.

; Restaura R17 e retorna.
   POP   R17
   RET

;*********************************************
;  INIT_PORTS:                               *
;     Inicializa PORTB e PORTL como saídas.  *  
;*********************************************
INIT_PORTS:
   LDI   R16, 0b11111111
   STS   DDRK, R16
   RET

;****************************************
;  Registradores das interrupções INTn  *
;*************************************************************************************
;  EICRB  External Interrupt Control Register B                                  *
;   EICRB (ISC71 ISC70 ISC61 ISC60 ISC51 ISC50 ISC41 ISC40)                          *
;   ISCn1 ISCn0 Description                                                          *
;   0 0 The low level of INTn generates an interrupt request                         *
;   0 1 Any logical change on INTn generates an interrupt request                    *
;   1 0 The falling edge between two samples of INTn generates an interrupt request  *
;   1 1 The rising edge between two samples of INTn generates an interrupt request   *
;                                                                                    *
;   EIMSK External Interrupt Mask Register                                      *
;   INT7 INT6 INT5 INT4 INT3 INT2 INT1 INT0                                          *
;                                                                                    *
;   EIFR External Interrupt Flag Register                                       *
;   INTF7 INTF6 INTF5 INTF4 INTF3 INTF2 INTF1 IINTF0                                 *
;*************************************************************************************
/*********************************************
* Inicialização dos registradores para INTn  *
*********************************************/
INIT_INTS:
   LDI   R16, 0b10000000      ; Sensível a borda de descida
   STS   EICRB, R16
   LDI   R16, 0b10000000      ; INT7 habilitada
   OUT   EIMSK, R16
   RET

MENSAGEM:
   .DB   "Gerando onda jigsaw",RETURN,LINEFEED,'$'

;**************************
; Segmento de dados (RAM) *
;**************************
   .DSEG
   .ORG   0x200

;***********************************
; Espaço alocado para variável     *
; de 16 bits, um número natural    *
; representado por uma cadeia de   *
; dois bytes.                      *
;***********************************
ATRASO:
   .BYTE	2

   .EXIT
