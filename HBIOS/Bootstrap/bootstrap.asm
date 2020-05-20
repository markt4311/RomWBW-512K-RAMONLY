
CONDAT	.EQU	$81
MPGSEL	.EQU	$82
CLRBS	.EQU	$83

BOOTLOADER	.EQU	$F000

	.ORG	0

	ld	hl,BOOTLOADER
	ld	c,CONDAT

	;	Bootloader is used to create bootstrap.inc by Build.ps1

#INCLUDE	"bootstrap.inc"
	
	xor	a		; clear a
	ld	b,a		; clear b
	ld	h,a		; clear h
	ld	l,a		; clear l

	jp	BOOTLOADER - 2	;	2 bytes for out instruction
	out	(CLRBS),a

	.END
	