;*************************************************************************
;  IOPORTS.ASM                                                           *
;    Programa teste para instruções de entrada e saída.                  *
;                                                                        *
;    O programa assume um hardware dotado dos seguintes elementos:       *
;                                                                        *
;    - Processador MP8 (8080/8085 simile);                               *
;    - ROM de 0000H a 1FFFh;                                             *
;    - RAM de E000h a FFFFh;                                             *
;    - UART 8250A vista nos enderecos 08H a 0Fh;                         *
;    - PIO de entrada vista no endereço 00h;                             *
;    - PIO de saída vista no endereço 00h.                               *
;                                                                        *
;    Funcionamento do programa:                                          *
;                                                                        *
;      INICIO:   Inicializa o Stack Pointer;                             *
;                Inicializa a UART 8250A ;                               *
;                Faz A = 00H;                                            *
;      LOOP:     Escreve A no PORT[00H];                                 *                                  
;                Chama subrotina DELAY para atraso;                      *
;                Incrementa A;                                           *
;                Salta para LOOP                                         *
;                                                                        *
;    Para compilar e "linkar" o programa, pode ser usado o assembler     *
;    "zmac", com a linha de comando:                                     *
;                                                                        *
;         "zmac -8 --oo lst,hex ioports.asm".                            *
;                                                                        *
;    zmac produzirá na pasta zout o arquivo "ioports.hex", imagem do     *
;    código executável a ser carregado no projeto Proteus e também       *
;    e também o arquivo de listagem "ioports.lst".                       *
;                                                                        *
;*************************************************************************

; Define origem da ROM e da RAM (este programa tem dois segmentos).
; Diretivas nao podem comecar na primeira coluna.

CODIGO		EQU	0000H

DADOS		EQU	0E000H

TOPO_RAM	EQU	0FFFFH


;********************
; Início do código  *
;********************

	ORG	CODIGO

INICIO:         LXI     SP,TOPO_RAM   ; Pilha na RAM.
                CALL    INICIASIO

; Imprime mensagem.
                LXI     H,MENSAGEM_INICIO
                CALL    DISPLAY

; Aqui comeca o teste dos PORTs".

PRINCIPAL:      MVI	A,00H
LOOP:		OUT	00H
		CALL	DELAY
		INR	A
		JMP	LOOP
;                               *
;********************************


;************************************
; DELAY                             *
;    Subrotina para gerar atrasos.  *
;************************************
DELAY:
		PUSH	PSW
		PUSH	H

		LXI	H,200
LOOP_DELAY:	DCX	H
		MOV	A,H
		ORA	L

 		JNZ	LOOP_DELAY

		POP	H
		POP	PSW

		RET
;                               *
;********************************


;****************************************************
;****************************************************
;    SUBROTINAS PARA MANIPULACAO DA UART 8250A     **
;                                                  **
;    NAO ALTERE O QUE VEM A SEGUIR !!!!            **
;****************************************************
;****************************************************


;****************************
;  Definicao de constantes  *
;****************************
RBR             EQU     08H     ; Com bit DLA (LCR.7) em 0.
THR             EQU     08H     ; Com bit DLA (LCR.7) em 0.     
IER             EQU     09H     ; Com bit DLA (LCR.7) em 0.
IIR             EQU     0AH
LCR             EQU     0BH
MCR             EQU     0CH
LSR             EQU     0DH
MSR             EQU     0EH
DLL             EQU     08H     ; Com bit DLA (LCR.7) em 1.
DLM             EQU     09H     ; Com bit DLA (LCR.7) em 1.
SCR             EQU     0FH
;*******************************************************
;  INICIASIO                                           *
;    Inicializa a UART 8250A                           *
;                                                      *
;    UART 8250A inicializada com:                      *
;      - 1 stop bit;                                   *
;      - sem paridade;                                 *
;      - palavras de 8 bits;                           *
;      - baud rate = CLOCK/(16*DIVISOR).               *
;                                                      *
;                                                      *
;    Para operar a 9600 baud devemos ter portanto:     *
;        DIVISOR = 1843200/(16*9600) = 12 = 0CH        *
;                                                      *
;*******************************************************
INICIASIO:      PUSH    PSW

                MVI     A,10000011B
                OUT     LCR
                MVI     A,0CH
                OUT     DLL
                MVI     A,00H
                OUT     DLM
                MVI     A,00000011B
                OUT     LCR

                POP     PSW
                RET
;                               *
;********************************

;*********************************************************************
;  OUTPUT                                                            *
;    Envia A para transmissao pela UART 8250A.                       *
;                                                                    *
;    Somente retorna apos conseguir escrever A no BUFFER da UART.    *
;    Preserva todos os registradores.                                *
;                                                                    *
;   STATUS_UART = (DSR,BRKDET,FE,OE,PE,TXEMPTY,RXREADY,TXREADY)      *
;                                                                    *
;*********************************************************************
OUTPUT:         PUSH    PSW
                PUSH    B

                MOV     B,A
OUTPUTLP:       IN      LSR
                ANI     20H
                JZ      OUTPUTLP
                MOV     A,B
                OUT     THR

                POP     B
                POP     PSW
                RET
;                               *
;********************************

;****************************************************************************
;  INPUT                                                                    *
;    Le byte recebido pela UART 8250A                                       *
;                                                                           *
;      Somente retorna apos detectar um byte no BUFFER de dados da UART.    *
;                                                                           *
;      Retorna com o byte em A.  Preserva os demais registradores.          *
;                                                                           *
;      STATUS_UART = (DSR,BRKDET,FE,OE,PE,TXEMPTY,RXREADY,TXREADY)          *
;                                                                           *
;****************************************************************************
INPUT:          PUSH    PSW

INPUTLP:        IN      LSR
                ANI     00000001B
                JZ      INPUTLP

                POP     PSW
                IN      RBR
                RET
;                               *
;********************************

;********************************************************************
;  CHECKINPUT                                                       *
;    Verifica se ha byte recebido pela UART 8250A:                  *
;                                                                   *
;    Se houver byte retorna com flag Z = 1;                         *
;    caso contrario retorna com flag Z = 0;                         *
;                                                                   *
;    Preserva os demais registradores.                              *
;                                                                   *
;    STATUS_UART = (DSR,BRKDET,FE,OE,PE,TXEMPTY,RXREADY,TXREADY)    *
;                                                                   *
;********************************************************************
CHECKINPUT:     PUSH    PSW

                IN      LSR
                ANI     00000001B
                JNZ     TEMBYTE

; Retorno quando nao tem byte.
NAOTEMBYTE:     POP     PSW
                STC
                CMC
                RET

; Retorno quando tem byte.
TEMBYTE:        POP     PSW
                STC
                RET
;                               *
;********************************

;****************************************************
; DISPLAY                                           *
;   Subrotina para imprimir cadeia de caracteres.   *
;                                                   *
;   Parametro: HL aponta para string ASCII          *
;   terminado em "$"                                *
;****************************************************

DISPLAY:        PUSH    PSW
                PUSH    B
                PUSH    D
                PUSH    H

ADIANTE:        MOV     A,M
                CPI     "$"
                JZ      DISPLAY_FIM
                CALL    OUTPUT
                INX     H
                JMP     ADIANTE

DISPLAY_FIM:    POP     H
                POP     D
                POP     B
                POP     PSW
                RET
;                               *
;********************************

;**********************************
; Cadeias de caracteres em ROM.   *
;**********************************

RETURN          EQU     0DH
LINEFEED	EQU	0AH

MENSAGEM_INICIO:
                DB      "Testando output PORT 00H.",RETURN,"$"


;                               *
;********************************


;       Final do segmento "CODIGO"                                   **
;                                                                    **
;**********************************************************************
;**********************************************************************

        END	INICIO

