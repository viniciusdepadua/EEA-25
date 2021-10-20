/***********************************************************************************
************************************************************************************
**                                                                                **
**       hanoi.c                                                                  **
**       Programa exemplo para ATMEGA328 a 16 MHz com                             **
**       GCC
**                                                                                **
**       Demonstra utilização das USARTs com streamed IO.                         **
**       Resolve o problema Torre de Hanoi, interagindo com o usuário através     **
**       da USART0.                                                               **
**                                                                                **
**       USART0 a 9600 baud, com 8 bits, sem paridade e 1 stop bit.               **
**                                                                                **
**                                               Created: 14/09/2021              **
**                                               Author: Chiepa - ITA             **
**                                                                                **
** modified in 20210920 by dloubach                                               **
************************************************************************************
***********************************************************************************/

#include <avr/io.h>
#include <stdio.h>

/*  Protótipos de funções para acessar interfaces por "streamed IO"  */
int USART0SendByte(char u8Data, FILE *stream);
int USART0ReceiveByte(FILE *stream);
void USART0Init(void);
void hanoi(unsigned int ndiscos, unsigned int origem, unsigned int destino);

/*  Stream para a USART0  */
FILE usart0_str = FDEV_SETUP_STREAM(USART0SendByte, USART0ReceiveByte, _FDEV_SETUP_RW);

int main(void)
{
	unsigned int ndiscos,origem,destino;
	USART0Init();
	
	while(1)
	{
		fprintf(&usart0_str,"Digite: ndiscos (1 a 10),origem (0 a 2),destino(0 a 2)\n");
		fscanf(&usart0_str,"%u,%u,%u",&ndiscos,&origem,&destino);

		if(ndiscos<=10 && origem<=2 && destino<=2 && origem!=destino)
		{
			fprintf(&usart0_str,"\nAqui vai a solucao:\n\n");
			hanoi(ndiscos,origem,destino);
			fprintf(&usart0_str,"\n");
		}
		else
		fprintf(&usart0_str,"Parametros invalidos\n");
	}
}

/********************************************
*  FUNÇÃO  PARA RESOLVER "TORRE DE HANOI"   *
********************************************/
void hanoi(unsigned int ndiscos, unsigned int origem, unsigned int destino)
{
	unsigned int intermediario;
	if(ndiscos==1) fprintf(&usart0_str,"%2u --> %2u\n",origem,destino);
	else
	{
		ndiscos--;
		intermediario=3-(origem+destino);
		hanoi(ndiscos, origem, intermediario);
		fprintf(&usart0_str,"%2u --> %2u\n",origem,destino);
		hanoi(ndiscos, intermediario, destino);
	}
}

/************************
*  FUNÇÕES  DA USART0   *
************************/
void USART0Init(void)
{
	// Inicialização da USART0 com: assíncrona, 9600 bps, 8 bits,1 stop bit , sem paridade.
	// Deixa transmissor e receptor ativados.
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

	//Espera até que a transmissão do byte anterior seja completada.
	while(!(UCSR0A&(1<<UDRE0)));

	// Deposita o byte para transmissão.
	UDR0 = u8Data;
	return 0;
}

int USART0ReceiveByte(FILE *stream)
{
	uint8_t u8Data;
	// Aguarda chegada de byte
	while(!(UCSR0A&(1<<RXC0)));

	// Lê o byte
	u8Data=UDR0;
	
	// Ecoa o byte recebido
	USART0SendByte(u8Data,stream);

	// Retorna com o byte recebido
	return u8Data;
}