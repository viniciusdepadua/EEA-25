/*********************************************************
**********************************************************
**    AritmeticaPontoFlutuante.c                        **
**                                                      **
**    Programa para ATMega328 a 16 MHz                  **
**                                                      **
**    Exemplo de programa em C, para o AVR Studio       **
**    incluindo utiliza��o da USART e aritm�tica        **
**    em Ponto Flutuante (incluindo uso das fun��es     **
**    da da fam�lia "printf".                           **
**                                                      **
**    Imprime tabela de n�meros, quadrados e ra�zes     **
**    quadradas.                                        **
**                                          19/10/2020  **
**********************************************************
*********************************************************/
#define RAMEND 0x21ff
#define F_CPU 16000000    // Necess�rio para uso das fun��es "delay" por software.
#include <avr/io.h>

#include <string.h>
#include <math.h>
#include <util/delay.h>  // Aqui F_CPU � utilizada.
#include <stdio.h>

/* Function Prototypes  */
void tabela(void);
void mensagem(void);

// Streamed IO
int USART0SendByte(char u8Data,FILE *stream);
int USART0ReceiveByte(FILE *stream);
void USART0Init(void);
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

/*****************************************************
*  tabela                                            *
*    Imprime tabela de quadrados e raizes quadradas  *
*
*****************************************************/
void tabela(void)
{
	unsigned long int i;
	float x;
	fprintf(&usart0_str,"    Numero    Quadrado  Raiz quadrada\n\n");

	for(i=0;i<=10;i++)
	{
		x=sqrt(i);
		fprintf(&usart0_str,"%10lu  %10lu  %10.6f\n",i,i*i,x);
	}
	fprintf(&usart0_str,"\n");
}

/******************************
*******************************
**  Fun��es  para a USART0   **
*******************************
******************************/

void USART0Init(void)
{
	// Inicializa��o USART0 com:
	// Modo Ass�ncrono, 9600 bit/s, palavras de 8 bits, sem paridade, um stop bit,
	// Transmissor e receptor ligados, sem interrup��es.
	UCSR0A=(0<<RXC0) | (0<<TXC0) | (0<<UDRE0) | (0<<FE0) | (0<<DOR0) | (0<<UPE0) | (0<<U2X0) | (0<<MPCM0);
	UCSR0B=(0<<RXCIE0) | (0<<TXCIE0) | (0<<UDRIE0) | (1<<RXEN0) | (1<<TXEN0) | (0<<UCSZ02) | (0<<RXB80) | (0<<TXB80);
	UCSR0C=(0<<UMSEL01) |(0<<UMSEL00) | (0<<UPM01) | (0<<UPM00) | (1<<USBS0) | (1<<UCSZ01) | (1<<UCSZ00) | (0<<UCPOL0);
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