;
; N8 HARDWARE DEFINITIONS
;
RAMBIAS		.EQU	0		; RAM STARTS AT 0K
;
N8_BASE		.EQU	$80		; I/O BASE ADDRESS FOR ONBOARD PERIPHERALS
;
N8_PPI0		.EQU	N8_BASE + $00	; FIRST PARALLEL PORT
N8_PPI1		.EQU	N8_BASE + $04	; SECOND PARALLEL PORT
N8_RTC		.EQU	N8_BASE + $08	; RTC LATCH AND BUFFER
N8_FDC		.EQU	N8_BASE + $0C	; FLOPPY DISK CONTROLLER
N8_UTIL		.EQU	N8_BASE + $10	; FLOPPY DISK UTILITY 
N8_ACR		.EQU	N8_BASE + $14	; AUXILLARY CONTROL REGISTER
N8_RMAP		.EQU	N8_BASE + $16	; ROM PAGE REGISTER
N8_VDP		.EQU	N8_BASE + $18	; VIDEO DISPLAY PROCESSOR (TMS9918A)
N8_PSG		.EQU	N8_BASE + $1C	; PROGRAMMABLE SOUND GENERATOR (AY-3-8910)
;
N8_DEFACR	.EQU	$1B		; DEFAULT VALUE FOR ACR REGISTER
;
RTC		.EQU	N8_RTC		; GENERIC ALIAS FOR RTC PORT
PPIBASE		.EQU	N8_PPI0		; GENERIC ALIAS FOR PRIMARY PARALLEL PORT
;
Z180_BASE	.EQU	$40		; I/O BASE ADDRESS FOR INTERNAL Z180 REGISTERS
#INCLUDE "z180.inc"
