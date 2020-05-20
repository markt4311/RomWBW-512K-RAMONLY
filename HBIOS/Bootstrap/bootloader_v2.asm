;	v2	25-Jul-2019
;	Check console status ready instead of relying on wait to see if this
;	allows operation at 20MHz
;
#INCLUDE	"build.inc"

CONSTAT	.EQU	$80
CONDAT	.EQU	$81
MPGSEL	.EQU	$82
CLRBS	.EQU	$83

CONRXF	.EQU	$01

START	.EQU	0

	.ORG	$F000

;	ld	c,CONDAT		;	set up by bootstrap
;	xor	a			;	clear a
;	ld	b,a			;	set up by bootstrap
;	ld	h,a
;	ld	l,a

	ld	d,a			; d used for page selection as a now overwritten by CONSTAT
LBOOT:
;	inir				; load 256 byte block
	in	a,(CONSTAT)
	and	CONRXF
	jr	z,LBOOT		; wait for RX Full

	ini
	jr	nz,LBOOT

	bit	7,h
	jr	z,LBOOT			; 32K block
	
	; reset h for start of next 32K block
	; b is always going to be 0 here
	ld	h,b			

	inc	d			; next page
	ld	a,d
	out	(MPGSEL),a		; set next page

	cp	ROMSIZE / 32		; 10 blocks of 32K
	jr	nz,LBOOT

	xor	a			; clear page select
	out	(MPGSEL),a
	jp	START

	.END
