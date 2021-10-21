/*
 * lab7.c
 *
 * Created: 10/20/2021 5:37:55 PM
 *  Author: vinic
 */ 


#include <avr/io.h>
#include <stdio.h>
#include <avr/interrupt.h>
#include <stdbool.h>

#include "commit.h"
#include "constants.h"

#define F_CPU 16000000UL
#include <util/delay.h>			// Aqui F_CPU é utilizada.


/*  Protótipos de funções  */
void Timer1Init(void);

int USART0SendByte(char u8Data, FILE *stream);
int USART0ReceiveByte(FILE *stream);
void USART0Init(void);

int USART1SendByte(char u8Data, FILE *stream);
int USART1ReceiveByte(FILE *stream);
void USART1Init(void);

/*  Stream para a USART1  */
FILE usart0_str = FDEV_SETUP_STREAM(USART0SendByte, USART0ReceiveByte, _FDEV_SETUP_RW);
FILE usart1_str = FDEV_SETUP_STREAM(USART1SendByte, USART1ReceiveByte, _FDEV_SETUP_RW);

bool master;
int PWM;

/* Variaveis globais  */
int main(void)
{
	DDRB = 0xff;
	DDRF = 0xff;
	DDRH = 0xff;		
	DDRL = 0x00;
	
	master = (PINL >> PINL7 == 1);
	
	char comando1,comando2,comando3,comando4,comando5;
	
	sei();
	
	USART0Init(); 
	USART1Init();
	
	Timer1Init();
	
	fprintf(&usart0_str, LAST_COMMIT);
	
	if(master)
	{
		fprintf(&usart0_str, "***MASTER***\n");
		fprintf(&usart0_str,"\nDigite um comando valido para o slave:\n");
		PORTF = 1;
		while(true)
		{
			fscanf(&usart0_str, "%c%c%c%c%c", &comando1, &comando2, &comando3, &comando4, &comando5);
			fprintf(&usart1_str, "%c%c%c%c%c", comando1, comando2, comando3, comando4, comando5);
		}
	}
	
	else
	{
		fprintf(&usart0_str, "***SLAVE***\n");
		while(true)
		{
			
		}
	}
	
}

/**********************
*  INTERRUPT DRIVERS  *
**********************/

/***********************************************
*  Interrupt driver para o Receptor da USART1  *
***********************************************/
ISR(USART1_RX_vect)
{
	if(master){
		char received;
		fscanf(&usart1_str, "%c", &received);
	}
	else{
		char comando1,comando2,comando3,comando4,comando5;
		bool valid = false;
		float angle = 0;
		
		fscanf(&usart1_str, "%c%c%c%c%c", &comando1, &comando2, &comando3, &comando4, &comando5);
		fprintf(&usart0_str, "\n");
		if(comando1 == 'S'){
			angle = (comando4 - 48)* 10 + (comando5 - 48);
			if (angle <= 90 && angle >= -90){
				if(comando2 == '0'){
					if(comando3 == '+'){
						PWM = 11 * angle + 1/9 * angle + 2999;
						valid = true;
						
						OCR1AH=PWM>>8;
						OCR1AL=PWM & 0xff;

					}
					else if(comando3 == '-'){
						PWM = 11 * angle - 1/9 * angle + 2999;
						valid = true;	
							
						OCR1AH=PWM>>8;
						OCR1AL=PWM & 0xff;				
					}
				}
				else if(comando2 == '1'){
					if(comando3 == '+'){
						PWM = 11 * angle + 1/9 * angle + 2999;
						valid = true;
						
						OCR1BH=PWM>>8;
						OCR1BL=PWM & 0xff;
					}
					else if(comando3 == '-'){
						PWM = 11 * angle - 1/9 * angle + 2999;
						valid = true;
						
						OCR1BH=PWM>>8;
						OCR1BL=PWM & 0xff;
					}
				}
				else if(comando2 == '2'){
					if(comando3 == '+'){
						PWM = 11 * angle + 1/9 * angle + 2999;
						valid = true;
						
						OCR1CH=PWM>>8;
						OCR1CL=PWM & 0xff;
					}
					else if(comando3 == '-'){
						PWM = 11 * angle - 1/9 * angle + 2999;
						valid = true;
						
						OCR1CH=PWM>>8;
						OCR1CL=PWM & 0xff;
					}
				}
			}
			
		}
		else if(comando1 == 'L'){
			if(comando2 == '0'){
				if (comando3 == 'O' && comando4 == 'N' && comando5 == 'N'){
					valid = true;
					PORTH |= (1<<PH0);			
				}
				else if(comando3 == 'O' && comando4 == 'F' && comando5 == 'F'){
					valid = true;
					PORTH &= ~(1<<PH0);
				}
			}
			else if(comando2 == '1'){
				if (comando3 == 'O' && comando4 == 'N' && comando5 == 'N'){
					valid = true;
					PORTH |= (1<<PH1);
				}
				else if(comando3 == 'O' && comando4 == 'F' && comando5 == 'F'){
					valid = true;
					PORTH &= ~(1<<PH1);
				}
			}
		}
		
		if(valid){
			fprintf(&usart1_str, "\n ACK\n");
		}
		else{
			fprintf(&usart1_str, "\n INVALID\n");
		}
	}
	_delay_us(3);
}


/***********************
*  FUNÇÕES  DO TIMER1  *
***********************/

void Timer1Init(void)
  {
    /* Inicializacao to TIMER1:
            Modo 14 	
    */
	
	// Modo 14, CTC: (WGM13, WGM12, WGM11, WGM10)=(1,1,1,0)
	// Comutar OC1A para gerar onda quadrada: (COM1A1,COM1A0)=(1,0), (Tabela 3)
	
    TCCR1A=(1<<COM1A1) | (0<<COM1A0) | (1<<COM1B1) | (0<<COM1B0) | (1<<COM1C1) | (0<<COM1C0) | (1<<WGM11) | (0<<WGM10);
    TCCR1B=(0<<ICNC1) | (0<<ICES1) | (1<<WGM13) | (1<<WGM12) | (0<<CS12) | (1<<CS11) | (0<<CS10);
 
	ICR1H = CONST_ICR1 >> 8;
	ICR1L = CONST_ICR1 && 0xff;
	
    OCR1AH=INIT_OCnX>>8;
    OCR1AL=INIT_OCnX & 0xff;
	
	OCR1BH=INIT_OCnX>>8;
	OCR1BL=INIT_OCnX & 0xff;
	
	OCR1CH=INIT_OCnX>>8;
	OCR1CL=INIT_OCnX & 0xff;

    // Timer/Counter 1 Interrupt(s) initialization
    TIMSK1=(0<<ICIE1) | (0<<OCIE1C) | (0<<OCIE1B) | (0<<OCIE1A) | (0<<TOIE1);

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
	UBRR0L=BAUD_RATE;
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

void USART1Init(void)
{
    /* Inicializacao da USART1:
	       8 bits, 1 stop bit, sem paridade
		   Baud rate = 9600 bps
		   Interrupcoes por recepcao de caractere
	*/
	
	UCSR1A=(0<<RXC1) | (0<<TXC1) | (0<<UDRE1) | (0<<FE1) | (0<<DOR1) | (0<<UPE1) | (0<<U2X1) | (0<<MPCM1);
    UCSR1B=(1<<RXCIE1) | (0<<TXCIE1) | (0<<UDRIE1) | (1<<RXEN1) | (1<<TXEN1) | (0<<UCSZ12) | (0<<RXB80) | (0<<TXB81);
    UCSR1C=(0<<UMSEL11) |(0<<UMSEL10) | (0<<UPM11) | (0<<UPM10) | (0<<USBS1) | (1<<UCSZ11) | (1<<UCSZ10) | (0<<UCPOL1);
    UBRR1H=0x00;
    UBRR1L=BAUD_RATE;
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
   USART0SendByte(u8Data,&usart0_str);
   // Retorna dado o recebido
   return u8Data;
}                             