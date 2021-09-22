/*
 * AssemblerApplication1.asm
 *
 *  Created: 9/22/2021 2:16:49 PM
 *   Author: vinic
 */ 


;*************************************************************************************
;*************************************************************************************
;   int7.asm                                                                        **
;                                                                                   **
;   Demonstra o uso das interrupções externas INTn em um ATMega2560 a 16 MHz.       **
;                                                                                   **
;   Os pedidos de interrupção são produzidos por uma chave pushbutton               **
;   conectada ao terminal INT7. Cada vez que a chave é acionada uma transição de    **
;   nível alto para nível baixo é aplicada a INT7, determinando um pedido de        **
;   interrupção.                                                                    **
;                                                                                   **
;   Após inicializar a USART), o sistema de interrupções, os PORTs B, D e L,        **
;   o sistema fica em loop:                                                         **
;       - De um em um segundo imprime "Hello, world!\n";                            **
;       - Incrementa o valor emitido no PORTB.                                      **
;                                                                                   **
;   O interrupt driver de INT7 incrementa o valor emitido no PORTL.                 **
;                                                                                   **
;   created by chiepa                                                               **
;*************************************************************************************
;*************************************************************************************

;***************
;* Constantes  *
;***************
; Constantes para configurar baud rate (2400:416, 9600:103, 57600:16, 115200:8).

   .EQU  BAUD_RATE = 103  		  
   .EQU  CONST_ATRASO = 47320   ; Constante para atraso de 50ms em DELAY.
   .EQU  RETURN = 0x0A          ; Retorno do cursor.
   .EQU  LINEFEED = 0x0D        ; Descida do cursor.
   .EQU  INT_I7_vect = 0x0010   ; Vetor de interrupção INT7.

;*****************************
; Segmento de código (FLASH) *
;*****************************
   .CSEG
   .ORG   0 

;*******************************
; Ponto de entrada para reset  *
;*******************************         
RESET:
   JMP	PARTIDA

   .ORG  INT_I7_vect
;*************************************
; Ponto de entrada para o interrupt  *
; driver de INT7.                    *
;*************************************         
INT7_ENTRADA:
   JMP   INT7_DRIVER

   .ORG  0x100
PARTIDA:
   LDI   R16, LOW(RAMEND)       ; Inicializa Stack Pointer.
   OUT   SPL, R16
   LDI   R16, HIGH(RAMEND)        
   OUT   SPH, R16

   CALL  USART0_INIT            ; Inicializa USART.
   CALL  INIT_PORTS             ; Inicializa PORTB e PORTL como saídas.
   CALL  INIT_INTS              ; Inicializa interrupções INT7.
   SEI                          ; Habilita interrupções.

PARA_SEMPRE:
   LDI   ZH, HIGH(2*MENSAGEM)   ; Imprime mensagem.
   LDI   ZL, LOW(2*MENSAGEM)
   CALL  ENVIAR

   IN    R16,PORTB
   INC   R16
   OUT   PORTB,R16

   LDI   R16,20
REP_DELAY:
   CALL  DELAY
   DEC   R16
   BRNE  REP_DELAY
   JMP   PARA_SEMPRE   

;******************************************
; Interrupt driver para INT7              *
;    incrementa POTL a cada ativação.     *
; Importante observar:                    *
;   - Um interrupt driver deve            *
;     preservar todos os registradores;   *
;   - Interrupções são reabilitadas       *
;     automaticamente com RETI após a     *
;     execução da instrução no endereço   *
;     de retorno.                         *
;******************************************
INT7_DRIVER:
   PUSH  R16
   LDS   R16, SREG
   PUSH  R16

   LDS   R16, PORTL
   INC   R16
   STS   PORTL, R16

   POP   R16
   STS   SREG, R16
   POP   R16
   RETI

;***********************************
;  ENVIAR                          *
;  Subrotina para enviar através   *
;  da USART0 a mensagem apontada   *
;  por Z na memória FLASH.         *
;***********************************
ENVIAR:
   PUSH  R16
   LDS   R16,SREG
   PUSH  R16
         
ENVIAR_REP:
   LPM   R16,Z+
   CPI   R16,'$'
   BREQ  FIM_ENVIAR
   CALL  USART0_Transmit
   JMP   ENVIAR_REP
FIM_ENVIAR:
   POP   R16
   STS   SREG, R16
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
   LDS   R16, SREG
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
   STS   SREG,R16
   POP   R16
   RET

;***************
;  USART0_INIT *
;  Subrotina   *
;***************
; Inicializa USART: modo assincrono, 9600 bps, 1 stop bit, sem paridade.  
; Os registradores são:
;     - UBRR0 (USART0 Baud Rate Register)
;     - UCSR0 (USART0 Control Status Register B)
;     - UCSR0 (USART0 Control Status Register C)
USART0_INIT:
   LDI   R17, HIGH(BAUD_RATE)         ;Estabelece Baud Rate.
   STS   UBRR0H, R17
   LDI   R16, LOW(BAUD_RATE)
   STS   UBRR0L, R16
   LDI   R16, (1<<RXEN0)|(1<<TXEN0)   ;Habilita receptor e transmissor.

   STS   UCSR0B,R16
   LDI   R16, (0<<USBS0)|(3<<UCSZ00)  ;Frame: 8 bits dado, 1 stop bit,
   STS   UCSR0C, R16                  ;sem paridade.

   RET

;*******************
;  USART0_TRANSMIT *
;  Subrotina       *
;  Transmite R16.  *
;*******************
USART0_TRANSMIT:
;Salva R17 na pilha.
   PUSH  R17

WAIT_TRANSMIT:
   LDS   R17, UCSR0A             
   SBRS  R17, UDRE0            ;Aguarda BUFFER do transmissor ficar vazio.      
   RJMP  WAIT_TRANSMIT
   STS   UDR0, R16             ;Escreve dado no BUFFER.

; Restaura R17 e retorna.
   POP   R17
   RET

;*****************************
;  USART0_RECEIVE            *
;  Subrotina                 *
;  Coloca em R16 o caracter  *
;  recebido pela USART.      *
;*****************************
USART0_RECEIVE:
;Salva R17 na pilha.
   PUSH  R17

WAIT_RECEIVE:
   LDS   R17,UCSR0A             
   SBRS  R17,RXC0
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
   OUT   DDRB, R16
   STS   DDRL, R16
   RET

;****************************************
;  Registradores das interrupções INTn  *
;*************************************************************************************
;  EICRB – External Interrupt Control Register B                                     *
;   EICRB (ISC71 ISC70 ISC61 ISC60 ISC51 ISC50 ISC41 ISC40)                          *
;   ISCn1 ISCn0 Description                                                          *
;   0 0 The low level of INTn generates an interrupt request                         *
;   0 1 Any logical change on INTn generates an interrupt request                    *
;   1 0 The falling edge between two samples of INTn generates an interrupt request  *
;   1 1 The rising edge between two samples of INTn generates an interrupt request   *
;                                                                                    *
;   EIMSK – External Interrupt Mask Register                                         *
;   INT7 INT6 INT5 INT4 INT3 INT2 INT1 INT0                                          *
;                                                                                    *
;   EIFR – External Interrupt Flag Register                                          *
;   INTF7 INTF6 INTF5 INTF4 INTF3 INTF2 INTF1 IINTF0                                 *
;*************************************************************************************
/*********************************************
* Inicialização dos registradores para INTn  *
*********************************************/
INIT_INTS:
   LDI   R16, 0b01000000      ; Sensível a borda de descida
   STS   EICRB, R16
   LDI   R16, 0b10000000      ; INT7 habilitada
   OUT   EIMSK, R16
   RET

MENSAGEM:
   .DB   "Hello, world!",RETURN,LINEFEED,'$'

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




#define RAMEND 0x21ff
#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <stdio.h>

//  Protótipo da função para inicialização do PORTB, PORTF e PORTL
void initPORTS(void);

//  Protótipo da função para inicialização dos registradores para INTnL
void interruptsInit(void);

/*  Protótipos de funções para acessar interfaces por "streamed IO"  */
int USART0SendByte(char u8Data,FILE *stream);
int USART0ReceiveByte(FILE *stream);
void USART0Init(void);

/*  Stream para a USART0  */
FILE usart0_str = FDEV_SETUP_STREAM(USART0SendByte, USART0ReceiveByte, _FDEV_SETUP_RW);

/******************************
*******************************
**        função main        **
*******************************
******************************/
int main(void)
{
   initPORTS();
   USART0Init();
   interruptsInit();
   sei();
   while(1)
   {
      fprintf(&usart0_str,"Hello world!\n");
      PORTB++;
      _delay_ms(1000);
   }     
}

void initPORTS(void)
{
   DDRF = 0b11111111;
   PORTF = 0b00000000;
   DDRL = 0b11111111;
   PORTL = 0b00000000;
   DDRB = 0b11111111;
   PORTB = 0b00000000;
}

/****************************************
*  Registradores das interrupções INTn  *
***************************************************************************************
/*  EICRB – External Interrupt Control Register B                                     *
**   EICRB (ISC71 ISC70 ISC61 ISC60 ISC51 ISC50 ISC41 ISC40)                          *
**   ISCn1 ISCn0 Description                                                          *
**   0 0 The low level of INTn generates an interrupt request                         *
**   0 1 Any logical change on INTn generates an interrupt request                    *
**   1 0 The falling edge between two samples of INTn generates an interrupt request  *
**   1 1 The rising edge between two samples of INTn generates an interrupt request   *
**                                                                                    *
**   EIMSK – External Interrupt Mask Register                                         *
**   INT7 INT6 INT5 INT4 INT3 INT2 INT1 INT0                                          *
**                                                                                    *
**   EIFR – External Interrupt Flag Register                                          *
**   INTF7 INTF6 INTF5 INTF4 INTF3 INTF2 INTF1 IINTF0                                 *
**************************************************************************************/
/*********************************************
* Inicialização dos registradores para INTn  *
*********************************************/
void interruptsInit(void)
{
   EICRB = 0b10000000; // Sensível a borda de descida
   EIMSK = 0b10000000; // INT7 habilitada
}

/*****************************************************
*  Interrupt driver para interrupções externas INT7  *
*****************************************************/
ISR(INT7_vect)
{
   PORTF = PORTF^0b00001000;
   PORTL++;
}

/***********************
*  FUNÇÕES  DA USART0  *
***********************/
void USART0Init(void)
{
   /********************************************************************
   Inicialização da USART0 com modo assíncrono, 8 bits, 1 stop bit,
   sem paridade,9600 bps,receptor e transmissor ativados.
   ********************************************************************/
   UCSR0A=(0<<RXC0) | (0<<TXC0) | (0<<UDRE0) | (0<<FE0) | (0<<DOR0) | (0<<UPE0) | (0<<U2X0) | (0<<MPCM0);
   UCSR0B=(0<<RXCIE0) | (0<<TXCIE0) | (0<<UDRIE0) | (1<<RXEN0) | (1<<TXEN0) | (0<<UCSZ02) | (0<<RXB80) | (0<<TXB80);
   UCSR0C=(0<<UMSEL01) |(0<<UMSEL00) | (0<<UPM01) | (0<<UPM00) | (0<<USBS0) | (1<<UCSZ01) | (1<<UCSZ00) | (0<<UCPOL0);
   UBRR0H=0x00;
   UBRR0L=103;
}

int USART0SendByte(char u8Data,FILE *stream)
{
   if(u8Data == '\n')
   {
      USART0SendByte('\r',stream);
   }
   //wait while previous byte is completed
   while(!(UCSR0A&(1<<UDRE0))){};
   // Transmit data
   UDR0 = u8Data;
   return 0;
}

int USART0ReceiveByte(FILE *stream)
{
   uint8_t u8Data;
   // Wait for byte to be received
   while(!(UCSR0A&(1<<RXC0))){};
   u8Data=UDR0;
   //echo input data
   //USART0SendByte(u8Data,stream);
   // Return received data
   return u8Data;
}