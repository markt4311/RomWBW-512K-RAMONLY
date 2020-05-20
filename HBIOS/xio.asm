;___XIO________________________________________________________________________________________________________________
;
; DIRECT SERIAL I/O
;
;   PROVIDES INTERFACE TO PLATFORM BASE SERIAL I/O DEVICE
;   ALLOWS USER MESSAGING/INTERACTION PRIOR TO AND DURING HBIOS INIT
;______________________________________________________________________________________________________________________
;
;
#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA) | (PLATFORM == PLT_ZETA2))
;
UARTIOB		.EQU	$68
;
SIO_RBR		.EQU	UARTIOB + 0	; DLAB=0: RCVR BUFFER REG (READ ONLY)
SIO_THR		.EQU	UARTIOB + 0	; DLAB=0: XMIT HOLDING REG (WRITE ONLY)
SIO_IER		.EQU	UARTIOB + 1	; DLAB=0: INT ENABLE REG
SIO_IIR		.EQU	UARTIOB + 2	; INT IDENT REGISTER (READ ONLY)
SIO_FCR		.EQU	UARTIOB + 2	; FIFO CONTROL REG (WRITE ONLY)
SIO_LCR		.EQU	UARTIOB + 3	; LINE CONTROL REG
SIO_MCR		.EQU	UARTIOB + 4	; MODEM CONTROL REG
SIO_LSR		.EQU	UARTIOB + 5	; LINE STATUS REG
SIO_MSR		.EQU	UARTIOB + 6	; MODEM STATUS REG
SIO_SCR		.EQU	UARTIOB + 7	; SCRATCH REGISTER
SIO_DLL		.EQU	UARTIOB + 0	; DLAB=1: DIVISOR LATCH (LS)
SIO_DLM		.EQU	UARTIOB + 1	; DLAB=1: DIVISOR LATCH (MS)
;
;XIO_DIV	.EQU	(UARTOSC / (16 * CONBAUD))
;
#ENDIF

#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
#ENDIF

XIO_INIT:	; MINIMAL UART INIT

#IF (PLATFORM == PLT_UNA)
	; SHOULD UNA SERIAL I/O BE RESET HERE???
#ENDIF

#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))

	; INIT ASCI0 WITH BASIC VALUES AND FAILSAFE DIVISOR
	LD	A,$66			; IGNORE CTS/DCD, NO BREAK DETECT
	OUT0	(Z180_ASEXT0),A		; -> ASEXT0
	LD	A,$64			; ENABLE XMT/RCV, 8 DATA, NO PARITY, 1 STOP
	OUT0	(Z180_CNTLA0),A		; -> CNTLA0
	;LD	A,$20			; FAILSAFE VALUE, 38400 BAUD AT 18.432 MHZ
	;LD	A,$22			; FAILSAFE VALUE, 9600 BAUD AT 18.432 MHZ
	;OUT0	(Z180_CNTLB0),A		; -> CNTLB0
	
	; TRY TO IMPLEMENT CONFIGURED BAUD RATE
	LD	HL,DEFSERCFG		; SERIAL CONFIG WORD
	LD	A,H			; BYTE W/ ENCODED BAUD RATE
	AND	$1F			; ISOLATE BITS
	LD	L,A			; MOVE TO L
	LD	H,0			; CLEAR MSB
	CALL	XIO_CNTLB		; DERIVE CNTLB VALUE
	JR	Z,XIO_INIT1		; SUCCESS, IMPLEMENT IT
	LD	C,$21 + Z180_CLKDIV	; FAILSAFE VALUE, 9600 BAUD IF OSC=18.432 MHZ

XIO_INIT1:
	LD	A,C			; MOVE VALUE TO ACCUM
	OUT0	(Z180_CNTLB0),A		; AND SET THE VALUE
#ENDIF

#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA) | (PLATFORM == PLT_ZETA2))

	LD	DE,DEFSERCFG		; SERIAL CONFIG WORD
	CALL	XIO_COMPDIV		; COMPUTE DIVISOR TO BC

	LD	A,$80			; LCR := DLAB ON
	OUT	(SIO_LCR),A		; SET LCR
	;LD	A,XIO_DIV % $100	; BAUD RATE DIVISOR (LSB)
	LD	A,C			; LOW BYTE OF DIVISOR
	OUT	(SIO_DLL),A		; SET DIVISOR (LSB)
	;LD	A,XIO_DIV / $100	; BAUD RATE DIVISOR (MSB)
	LD	A,B			; HIGH BYTE OF DIVISOR
	OUT	(SIO_DLM),A		; SET DIVISOR (MSB)
	LD	A,03H			; VALUE FOR LCR AND MCR
	OUT	(SIO_LCR),A		; LCR := 3, DLAB OFF, 8 DATA, 1 STOP, NO PARITY
	OUT  	(SIO_MCR),A		; MCR := 3, DTR ON, RTS ON
	LD	A,6			; DISABLE & RESET FIFO'S
	OUT	(SIO_FCR),A		; DO IT

#ENDIF

	RET
;
XIO_SYNC:	; WAIT FOR FOR PENDING DATA IN FIFO TO CLEAR
;
#IF (PLATFORM == PLT_UNA)
	; NOT SURE ANYTHING IS POSSIBLE HERE...
#ENDIF

#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
	; IMPLEMENT THIS... OR MAYBE NOT.
#ENDIF

#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA) | (PLATFORM == PLT_ZETA2))
	LD	DE,CPUMHZ * 25		; FAILSAFE TIMEOUT COUNTER
XIO_SYNC1:
	IN	A,(SIO_LSR)		; GET LINE STATUS REGISTER
	BIT	6,A			; TEST BIT 6 (TRANSMITTER EMPTY)
	JR	NZ,XIO_SYNC2		; EMPTY, MOVE ON
 	DEC	DE			; DECREMENT TIMEOUT COUNTER
	LD	A,D			; TEST TIMEOUT COUNTER
	OR	E			; ... FOR ZERO
	JR	NZ,XIO_SYNC1		; LOOP UNTIL TIMEOUT
XIO_SYNC2:
#ENDIF

	RET
;
XIO_CRLF2:	; OUTPUT 2 NEWLINES
	CALL	XIO_CRLF		; SEND CRLF, FALL THRU FOR ANOTHER
XIO_CRLF:	; OUTPUT A NEWLINE
	LD	A,13			; A = CR
	CALL	XIO_OUTC		; WRITE IT
	LD	A,10			; A = LF
	JR	XIO_OUTC		; WRITE IT AND RETURN
;
XIO_SPACE:	; OUTPUT A SPACE CHARACTER
	LD	A,' '
	JR	XIO_OUTC
;
XIO_DOT:	; OUTPUT A DOT (MARK PROGRESS)
	LD	A,'.'
;
XIO_OUTC:	; OUTPUT BYTE IN A

#IF (PLATFORM == PLT_UNA)
	PUSH	BC			; PRESERVE BC
	PUSH	DE			; PRESERVE DE
	LD	BC,$0012		; UNA UNIT = 0, FUNC = WRITE CHAR
	LD	E,A			; CHAR TO E
	CALL	$FFFD			; DO IT (RST 08 NOT SETUP YET)
	POP	DE			; RESTORE DE
	POP	BC			; RESTORE BC
	RET				; DONE
#ENDIF

#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
	PUSH	AF			; SAVE INCOMING BYTE
XIO_OUTC1:
	IN0	A,(Z180_STAT0)		; GET LINE STATUS
	AND	$02			; ISOLATE TDRE
	JR	Z,XIO_OUTC1		; LOOP TILL READY (EMPTY)
	POP	AF			; RECOVER INCOMING BYTE TO OUTPUT
	OUT0	(Z180_TDR0),A		; WRITE THE CHAR TO ASCI
	RET
#ENDIF

#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA) | (PLATFORM == PLT_ZETA2))
	PUSH	AF			; SAVE INCOMING BYTE
XIO_OUTC1:
	IN	A,(SIO_LSR)		; READ LINE STATUS REGISTER
	AND	$20			; ISOLATE THRE
	JR	Z,XIO_OUTC1		; LOOP TILL READY (EMPTY)
	POP	AF			; RECOVER BYTE TO WRITE
	OUT	(SIO_THR),A		; WRITE THE CHAR TO UART
	RET
#ENDIF
;
XIO_INC:	; INPUT BYTE TO A

#IF (PLATFORM == PLT_UNA)
	PUSH	BC			; PRESERVE BC
	PUSH	DE			; PRESERVE DE
	LD	BC,$0011		; UNA UNIT = 0, FUNC = READ CHAR
	CALL	$FFFD			; DO IT (RST 08 NOT SETUP YET)
	LD	A,E			; CHAR TO A
	POP	DE			; RESTORE DE
	POP	BC			; RESTORE BC
	RET				; DONE
#ENDIF

#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
XIO_INC1:
	IN0	A,(Z180_STAT0)		; READ LINE STATUS
	AND	$80			; ISOLATE RDRF
	JR	Z,XIO_INC1		; LOOP TILL CHAR AVAILABLE
	IN0	A,(Z180_RDR0)		; READ THE CHAR
	RET
#ENDIF

#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA) | (PLATFORM == PLT_ZETA2))
XIO_INC1:
	IN	A,(SIO_LSR)		; READ LINE STATUS REGISTER
	AND	$01			; ISOLATE RDR
	JR	Z,XIO_INC1		; LOOP TILL CHAR AVAILABLE
	IN	A,(SIO_RBR)		; READ THE CHAR
	RET
#ENDIF
;
XIO_IST:	; INPUT STATUS TO A (NUM CHARS WAITING)

#IF (PLATFORM == PLT_UNA)
	PUSH	BC			; PRESERVE BC
	PUSH	DE			; PRESERVE DE
	LD	BC,$0013		; UNA UNIT = 0, FUNC = READ CHAR
	CALL	$FFFD			; DO IT (RST 08 NOT SETUP YET)
	LD	A,E			; CHAR TO A
	OR	A			; UPDATE ZF
	POP	DE			; RESTORE DE
	POP	BC			; RESTORE BC
	RET				; DONE
#ENDIF

#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
	IN0	A,(Z180_STAT0)		; READ LINE STATUS
	AND	$80			; ISOLATE RDRF
	RET	Z			; NO CHARS WAITING, A=0, Z SET
	LD	A,1			; SIGNAL 1 CHAR WAITING
	OR	A			; UPDATE ZF
	RET
#ENDIF

#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA) | (PLATFORM == PLT_ZETA2))
	IN	A,(SIO_LSR)		; READ LINE STATUS REGISTER
	AND	$01			; ISOLATE RDR
	RET	Z			; NO CHARS WAITING, A=0, Z SET
	LD	A,1			; SIGNAL 1 CHAR WAITING
	OR	A			; UPDATE ZF
	RET
#ENDIF
;
XIO_OUTS:	; OUTPUT '$' TERMINATED STRING AT ADDRESS IN HL
	LD	A,(HL)			; GET NEXT BYTE
	CP	'$'			; END OF STRING?
	RET	Z			; YES, GET OUT
	CALL	XIO_OUTC		; OTHERWISE, WRITE IT
	INC	HL			; POINT TO NEXT BYTE
	JR	XIO_OUTS		; AND LOOP

#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA) | (PLATFORM == PLT_ZETA2))
;
; COMPUTE DIVISOR TO BC
;
XIO_COMPDIV:
	; WE WANT TO DETERMINE A DIVISOR FOR THE UART CLOCK
	; THAT RESULTS IN THE DESIRED BAUD RATE.
	; BAUD RATE = UART CLK / DIVISOR, OR TO SOLVE FOR DIVISOR
	; DIVISOR = UART CLK / BAUDRATE.
	; THE UART CLOCK IS THE UART OSC PRESCALED BY 16.  ALSO, WE CAN
	; TAKE ADVANTAGE OF ENCODED BAUD RATES ALWAYS BEING A FACTOR OF 75.
	; SO, WE CAN USE (UART OSC / 16 / 75) / (BAUDRATE / 75)
;
	; FIRST WE DECODE THE BAUDRATE, BUT WE USE A CONSTANT OF 1 INSTEAD
	; OF THE NORMAL 75.  THIS PRODUCES (BAUDRATE / 75).
;
	LD	A,D			; GET CONFIG MSB
	AND	$1F			; ISOLATE ENCODED BAUD RATE
	LD	L,A			; PUT IN L
	LD	H,0			; H IS ALWAYS ZERO
	LD	DE,1			; USE 1 FOR ENCODING CONSTANT
	CALL	DECODE			; DE:HL := BAUD RATE, ERRORS IGNORED
	EX	DE,HL			; DE := (BAUDRATE / 75), DISCARD HL
	LD	HL,UARTOSC / 16 / 75	; HL := (UART OSC / 16 / 75)
	JP	XIO_DIV16		; BC := HL/DE == DIVISOR AND RETURN
;
#ENDIF	
;
;
;
#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
;
; DERIVE A CNTLB VALUE BASED ON AN ENCODED BAUD RATE AND CURRENT CPU SPEED
; ENTRY: HL = ENCODED BAUD RATE
; EXIT: C = CNTLB VALUE, A=0/Z IFF SUCCESS
;
; DESIRED DIVISOR == CPUHZ / BAUD
; DUE TO ENCODING BAUD IS ALWAYS DIVISIBLE BY 75
; Z180 DIVISOR IS ALWAYS A FACTOR OF 160
;
; X = (CPU_HZ / 160) / 75 ==> SIMPLIFIED ==> X = CPU_KHZ / 12
; X = X / (BAUD / 75)
; IF X % 3 == 0, THEN (PS=1, X := X / 3) ELSE PS=0
; IF X % 4 == 0, THEN (DR=1, X := X / 4) ELSE DR=0
; SS := LOG2(X)
;
XIO_CNTLB:
	LD	DE,1			; USE DECODE CONSTANT OF 1 TO GET BAUD RATE ALREADY DIVIDED BY 75
	CALL	DECODE			; DECODE THE BAUDATE INTO DE:HL, DE IS DISCARDED
	;CALL	TSTPT
	RET	NZ			; ABORT ON ERROR
	PUSH	HL			; HL HAS (BAUD / 75), SAVE IT
	;LD	HL,(HCB + HCB_CPUKHZ)	; GET CPU CLK IN KHZ
	LD	HL,CPUKHZ		; CPU CLK IN KHZ
	;LD	HL,9216			; *DEBUG*
	
	; DUE TO THE LIMITED DIVISORS POSSIBLE WITH CNTLB, YOU PRETTY MUCH
	; NEED TO USE A CPU SPEED THAT IS A MULTIPLE OF 128KHZ.  BELOW, WE
	; ATTEMPT TO ROUND THE CPU SPEED DETECTED TO A MULTIPLE OF 128KHZ
	; WITH ROUNDING.  THIS JUST MAXIMIZES OUR CHANCES OF SUCCESS COMPUTING
	; THE DIVISOR.
	LD	DE,$0040		; HALF OF 128 IS 64
	ADD	HL,DE			; ADD FOR ROUNDING
	LD	A,L			; MOVE TO ACCUM
	AND	$80			; STRIP LOW ORDER 7 BITS
	LD	L,A			; ... AND PUT IT BACK
	
	LD	DE,12			; PREPARE TO DIVIDE BY 12
	CALL	XIO_DIV16		; BC := (CPU_KHZ / 12), REM IN HL, ZF
	;CALL	TSTPT
	POP	DE			; RESTORE (BAUD / 75)
	RET	NZ			; ABORT IF REMAINDER
	PUSH	BC			; MOVE WORKING VALUE
	POP	HL			; ... BACK TO HL
	CALL	XIO_DIV16		; BC := X / (BAUD / 75)
	;CALL	TSTPT
	RET	NZ			; ABORT IF REMAINDER
;	
	; DETERMINE PS BIT BY ATTEMPTING DIVIDE BY 3
	PUSH	BC			; SAVE WORKING VALUE ON STACK
	PUSH	BC			; MOVE WORKING VALUE
	POP	HL			; ... TO HL
	LD	DE,3			; SETUP TO DIVIDE BY 3
	CALL	XIO_DIV16		; BC := X / 3, REM IN HL, ZF
	;CALL	TSTPT
	POP	HL			; HL := PRIOR WORKING VALUE
	LD	E,0			; INIT E := 0 AS WORKING CNTLB VALUE
	JR	NZ,XIO_CNTLB1		; DID NOT WORK, LEAVE PS==0, SKIP AHEAD
	SET	5,E			; SET PS BIT
	PUSH	BC			; MOVE NEW WORKING
	POP	HL			; ... VALUE TO HL
;
XIO_CNTLB1:
	;CALL	TSTPT
	; DETERMINE DR BIT BY ATTEMPTING DIVIDE BY 4
	LD	A,L			; LOAD LSB OF WORKING VALUE
	AND	$03			; ISOLATE LOW ORDER BITS
	JR	NZ,XIO_CNTLB2		; NOT DIVISIBLE BY 4, SKIP AHEAD
	SET	3,E			; SET PS BIT
	SRL	H			; DIVIDE HL BY 4
	RR	L			; ...
	SRL	H			; ...
	RR	L			; ...
;
XIO_CNTLB2:
	;CALL	TSTPT
	; DETERMINE SS BITS BY RIGHT SHIFTING AND INCREMENTING
	LD	B,7			; LOOP COUNTER, MAX VALUE OF SS IS 7
	LD	C,E			; MOVE WORKING CNTLB VALUE TO C
XIO_CNTLB3:
	BIT	0,L			; CAN WE SHIFT AGAIN?
	JR	NZ,XIO_CNTLB4		; NOPE, DONE
	SRL	H			; IMPLEMENT THE
	RR	L			; ... SHIFT OPERATION
	INC	C			; INCREMENT SS BITS
	DJNZ	XIO_CNTLB3		; LOOP IF MORE SHIFTING POSSIBLE
;
	; AT THIS POINT HL MUST BE EQUAL TO 1 OR WE FAILED!
	DEC	HL			; IF HL == 1, SHOULD BECOME ZERO
	LD	A,H			; TEST HL
	OR	L			; ... FOR ZERO
	RET	NZ			; ABORT IF NOT ZERO
;
XIO_CNTLB4:
	;CALL	TSTPT
	XOR	A
	RET
;
#ENDIF
;
; COMPUTE HL / DE = BC W/ REMAINDER IN HL & ZF
;
XIO_DIV16:
	LD	A,H			; HL -> AC
	LD	C,L			; ...
	LD	HL,0			; INIT HL
	LD	B,16			; INIT LOOP COUNT
XIO_DIV16A:	
	SCF
	RL	C
	RLA	
	ADC	HL,HL	
	SBC	HL,DE	
	JR	NC,XIO_DIV16B	
	ADD	HL,DE	
	DEC	C	
XIO_DIV16B:	
	DJNZ	XIO_DIV16A		; LOOP AS NEEDED
	LD	B,A			; AC -> BC
	LD	A,H			; SET ZF
	OR	L			; ... BASED ON REMAINDER
	RET				; DONE