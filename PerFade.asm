section "PerFade RAM",wram0,align[8]
sys_PalTransferBuf:
sys_BGPalTransferBuf::  ds  (2*4)*8 ; 8 PalTransferBuf, 4 colors per palette, 2 bytes per color
sys_ObjPalTransferBuf:: ds  (2*4)*8 ; 8 PalTransferBuf, 4 colors per palette, 2 bytes per color
sys_PalBuffer:
sys_BGPalBuffer::       ds  (3*4)*8 ; BG palette work area (8 PalTransferBuf, 4 colors per palette, 3 bytes per color)
sys_ObjPalBuffer::      ds  (3*4)*8 ; OBJ palette work area (8 PalTransferBuf, 4 colors per palette, 3 bytes per color)
sys_Palettes:
sys_BGPalettes:         ds  (2*4)*8 ; main BG palette
sys_ObjPalettes:        ds  (2*4)*8 ; main OBJ palette
sys_PalBuffersEnd:
sys_FadeState::         db  ; bit 0 = fading, bit 1 = fade type (0 = white, 1 = black), bit 1 = fade dir (0 = in, 1 = out)
sys_FadeLevel::         db  ; current intensity level

section "PerFade routines",rom0

; INPUT:     a = color index to modify
;           hl = color 
; DESTROYS:  a, b, hl
SetColor::
    push    de
    and     15
    bit     3,a
    jr      nz,.obj
    add     a   ; x2
    ld      b,a
    ld      de,sys_BGPalTransferBuf
    add     e
    ld      e,a
    
    ld      a,h
    ld      [de],a
    inc     e
    ld      a,l
    ld      [de],a
    pop     de
    ret
.obj
    add     a   ; x2
    add     a   ; x4
    add     a   ; x8
    ld      b,a
    ld      de,sys_ObjPalTransferBuf
    add     e
    ld      e,a

    ld      a,h
    ld      [de],a
    inc     e
    ld      a,l
    ld      [de],a
    pop     de
    ret

; Routines to initialize palette fading
; INPUT:    b = BG palette mask
;           c = OBJ palette mask
; DESTROYS: a
PalFadeInWhite:
    call    AllPalsWhite
    ld      a,%00000001
    ld      e,31
    jr      _InitFade

PalFadeOutWhite:
    ld      a,%00000101
    ld      e,0
    jr      _InitFade
    
PalFadeInBlack:
    call    AllPalsBlack
    ld      a,%00000011
    ld      e,31
    jr      _InitFade
    
PalFadeOutBlack:
    ld      a,%00000111
    ld      e,0
    ; fall through
    
_InitFade:
    ld      [sys_FadeState],a
    ld      a,e
    ld      [sys_FadeLevel],a
    ret

; Must be run during VBlank, otherwise exits
UpdatePalettes:
	ldh		a,[hConsoleType]
	cp		SYSTEM_CGB
	ret		c   ; return if not on CGB or AGB
    ldh     a,[rLCDC]
    bit     7,a         ; is LCD on?
    jr      z,.skiply
    ldh     a,[rLY]
    cp      144
    ret     c
    ; bg palettes
.skiply
    ld      a,$80
    ldh     [rBCPS],a
    ld      hl,sys_BGPalTransferBuf
    rept    2*32
        ld      a,[hl+]
        ldh     [rBCPD],a
    endr

    ; obj palettes
    ld      a,$80
    ldh     [rOCPS],a
    ld      hl,sys_ObjPalTransferBuf
    rept    2*32
        ld      a,[hl+]
        ldh     [rOCPD],a
    endr
    ret

UpdatePaletteSingle:
    ld      c,a
    ldh     a,[hConsoleType]
    cp      SYSTEM_CGB
    ret     c   ; return if not on CGB or AGB
:   ldh     a,[rSTAT]
    bit     STATB_BUSY,a ; check for VBlank or HBlank
    jr      z,:-   ; return if we're not in HBlank or VBlank

    ld      a,c
    add     a   ; x2
    add     a   ; x4
    add     a   ; x8
    or      $80
    ldh     [rBCPS],a   ; auto-increment + address specified by palette number C
    
    ld      hl,sys_PalTransferBuf
    ld      b,0
    add     hl,bc   ; x2
    add     hl,bc   ; x4
    add     hl,bc   ; x8
    ld      c,low(rBCPD)
    rept    2*4
        ld      a,[hl+]
        ld      [c],a
    endr
    

    ret

Pal_DoFade:
    ld      a,[sys_FadeState]
    bit     0,a
    ret     z
    bit     1,a
    jr      nz,.black
.white
    bit     2,a
    jr      z,_PalFadeInWhite
    jr      _PalFadeOutWhite
.black
    bit     2,a
    jr      z,_PalFadeInBlack
    jr      _PalFadeOutBlack
    
_FinishFade:
    xor     a
    ld      [sys_FadeState],a
    jr      UpdatePalsWhite ; doesn't matter which table we use here

_PalFadeInWhite:
    ld      a,[sys_FadeLevel]
    dec     a
    ld      [sys_FadeLevel],a
    jr      z,_FinishFade
    call    UpdatePalsWhite
    jp      SyncPalettes
    
_PalFadeOutWhite:
    ld      a,[sys_FadeLevel]
    inc     a
    ld      [sys_FadeLevel],a
    cp      31
    jr      z,_FinishFade
    call    UpdatePalsWhite
    jr      SyncPalettes

_PalFadeInBlack:
    ld      a,[sys_FadeLevel]
    dec     a
    ld      [sys_FadeLevel],a
    jr      z,_FinishFade
    call    UpdatePalsBlack
    jp      SyncPalettes
    
_PalFadeOutBlack:
    ld      a,[sys_FadeLevel]
    inc     a
    ld      [sys_FadeLevel],a
    cp      31
    jr      z,_FinishFade
    call    UpdatePalsBlack
    jr      SyncPalettes

UpdatePalsWhite:
    call    ConvertPals
    ld      b,(3*4)*16
    ld      hl,sys_PalBuffer
.loop
    push    hl
    ld      a,[sys_FadeLevel]
    dec     a
    ld      l,a
    ld      h,0
    add     hl,hl   ; x2
    add     hl,hl   ; x4
    add     hl,hl   ; x8
    add     hl,hl   ; x16
    add     hl,hl   ; x32
    ld      d,h
    ld      e,l
    ld      hl,PalFadeWhiteTable
    add     hl,de
    ld      d,h
    ld      e,l

    pop     hl
    ld      a,[hl]
    add     e
    ld      e,a
    jr      nc,.nocarry
    inc     d
.nocarry
    ld      a,[de]
    ld      [hl+],a
    dec     b
    jr      nz,.loop
    ret

UpdatePalsBlack:
    call    ConvertPals
    ld      b,(3*4)*16
    ld      hl,sys_PalBuffer
.loop
    push    hl
    ld      a,[sys_FadeLevel]
    dec     a
    ld      l,a
    ld      h,0
    add     hl,hl   ; x2
    add     hl,hl   ; x4
    add     hl,hl   ; x8
    add     hl,hl   ; x16
    add     hl,hl   ; x32
    ld      d,h
    ld      e,l
    ld      hl,PalFadeBlackTable
    add     hl,de
    ld      d,h
    ld      e,l

    pop     hl
    ld      a,[hl]
    add     e
    ld      e,a
    jr      nc,.nocarry
    inc     d
.nocarry
    ld      a,[de]
    ld      [hl+],a
    dec     b
    jr      nz,.loop
    ret

SyncPalettes:
    ld      hl,sys_PalBuffer
    ld      de,sys_PalTransferBuf
    ld      b,8*8
.syncloop
    push    bc
    push    hl
    push    de
    ld      a,[hl+]
    ld      e,a
    ld      a,[hl+]
    ld      b,a
    ld      a,[hl+]
    ld      c,a
    ld      a,e
    call    CombineColors
    pop     de
    ld      a,l
    ld      [de],a
    inc     e
    ld      a,h
    ld      [de],a
    inc     e
    pop     hl
    inc     hl
    inc     hl
    inc     hl
    pop     bc
    dec     b
    jr      nz,.syncloop
    ret

; INPUT:     a = palette number to load into (bit 3 for object palette)
;           hl = palette pointer
; DESTROYS:  a, b, de, hl
LoadPal:
    push    af
    push    af
    xor     a
    ld      [sys_FadeState],a
    pop     af

    and     15
    bit     3,a
    jr      nz,.obj
    add     a   ; x2
    add     a   ; x4
    add     a   ; x8
    ld      b,a
    ld      de,sys_BGPalettes
    add     e
    ld      e,a

    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    pop     af
    ret
.obj
    sub     8
    add     a   ; x2
    add     a   ; x4
    add     a   ; x8
    ld      b,a
    ld      de,sys_ObjPalettes
    add     e
    ld      e,a

    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    ld      a,[hl+]
    ld      [de],a
    inc     e
    pop     af
    ret

AllPalsWhite:
    ld      hl,sys_PalTransferBuf
    ld      b,sys_PalBuffer-sys_PalTransferBuf
    ld      a,$ff
.loop
    ld      [hl+],a
    xor     %10000000
    dec     b
    jr      nz,.loop
    ret

AllPalsBlack:
    ld      hl,sys_PalTransferBuf
    ld      b,sys_PalBuffer-sys_PalTransferBuf
    xor     a
.loop
    ld      [hl+],a
    dec     b
    jr      nz,.loop
    ret

ConvertPals:
    call    CopyPalettes
    ld      hl,sys_PalTransferBuf
    ld      de,sys_PalBuffer
    ld      b,8*8
.loop
    push    bc
    ld      a,[hl+]
    ld      b,a
    ld      a,[hl+]
    push    hl
    ld      h,a
    ld      l,b
    call    SplitColors
    ld      [de],a
    inc     de
    ld      a,b
    ld      [de],a
    inc     de
    ld      a,c
    ld      [de],a
    inc     de
    pop     hl
    pop     bc
    dec     b
    jr      nz,.loop
    ret

CopyPalettes:
    ld      hl,sys_Palettes
    ld      de,sys_PalTransferBuf
    ld      b,sys_PalBuffersEnd-sys_Palettes
    jp      Copy8

CopyPaletteSingle:
    ld      l,a
    ld      h,0
    add     hl,hl   ; x2
    add     hl,hl   ; x4
    add     hl,hl   ; x8
    ld      b,h
    ld      c,l
    ld      hl,sys_PalTransferBuf
    add     hl,bc
    ld      d,h
    ld      e,l
    ld      hl,sys_Palettes
    add     hl,bc
    ld      b,8
    jp      Copy8

; Takes a palette color and splits it into its RGB components.
; INPUT:    hl = color
; OUTPUT:    a = red
;            b = green
;            c = blue
SplitColors:
    push    de
    ld      a,l         ; GGGRRRRR
    and     %00011111   ; xxxRRRRR
    ld      e,a
    ld      a,l
    and     %11100000   ; GGGxxxxx
    swap    a           ; xxxxGGGx
    rra                 ; xxxxxGGG
    ld      b,a
    ld      a,h         ; xBBBBBGG
    and     %00000011   ; xxxxxxGG
    swap    a           ; xxGGxxxx
    rra                 ; xxxGGxxx
    or      b           ; xxxGGGGG
    ld      b,a
    ld      a,h         ; xBBBBBGG
    and     %01111100   ; xBBBBBxx
    rra                 ; xxBBBBBx
    rra                 ; xxxBBBBB
    ld      c,a
    ld      a,e
    pop     de
    ret
    
; Takes a set of RGB components and converts it to a palette color.
; INPUT:     a = red
;            b = green
;            c = blue
; OUTPUT:   hl = color
; DESTROYS:  a
CombineColors:
    ld      l,a         ; hl = ???????? xxxRRRRR
    ld      a,b         ;  a = xxxGGGGG
    and     %00000111   ;  a = xxxxxGGG
    swap    a           ;  a = xGGGxxxx
    rla                 ;  a = GGGxxxxx
    or      l           ;  a = GGGRRRRR
    ld      l,a         ; hl = ???????? GGGRRRRR
    ld      a,b         ;  a = xxxGGGGG
    and     %00011000   ;  a = xxxGGxxx
    rla                 ;  a = xxGGxxxx
    swap    a           ;  a = xxxxxxGG
    ld      h,a         ; hl = xxxxxxGG GGGRRRRR
    ld      a,c         ;  a = xxxBBBBB
    rla                 ;  a = xxBBBBBx
    rla                 ;  a = xBBBBBxx
    or      h           ;  a = xBBBBBGG
    ld      h,a         ; hl = xBBBBBGG GGGRRRRR
    ret

PalFadeBlackTable:
    db       0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    db       0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30
    db       0, 1, 2, 3, 4, 5, 6, 7, 7, 8, 9,10,11,12,13,14,15,16,17,18,19,20,21,22,22,23,24,25,26,27,28,29
    db       0, 1, 2, 3, 4, 5, 5, 6, 7, 8, 9,10,11,12,13,14,14,15,16,17,18,19,20,21,22,23,23,24,25,26,27,28
    db       0, 1, 2, 3, 3, 4, 5, 6, 7, 8, 9,10,10,11,12,13,14,15,16,17,17,18,19,20,21,22,23,24,24,25,26,27
    db       0, 1, 2, 3, 3, 4, 5, 6, 7, 8, 8, 9,10,11,12,13,13,14,15,16,17,18,18,19,20,21,22,23,23,24,25,26
    db       0, 1, 2, 2, 3, 4, 5, 6, 6, 7, 8, 9,10,10,11,12,13,14,15,15,16,17,18,19,19,20,21,22,23,23,24,25
    db       0, 1, 2, 2, 3, 4, 5, 5, 6, 7, 8, 9, 9,10,11,12,12,13,14,15,15,16,17,18,19,19,20,21,22,22,23,24
    db       0, 1, 1, 2, 3, 4, 4, 5, 6, 7, 7, 8, 9,10,10,11,12,13,13,14,15,16,16,17,18,19,19,20,21,22,22,23
    db       0, 1, 1, 2, 3, 4, 4, 5, 6, 6, 7, 8, 9, 9,10,11,11,12,13,13,14,15,16,16,17,18,18,19,20,21,21,22
    db       0, 1, 1, 2, 3, 3, 4, 5, 5, 6, 7, 7, 8, 9, 9,10,11,12,12,13,14,14,15,16,16,17,18,18,19,20,20,21
    db       0, 1, 1, 2, 3, 3, 4, 5, 5, 6, 6, 7, 8, 8, 9,10,10,11,12,12,13,14,14,15,15,16,17,17,18,19,19,20
    db       0, 1, 1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 7, 8, 9, 9,10,10,11,12,12,13,13,14,15,15,16,17,17,18,18,19
    db       0, 1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6, 7, 8, 8, 9, 9,10,10,11,12,12,13,13,14,15,15,16,16,17,17,18
    db       0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 7, 8, 8, 9, 9,10,10,11,12,12,13,13,14,14,15,15,16,16,17
    db       0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9,10,10,11,11,12,12,13,13,14,14,15,15,16
    db       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9,10,10,11,11,12,12,13,13,14,14,15,15
    db       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 9,10,10,11,11,12,12,13,13,14,14
    db       0, 0, 1, 1, 2, 2, 3, 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7, 8, 8, 8, 9, 9,10,10,10,11,11,12,12,13,13
    db       0, 0, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7, 7, 8, 8, 9, 9, 9,10,10,10,11,11,12,12
    db       0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 9, 9, 9,10,10,10,11,11
    db       0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 8, 9, 9, 9,10,10
    db       0, 0, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 8, 8, 8, 8, 9, 9
    db       0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 8, 8
    db       0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7
    db       0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 6, 6, 6
    db       0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5
    db       0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4
    db       0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3
    db       0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2
    db       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
    db       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

PalFadeWhiteTable:
    db       1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,31
    db       2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,31
    db       3, 4, 5, 6, 7, 8, 9,10,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,25,26,27,28,29,30,31,31
    db       4, 5, 6, 7, 8, 9, 9,10,11,12,13,14,15,16,17,18,18,19,20,21,22,23,24,25,26,27,27,28,29,30,31,31
    db       5, 6, 7, 8, 8, 9,10,11,12,13,14,15,15,16,17,18,19,20,21,22,22,23,24,25,26,27,28,29,29,30,31,31
    db       6, 7, 8, 9, 9,10,11,12,13,14,14,15,16,17,18,19,19,20,21,22,23,24,24,25,26,27,28,29,29,30,31,31
    db       7, 8, 9, 9,10,11,12,13,13,14,15,16,17,17,18,19,20,21,22,22,23,24,25,26,26,27,28,29,30,30,31,31
    db       8, 9,10,10,11,12,13,13,14,15,16,17,17,18,19,20,20,21,22,23,23,24,25,26,27,27,28,29,30,30,31,31
    db       9,10,10,11,12,13,13,14,15,16,16,17,18,19,19,20,21,22,22,23,24,25,25,26,27,28,28,29,30,31,31,31
    db      10,11,11,12,13,14,14,15,16,16,17,18,19,19,20,21,21,22,23,23,24,25,26,26,27,28,28,29,30,31,31,31
    db      11,12,12,13,14,14,15,16,16,17,18,18,19,20,20,21,22,23,23,24,25,25,26,27,27,28,29,29,30,31,31,31
    db      12,13,13,14,15,15,16,17,17,18,18,19,20,20,21,22,22,23,24,24,25,26,26,27,27,28,29,29,30,31,31,31
    db      13,14,14,15,15,16,17,17,18,19,19,20,20,21,22,22,23,23,24,25,25,26,26,27,28,28,29,30,30,31,31,31
    db      14,15,15,16,16,17,17,18,19,19,20,20,21,22,22,23,23,24,24,25,26,26,27,27,28,29,29,30,30,31,31,31
    db      15,16,16,17,17,18,18,19,19,20,20,21,22,22,23,23,24,24,25,25,26,27,27,28,28,29,29,30,30,31,31,31
    db      16,17,17,18,18,19,19,20,20,21,21,22,22,23,23,24,24,25,25,26,26,27,27,28,28,29,29,30,30,31,31,31
    db      17,17,18,18,19,19,20,20,21,21,22,22,23,23,24,24,25,25,26,26,27,27,28,28,29,29,30,30,31,31,31,31
    db      18,18,19,19,20,20,21,21,22,22,23,23,23,24,24,25,25,26,26,27,27,27,28,28,29,29,30,30,31,31,31,31
    db      19,19,20,20,21,21,22,22,22,23,23,24,24,24,25,25,26,26,27,27,27,28,28,29,29,29,30,30,31,31,31,31
    db      20,20,21,21,22,22,22,23,23,23,24,24,25,25,25,26,26,27,27,27,28,28,29,29,29,30,30,30,31,31,31,31
    db      21,21,22,22,22,23,23,23,24,24,25,25,25,26,26,26,27,27,27,28,28,28,29,29,30,30,30,31,31,31,31,31
    db      22,22,23,23,23,24,24,24,25,25,25,26,26,26,27,27,27,27,28,28,28,29,29,29,30,30,30,31,31,31,31,31
    db      23,23,24,24,24,24,25,25,25,26,26,26,26,27,27,27,28,28,28,29,29,29,29,30,30,30,31,31,31,31,31,31
    db      24,24,25,25,25,25,26,26,26,26,27,27,27,27,28,28,28,28,29,29,29,29,30,30,30,30,31,31,31,31,31,31
    db      25,25,25,26,26,26,26,27,27,27,27,27,28,28,28,28,29,29,29,29,30,30,30,30,30,31,31,31,31,31,31,31
    db      26,26,26,27,27,27,27,27,28,28,28,28,28,29,29,29,29,29,29,30,30,30,30,30,31,31,31,31,31,31,31,31
    db      27,27,27,27,28,28,28,28,28,28,29,29,29,29,29,29,30,30,30,30,30,30,31,31,31,31,31,31,31,31,31,31
    db      28,28,28,28,29,29,29,29,29,29,29,29,30,30,30,30,30,30,30,30,31,31,31,31,31,31,31,31,31,31,31,31
    db      29,29,29,29,29,29,30,30,30,30,30,30,30,30,30,30,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31
    db      30,30,30,30,30,30,30,30,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31
    db      31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31
