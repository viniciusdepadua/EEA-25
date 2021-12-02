;*************************************************************************
;  HANOI.ASM                                                             *
;    Resolve recursivamente o problema "Torre de Hanoi".                 *
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
;    Para compilar e "linkar" o programa, pode ser usado o assembler     *
;    "zmac", com a linha de comando:                                     *
;                                                                        *
;         "zmac -8 --oo lst,hex hanoi.asm".                              *
;                                                                        *
;    zmac produzirá na pasta zout o arquivo "hanoi.hex", imagem do       *
;    código executável a ser carregado no projeto Proteus.               *
;                                                                        *
;*************************************************************************

; Define origem da ROM e da RAM (este programa tem dois segmentos).
; Diretivas nao podem comecar na primeira coluna.

CODIGO		EQU	0000H

DADOS		EQU	0E000H

;*******************************************
; Define instancia para o problema Hanoi.  *
;*******************************************

ORIGEM          EQU     2               ; Coluna origem.
DESTINO         EQU     0               ; Coluna destino.
NDISCOS         EQU     7               ; Numero de discos.
NMAX            EQU     9               ; Numero maximo de discos.

;*******************************************************************
;       Cria na RAM a Estrutura de dados utilizada para recursao,  *
;       area para mensagens impressas ea pilha para o programa.    *
;                                                                  *

	ORG	DADOS

;*****************************************************
; Pilha de dados para recursao.                      *
;    TOPO_AGENDA                                     *
;         |                                          *
;         |      AGENDA:        Origem               *
;         |                     Destino              *
;         |                     Numero de discos     *
;         |                     Origem               *
;         |                     Destino              *
;         |                     Numero de discos     *
;         |                     . . . . . .          *
;         |                     . . . . . .          *
;         |                     . . . . . .          *
;         |                     Origem               *
;         |                     Destino              *
;          ----------------->   Numero de discos     *
;                                                    *
;*****************************************************

TOPO_AGENDA     DW      AGENDA
AGENDA:         DS      3*NMAX  ; Tres bytes por disco


;*******************************************************
; Area para construcao de Mensagens a serem impressas. *
;*******************************************************
MENSAGEM:       DS      80


;**************************
; Pilha para o programa.  *
;**************************
PILHA:          DS      20*NMAX
TOPO_PILHA      EQU     $

;       Final do segmento "DADOS"                                  *
;                                                                  *
;*******************************************************************


;***********************************************************************
;                                                                      *
; Na area de ROM, o codigo para resolver o problema.


; Abre o segmento "CODIGO" para estabelecer seu conteudo.
;        SEG CODIGO
	ORG	CODIGO

INICIO:         LXI     SP,TOPO_PILHA   ; Pilha na RAM.

                CALL    INICIASIO
;                MVI     A,08H           ; Para deixar o PROTEUS feliz.
;                CALL    OUTPUT

; Imprime mensagem inicial.
                LXI     H,MENSAGEM_INICIO
                CALL    DISPLAY
;********************************************************
; Aqui comeca a solucao do problema "Torre de Hanoi".   *
;********************************************************

PRINCIPAL:      LXI     H,AGENDA-1
                SHLD    TOPO_AGENDA

; Empilha dados iniciais para o problema.
                INX     H
                SHLD    TOPO_AGENDA
                MVI     A,ORIGEM
                MOV     M,A

                INX     H
                SHLD    TOPO_AGENDA
                MVI     A,DESTINO
                MOV     M,A

                INX     H
                SHLD    TOPO_AGENDA
                MVI     A,NDISCOS
                MOV     M,A

; Invoca a subrotina recursiva "HANOI", que resolve o problema.

                CALL    HANOI

; Imprime mensagem final.
                LXI     H,MENSAGEM_FIM
                CALL    DISPLAY

; Fica em loop depois de resolver o problema.
                JMP     $

;*********************************************************
;  HANOI                                                 *
;  Subrotina recursiva para resolver a Torre de Hanoi.   *
;*********************************************************

; Se ndiscos = 1 movimenta o disco, desempilha a instancia e retorna.
HANOI:          LHLD    TOPO_AGENDA
                MOV     A,M
                CPI     1
                JNZ     RECURSAO

; Desempilha instancia atual e move um disco de Origem para Destino.
                DCX     H
                MOV     C,M             ; Destino em C.
                DCX     H
                MOV     B,M             ; Origem em B.
                DCX     H
                SHLD    TOPO_AGENDA
                CALL    EMITIR_MOVIMENTO
                RET

; Desempilha instancia atual (mover ndiscos de Origem para Destino).
RECURSAO:       MOV     D,M             ; ndiscos em D.
                DCX     H
                MOV     C,M             ; Destino em C.
                DCX     H
                MOV     B,M             ; Origem em B.
                DCX     H
                SHLD    TOPO_AGENDA

; Empilha agenda para a recursao.
; Agenda mover ndiscos-1 de Origem para Intermediario.
; Intermediario = 3 - Origem - Destino.
                LHLD    TOPO_AGENDA
                INX     H
                MOV     M,B

                INX     H
                MVI     A,3
                SUB     B
                SUB     C
                MOV     M,A

                INX     H
                SHLD    TOPO_AGENDA
                MOV     A,D
                DCR     A
                MOV     M,A

; Invoca a si propria.
                PUSH    B
                PUSH    D
                CALL    HANOI
                POP     D
                POP     B

; Agenda mover 1 disco de Origem para Destino.
                LHLD    TOPO_AGENDA
                INX     H
                MOV     M,B

                INX     H
                MOV     M,C

                INX     H
                SHLD    TOPO_AGENDA
                MVI     M,1

; Invoca a si propria.
                PUSH    B
                PUSH    D
                CALL    HANOI
                POP     D
                POP     B

; Agenda mover ndiscos-1 de Intermediario para Destino.
; Intermediario = 3 - Origem - Destino.
                LHLD    TOPO_AGENDA
                INX     H
                MVI     A,3
                SUB     B
                SUB     C
                MOV     M,A

                INX     H
                MOV     M,C

                INX     H
                SHLD    TOPO_AGENDA
                MOV     A,D
                DCR     A
                MOV     M,A

; Invoca a si propria.
                CALL    HANOI
                RET
;                               *
;********************************


;*************************************************
;  EMITIR_MOVIMENTO                              *
;  Imprime o movimento  " ORIGEM --> DESTINO".   *
;*************************************************

EMITIR_MOVIMENTO:
                PUSH    PSW
                PUSH    H

                MVI     A,"0"                   ; Imprime origem.
                ADD     B
                CALL    OUTPUT

                LXI     H,MENSAGEM_SETA         ; Imprime seta.
                CALL    DISPLAY

                MVI     A,"0"                   ; Imprime destino.
                ADD     C
                CALL    OUTPUT

                MVI     A,RETURN                ; Vai para proxima linha.
                CALL    OUTPUT

                POP     H
                POP     PSW

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
;    Verifica se ha byte recebido pela UART 8250A.                  *
;                                                                   *
;    Se houver byte retorna com flag Z = 1.                         *
;    caso contrario retorna com flag Z = 0.                         *
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

MENSAGEM_SETA:  DB      "  -->  $"

MENSAGEM_INICIO:
                DB      RETURN,"Movendo ",'0'+ndiscos," discos "
		DB      "de ",'0'+origem," para ",'0'+destino,".",RETURN
                DB      "Aqui vai a solucao:",RETURN,RETURN,"$"

MENSAGEM_FIM:   DB      RETURN,"Terminei !",RETURN,"$"

;                               *
;********************************


;       Final do segmento "CODIGO"                                   **
;                                                                    **
;**********************************************************************
;**********************************************************************

        END	INICIO

