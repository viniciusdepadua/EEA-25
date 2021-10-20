/*****************************************************************************************
******************************************************************************************
**                                                                                      **
**    Projeto TesteMultiplicadorCombinacional                                           **
**    Programa exemplo para ATMEGA2560 a 16 MHz com GCC e AVR Studio 5.                 **
**                                                                                      **
**    Verifica funcionamento do Multiplicador Combinacional de  8 bits.                 **
**                                                                                      **
**    Testa todas as combinações possiveis de multiplicando e multiplicador de 8 bits.  **
**                                                                                      **
**    PORTH <-- MULTIPLICANDO                                                           **
**    PORTJ <-- MULTIPLICADOR                                                           **
**    LOW(PRODUTO) <-- PINK                                                             **
**    HIGH(PRODUTO) <-- PINL                                                            **
**                                                                                      **
**                                                                                      **
**                                                                                      **
******************************************************************************************
*****************************************************************************************/

#include <avr/io.h>
#include <stdio.h>
#include <avr/interrupt.h>

#define F_CPU 16000000UL
#include <util/delay.h>			// Aqui F_CPU é utilizada.

/*  Protótipos de funções  */
int USART1SendByte(char u8Data,FILE *stream);
int USART1ReceiveByte(FILE *stream);
void USART1Init(void);

/*  Stream para a USART1  */
FILE usart1_str = FDEV_SETUP_STREAM(USART1SendByte, USART1ReceiveByte, _FDEV_SETUP_RW);
 
/* Variaveis globais  */
int main(void)
  {
    unsigned int multiplicando;
	unsigned int multiplicador;
	unsigned int produto;
    unsigned long contador;
		
    DDRG=0xff;
	PORTG=0b00011111;
    DDRH=0xff;
    DDRJ=0xff;
    DDRK=0x00;
    DDRL=0x00;
	
	USART1Init();
    contador=1;

    fprintf(&usart1_str,"Teste do multiplicador combinacional de 8 bits.\n");
    fprintf(&usart1_str,"Iniciando o teste.\n\n");

    while(1)
    {
       for(multiplicando=0;multiplicando<=0xff;multiplicando++)
	       {
	         for(multiplicador=0x00;multiplicador <= 0xff;multiplicador++)      
	            {
	                PORTH=multiplicando; PORTJ=multiplicador;
					_delay_us(1);
					produto=(unsigned int)PINK+(unsigned int)(PINL<<8);
		            fprintf(&usart1_str,"%x * %x = %x\n",multiplicando,multiplicador,produto);
					if(produto!=multiplicando*multiplicador)
						fprintf(&usart1_str,"Erro: produto correto = %x\n",multiplicando*multiplicador);
				}
			}
		if((contador%1000)==0)fprintf(&usart1_str,"Ciclo No %lu \n",contador);
		contador++;
	}
  }

/************************
*  FUNÇÕES  DA USART1   *
************************/
void USART1Init(void)
{
    /* Inicializacao da USART1:
	       8 bits, 1 stop bit, sem paridade
		   Baud rate = 9600 bps
		   Interrupcoes por recepcao de caractere
	*/
	
	UCSR1A=(0<<RXC1) | (0<<TXC1) | (0<<UDRE1) | (0<<FE1) | (0<<DOR1) | (0<<UPE1) | (0<<U2X1) | (0<<MPCM1);
    UCSR1B=(0<<RXCIE1) | (0<<TXCIE1) | (0<<UDRIE1) | (1<<RXEN1) | (1<<TXEN1) | (0<<UCSZ12) | (0<<RXB80) | (0<<TXB81);
    UCSR1C=(0<<UMSEL11) |(0<<UMSEL10) | (0<<UPM11) | (0<<UPM10) | (0<<USBS1) | (1<<UCSZ11) | (1<<UCSZ10) | (0<<UCPOL1);
    UBRR1H=0x00;
    UBRR1L=103;
}

int USART1SendByte(char u8Data,FILE *stream)
{
   if(u8Data == '\n')
      {
         USART1SendByte('\r',stream);
      }
  // Espera byte anterior ser completado
  while(!(UCSR1A&(1<<UDRE1))){};
  // Transmite o dado
  UDR1 = u8Data;
  return 0;
}

int USART1ReceiveByte(FILE *stream)
{
uint8_t u8Data;
   // Espera recepcao de byte
   while(!(UCSR1A&(1<<RXC1)));
   u8Data=UDR1;
   // Retorna dado o recebido
   return u8Data;
}                             

