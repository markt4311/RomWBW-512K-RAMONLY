
#INCLUDE	"build.inc"

CONDAT	.EQU	$81
MPGSEL	.EQU	$82
CLRBS	.EQU	$83

START	.EQU	0

	.ORG	$F000

;	ld	c,CONDAT		;	set up by bootstrap
;	xor	a			;	clear a
;	ld	b,a			;	set up by bootstrap
;	ld	h,a
;	ld	l,a
LBOOT:
	inir				; load 256 byte block
	bit	7,h
	jr	z,LBOOT			; 32K block
	
	; reset h for start of next 32K block
	; b is always going to be 0 here
	ld	h,b			

	inc	a
	out	(MPGSEL),a		; set next page

	cp	ROMSIZE / 32		; 10 blocks of 32K
	jr	nz,LBOOT

	xor	a			; clear page select
	out	(MPGSEL),a
	jp	START

	.END
