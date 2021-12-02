;*************************************************************************
; testLONGSUB.ASM                                                        *
;                                                                        *
;    Programa teste para a instruc�o LONSUB.                             *
;                                                                        *
;    LONGSUB nao faz parte do conjunto instrucoes do 8080/8085.          *
;                                                                        *
;    LONGSUB � codifivada com o byte [20H].                              *
;      Subtrai o numero de C bytes apontado por DE                       *
;      do numero de C bytes apontado por HL e coloca o                   *
;      o resultado a partir do endere�o HL.                              *
;      Os numeros s�o armazenados do byte mais significativo             *
;      para o menos significativo. Afeta apenas CARRY.                   *
;                                                                        *
;    O programa assume um hardware dotado dos seguintes elementos:       *
;                                                                        *
;    - Processador MP8 (8080/8085 simile);                               *
;    - ROM de 0000H a 1FFFh;                                             *
;    - RAM de E000h a FFFFh;                                             *
;    - UART 8250A vista nos enderecos 08H a 0Fh;                         *
;    - PIO de entrada vista no endere�o 00h;                             *
;    - PIO de sa�da vista no endere�o 00h.                               *
;                                                                        *
;    Para compilar e "linkar" o programa, pode ser usado o assembler     *
;    "zmac", com a linha de comando:                                     *
;                                                                        *
;         "zmac -8 --oo lst,hex longsub.asm".                            *
;                                                                        *
;    zmac produzir� na pasta zout o arquivo "longsub.hex", imagem do     *
;    c�digo execut�vel a ser carregado no projeto Proteus e tamb�m       *
;    e tamb�m o arquivo de listagem "longsub.lst".                       *
;                                                                        *
;*************************************************************************

; Define origem da ROM e da RAM (este programa tem dois segmentos).
; Diretivas nao podem comecar na primeira coluna.

CODIGO		EQU	0000H

DADOS		EQU	0E000H

TOPO_RAM	EQU	0FFFFH

;*******************************************
; Definicao de macros par que zmac reconheca
; novos mnemonicos de instrucao.
;*******************************************

FILLBLOCK	MACRO
		DB	08H
		ENDM	

MOVBLOCK	MACRO
		DB	10H
		ENDM	

LONGADD		MACRO
		DB	18H
		ENDM	

LONGSUB		MACRO
		DB	20H
		ENDM	


LONGCMP		MACRO
		DB	28H
		ENDM	

JMP256		MACRO
		DB	0CBH
		ENDM

;********************
; In�cio do c�digo  *
;********************

	ORG	CODIGO

INICIO:         LXI	B,8
		LXI	D,CONSTANTE1
		LXI	H,PARCELA1
		MOVBLOCK

		LXI	D,CONSTANTE2
		LXI	H,PARCELA2
		MOVBLOCK

		LXI	B,8
		LXI	D,PARCELA1
		LXI	H,PARCELA2

; Efetua Mem[HL..HL+(C-1)]<--Mem[HL..HL+(C-1)]-Mem[DE..DE+(C-1)].
REP_LONGSUB:	LONGSUB
		JMP REP_LONGSUB


CONSTANTE1:	DB	00H,00H,00H,00H,00H,00H,00H,01H		
CONSTANTE2:	DB	00H,00H,00H,00H,00H,00H,00H,00H


	ORG	DADOS
PARCELA1:	DS	8
PARCELA2:	DS	8

        END	INICIO

