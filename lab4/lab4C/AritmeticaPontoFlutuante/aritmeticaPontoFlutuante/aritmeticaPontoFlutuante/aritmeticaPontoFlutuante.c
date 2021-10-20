/*
 * aritmeticaPontoFlutuante.c
 *
 * Created: 10/20/2021 4:32:29 PM
 *  Author: vinic
 */ 


/**************************************************************
***************************************************************
**    AritmeticaPontoFlutuante.c                             **
**                                                           **
**    Programa para ATMega2560 a 16 MHz                      **
**                                                           **
**    Exemplo de programa em C, para o AVR Studio            **
**    incluindo utilização da USART e aritmética             **
**    em Ponto Flutuante (incluindo uso das funções          **
**    da da família "printf").                               **
**                                                           **
**    Imprime tabela de números, quadrados,  raízes          **
**    quadradas e senos de 5 em 5 segundos aproximadamente.  **
**                                                           **
**    Invoca a funcao _delay_ms() para marcar 5 segundos     **
**    entre o termino de uma impressao da                    **
**                                                           **
**    tabela e o inicio da proxima impressao.                **
**                                          19/10/2020       **
***************************************************************
**************************************************************/
#define F_CPU 16000000    // Necessário para uso das funções "delay" por software.
#include <avr/io.h>

#include <string.h>
#include <math.h>
#include <util/delay.h>  // Aqui F_CPU é utilizada.
#include <stdio.h>

// Prototipos para as funcoes do programa.
void tabela(void);
int USART0SendByte(char u8Data,FILE *stream);
int USART0ReceiveByte(FILE *stream);
void USART0Init(void);

// Declaracao de variavel do tipo FILE para IO atraves da USART0.
FILE usart0_str = FDEV_SETUP_STREAM(USART0SendByte, USART0ReceiveByte, _FDEV_SETUP_RW);

int main(void)
{
	USART0Init();
	while(1)
	{
		tabela();
		_delay_ms(5000);
	}
}

/***********************************************************
*  tabela                                                  *
*    Imprime tabela de quadrados senos e raizes quadradas  *
*                                                          *
***********************************************************/
void tabela(void)
{
	unsigned long int i;
	float x;
	fprintf(&usart0_str,"    Numero    Quadrado  Seno  Raiz quadrada\n\n");

	for(i=0;i<=30;i++)
	{
		x=sqrt(i);
		fprintf(&usart0_str,"%10lu  %10lu  %10.6f   %10.6f\n",i,i*i,x,sin(3.1415926536*i/180));
	}
	fprintf(&usart0_str,"\n");
}

/******************************
*******************************
**  Funções  para a USART0   **
*******************************
******************************/

void USART0Init(void)
{
	// Inicialização USART0 para operacao a 57600bps, palavras de 8 bits,
	// sem paridade, um stop bit, com transmissor e receptor ligados,
	// sem interrupcoes.
	UCSR0A=(0<<RXC0) | (0<<TXC0) | (0<<UDRE0) | (0<<FE0) | (0<<DOR0) | (0<<UPE0) | (0<<U2X0) | (0<<MPCM0);
	UCSR0B=(0<<RXCIE0) | (0<<TXCIE0) | (0<<UDRIE0) | (1<<RXEN0) | (1<<TXEN0) | (0<<UCSZ02) | (0<<RXB80) | (0<<TXB80);
	UCSR0C=(0<<UMSEL01) |(0<<UMSEL00) | (0<<UPM01) | (0<<UPM00) | (1<<USBS0) | (1<<UCSZ01) | (1<<UCSZ00) | (0<<UCPOL0);
	UBRR0H=0x00;
	UBRR0L=16;   // UBBR0=16 para 57200 bps, UBBR0=103 para 9600bps
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
	while(!(UCSR0A&(1<<RXC0)));
	u8Data=UDR0;
	//echo input data
	//USART0SendByte(u8Data,stream);
	// Return received data
	return u8Data;
}