/*****************************************************************************************
******************************************************************************************
**                                                                                      **
**    TesteMultiplicadorSerialSoftControl.c                                             **
**                                                                                      **
**    Programa exemplo para ATMEGA2560 a 16 MHz com GCC e AVR Studio 5.                 **
**                                                                                      **
**    Verifica funcionamento do Multiplicador Serial 8x8                                **
**    o multiplicador calcula o produto (16 bits)                                       **
**    Testa todas as combinações possiveis de multiplicando e multiplicador de 8 bits   **
**                                                                                      **
**    PORTH <-- MULTIPLICANDO                                                           **
**    PORTJ <-- MULTIPLICADOR                                                           **
**    LOW(PRODUTO) <-- PINK                                                             **
**    HIGH(PRODUTO) <-- PINL                                                            **
**                                                                                      **
**    PORTG[0]: Sinal PSHIFTER# de clock para o shif register (borda de subida)         **
**    PORTG[1]: Sinal SHIFT/LOAD# para carregamento paralelo do shift register          **
**    PORTG[2]: Sinal PLOADREG# de clock para o acumulador (borda de subida)            **
**    PORTG[3]: Sinal CLEARREG# para o registrador PRODUTO                              **
**                                                                                      **
**                                                                                      **
******************************************************************************************
*****************************************************************************************/

#include <avr/io.h>
#include <stdio.h>

#define F_CPU 16000000UL
#include <util/delay.h>			// Aqui F_CPU é utilizada.

/*  Protótipos de funções  */
int USART1SendByte(char u8Data,FILE *stream);
int USART1ReceiveByte(FILE *stream);
void USART1Init(void);


void pshifter(void);
void ploadshifter(void);
void ploadreg(void);
void pclearreg(void);

/*  Stream para a USART1  */
FILE usart1_str = FDEV_SETUP_STREAM(USART1SendByte, USART1ReceiveByte, _FDEV_SETUP_RW);

/* Variaveis globais  */
int main(void)
{
	unsigned int multiplicando;
	unsigned int multiplicador;
	unsigned int produto;
	unsigned long contador;
	unsigned int i;
	
	DDRG=0xff;
	PORTG=0b00011111;
	DDRH=0xff;
	DDRJ=0xff;
	DDRK=0x00;
	DDRL=0x00;
	
	USART1Init();
	contador=1;

	fprintf(&usart1_str,"Teste do multiplicador 8x8.\n");
	fprintf(&usart1_str,"Controle totalmente por software.\n");
	fprintf(&usart1_str,"Iniciando o teste\n\n");

	while(1)
	{
		for(multiplicando=0x00;multiplicando < 0x100;multiplicando++)
		for(multiplicador=0x00;multiplicador < 0x100;multiplicador++)
		{
			PORTH=multiplicando; PORTJ=multiplicador;

			// Zera o registrador PRODUTO;
			pclearreg();

			// Carrega o SHIFT REGISTER com o multiplicador.
			ploadshifter();
			
			// Carrega o registrador PRODUTO com a parcela
			// correspondente ao bit mais significativo do MULTIPLICADOR.
			ploadreg();


			for(i=1;i<=7;i++)
			{
				// Disponibiliza próximo bit na saída do SHIFT REGISTER.
				pshifter();

				// Carrega o registrador PRODUTO com a soma da
				// parcela correspondente a esse bit ao conteúdo
				// do PRODUTO deslocado de um bit para a esquerda.
				ploadreg();
			}

			_delay_us(1);

			// Le o resultado do multiplicador;
			// Compara com produto efetuado por software;
			// Imprime resultado.
			// Emite erro se for diferente e para em loop.
			produto=PINK+(PINL<<8);
				fprintf(&usart1_str,"%d * %d = %d\n",multiplicando,multiplicador,produto);
			if(produto!=(unsigned long int)(multiplicando*multiplicador))
			{
				fprintf(&usart1_str,"Produto lido = %x\n",produto);
				fprintf(&usart1_str,"ERRO,parando: produto correto = %x\n",multiplicando * multiplicador);
				while(1);
			}
		}
		fprintf(&usart1_str,"Ciclo No %lu completo.\n",contador);
		contador++;
	}
}

/*********************************************
*  FUNÇÕES  PARA CONTROLE DO MULTIPLICADOR   *
*********************************************/

/*******************************************************************
* Pulso ativo baixo para carregamento paralelo do SHIFT REGISTER   *
*******************************************************************/
void ploadshifter(void)
{
	PORTG=PORTG & 0b11111101;
	_delay_us(1);
	PORTG=PORTG | 0b00000010;
}

/*****************************************************
* Pulso ativo baixo para o CLOCK do SHIFT REGISTER   *
*****************************************************/
void pshifter(void)
{
	PORTG=PORTG^0b00000001;
	_delay_us(1);
	PORTG=PORTG^0b00000001;
	_delay_us(1);
}

/******************************************************
* Pulso ativo baixo para comandar o carregamento      *
* das somas parciais e final no registrador PRODUTO   *
*                                                     *
******************************************************/
void ploadreg(void)
{
	PORTG=PORTG^0b00000100;
	_delay_us(1);
	PORTG=PORTG^0b00000100;
	//	  _delay_us(1);
}

/*********************************************************
* Pulso ativo baixo para zerar o registrador de PRODUTO  *
*********************************************************/
void pclearreg(void)
{
	PORTG=PORTG^0b00001000;
	_delay_us(1);
	PORTG=PORTG^0b00001000;
	//	  _delay_us(1);
}

/************************
*  FUNÇÕES  DA USART1   *
************************/
/**********************************************
*  Inicializacao da USART1:                   *
*	       8 bits, 1 stop bit, sem paridade   *
*		   Baud rate = 9600 bps               *
**********************************************/
void USART1Init(void)
{
	UCSR1A=(0<<RXC1) | (0<<TXC1) | (0<<UDRE1) | (0<<FE1) | (0<<DOR1) | (0<<UPE1) | (0<<U2X1) | (0<<MPCM1);
	UCSR1B=(0<<RXCIE1) | (0<<TXCIE1) | (0<<UDRIE1) | (0<<RXEN1) | (1<<TXEN1) | (0<<UCSZ12) | (0<<RXB80) | (0<<TXB81);
	UCSR1C=(0<<UMSEL11) |(0<<UMSEL10) | (0<<UPM11) | (0<<UPM10) | (0<<USBS1) | (1<<UCSZ11) | (1<<UCSZ10) | (0<<UCPOL1);
	UBRR1H=0x00;
	UBRR1L=103;
}

/*****************************************
*  Transmite um byte atraves da  USART1  *
*  Retorna sempre o valor zero           *
*****************************************/
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

/*************************************
*  Le o byte recebido pelaa  USART1  *
*  Retorna o byte lido               *
*************************************/
int USART1ReceiveByte(FILE *stream)
{
	uint8_t u8Data;
	// Espera recepcao de byte
	while(!(UCSR1A&(1<<RXC1)));
	u8Data=UDR1;
	// Retorna dado o recebido
	return u8Data;
}
