; ====================
; SGB support routines
; ====================

; SGB command definitions
def PAL01		= $00
def PAL23		= $01
def PAL03		= $02
def PAL12		= $03
def ATTR_BLK	= $04
def ATTR_LIN	= $05
def ATTR_DIV	= $06
def ATTR_CHR	= $07
def SOUND 		= $08
def SOU_TRN		= $09
def PAL_SET		= $0a
def PAL_TRN		= $0b
def ATRC_EN		= $0c
def TEST_EN		= $0d
def ICON_EN		= $0e
def DATA_SND	= $0f
def DATA_TRN	= $10
def MLT_REQ		= $11
def JUMP		= $12
def CHR_TRN		= $13
def PCT_TRN		= $14
def ATTR_TRN	= $15
def ATTR_SET	= $16
def MASK_EN		= $17
def OBJ_TRN		= $18

; constants
def SIZEOF_SGB_PACKET EQU 16

macro sgb_packet_header
	db	\1 * 8 | \2
	endm

section "SGB support RAM",wram0
SGB_PacketBuffer:	ds	16

section "SGB support routines",rom0

; HL = pointer to GFX data to send on GB side
; B = destination on SNES side
; Returns if we're not on SGB or SGB2.
; NOTE 1: Assumes VBlank is enabled!
; NOTE 2: Trashes VRAM!
SGB_SendGFX:
	call	CheckSGB
	ret		nz
	push	bc
	push	hl
	xor		a
	ldh		[rBGP],a
	; wait 2 frames to ensure the SNES gets a picture
	ld		a,2
	call	WaitFrames
	; freeze display (otherwise we get visible garbage)
	ld		a,MASK_EN << 3 | 1
	ld		b,1
	call	SGB_SendAB
	ld		a,%11100100
	ldh		[rBGP],a
	pop		hl

	; load tile graphics into GB VRAM
	halt
	xor		a
	ldh		[rLCDC],a
	ld		de,$8000
	ld		bc,$fff
:	ld		a,[hl+]
	ld		[de],a
	inc		de
	dec		bc
	ld		a,b
	or		c
	jr		nz,:-
	
	; generate tilemap
	ld		bc,$1412
	ld		hl,$9800
	xor		a
.loop
	ld		[hl+],a
	inc		a
	jr		z,.break
	dec		b
	jr		nz,.loop
	push	af
	ld		b,$14
	ld		a,l
	and		$e0
	add		$20
	ld		l,a
	jr		nc,:+
	inc		h
:	pop		af
	dec		c
	jr		nz,.loop
.break
	; prepare display for GFX transfer
	ld		a,LCDCF_ON | LCDCF_BG8000 | LCDCF_BGON
	ldh		[rLCDC],a
	
	; do the transfer!
	pop		af
	sra		a
	ld		b,a
	ld		a,CHR_TRN << 3 | 1
	call	SGB_SendAB
	
	xor		a
	ldh		[rBGP],a
	
	; unfreeze display
	ld		a,MASK_EN << 3 | 1
	ld		b,0
	call	SGB_SendAB
	ret

; the following routines were shamelessly stolen from https://github.com/pinobatch/little-things-gb/blob/master/bordercrossing/src/sgb.z80

;;
; Send a 1-packet SGB command whose first two bytes are A and B
; and whose remainder is zero filled.
SGB_SendAB::
	ld 		c,0
	; fall through

;;
; Send a 1-packet SGB command whose first three bytes are A, B, and C
; and whose remainder is zero filled.
SGB_SendABC::
	ld 		hl,SGB_PacketBuffer
	push 	hl
	ld 		[hl+],a
	ld 		a,b
	ld 		[hl+],a
	ld 		a,c
	ld 		[hl+],a
	xor 	a
	ld 		c,13
:	ld 		[hl+],a
	dec 	c
	jr 		nz,:-
	pop 	hl
	; fall through

;;
; Sends a Super Game Boy packet starting at HL.
; Assumes no IRQ handler does any sort of controller autoreading.
; @return HL first byte after end of last packet
SGB_SendPacket::
	; B: Number of remaining bytes in this packet
	; C: Number of remaining packets
	; D: Remaining bit data
	ld 		a,$07
	and 	[hl]
	ret 	z
	ld 		c,a

.packetloop:
	; Start transfer by asserting both halves of the key matrix
	; momentarily.  (This is like strobing an NES controller.)
	xor 	a
	ldh 	[rP1],a
	ld 		a,$30
	ldh 	[rP1],a
	ld 		b,SIZEOF_SGB_PACKET
.byteloop:
	ld 		a,[hl+]  ; Read a byte from the packet
	
	; Put bit 0 in carry and the rest (and a 1) into D.  Once this 1
	; is shifted out of D, D is 0 and the byte is finished.
	; (PB16 and IUR use the same principle for loop control.)
	scf     ; A = hgfedcba, CF = 1
	rra     ; A = 1hgfedcb, CF = a
	ld 		d,a
.bitloop:
	; Send a 1 as $10 then $30, or a 0 as $20 then $30.
	; This is constant time thanks to ISSOtm, unlike SGB BIOS
	; which takes 1 mcycle longer to send a 0 then a 1.
	ld 		a,$10
	jr 		c, .bitIs1
	add 	a ; ld a,$20
.bitIs1:
	ldh 	[rP1],a
	ld 		a,$30
	ldh 	[rP1],a
	
	ldh 	a,[rIE]  ; Burn 3 cycles to retain original loops's speed
	
	; Advance D to next bit (this is like NES MMC1)
	srl 	d
	jr 		nz,.bitloop
	dec 	b
	jr 		nz,.byteloop
	
	; Send $20 $30 as end of packet
	ld 		a,$20
	ldh 	[rP1],a
	ld 		a,$30
	ldh		[rP1],a
	
	call 	SGB_Wait
	dec 	c
	jr 		nz,.packetloop
	ret
 
SGB_Wait:
	ld 		de,65536 - 17868
.loop:
	inc 	e
	jr 		nz,.loop
	inc 	d
	jr 		nz,.loop
	ret

; ========
