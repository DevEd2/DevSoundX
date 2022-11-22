; ======================================================================
; Demonstration program for DevSound X
; Copyright © 2022 DevEd
;
; Permission is hereby granted, free of charge, to any person obtaining
; a copy of this software and associated documentation files (the
; “Software”), to deal in the Software without restriction, including
; without limitation the rights to use, copy, modify, merge, publish,
; distribute, sublicense, and/or sell copies of the Software, and to
; permit persons to whom the Software is furnished to do so, subject to
; the following conditions:
;
; The above copyright notice and this permission notice shall be
; included in all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
; TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
; ======================================================================

; Global constants

SYSTEM_DMG  = 0 ; Game Boy
SYSTEM_MGB  = 1 ; Game Boy Pocket, Game Boy Light
SYSTEM_SGB  = 2 ; Super Game Boy
SYSTEM_SGB2 = 3 ; Super Game Boy 2
SYSTEM_CGB  = 4 ; Game Boy Color
SYSTEM_AGB  = 5 ; Game Boy Advance, Game Boy Advance SP, Game Boy Player

BTN_A       = 0
BTN_B       = 1
BTN_SELECT  = 2
BTN_START   = 3
BTN_RIGHT   = 4
BTN_LEFT    = 5
BTN_UP      = 6
BTN_DOWN    = 7

_A          = 1 << BTN_A
_B          = 1 << BTN_B
_START      = 1 << BTN_START
_SELECT     = 1 << BTN_SELECT
_RIGHT      = 1 << BTN_RIGHT
_LEFT       = 1 << BTN_LEFT
_UP         = 1 << BTN_UP
_DOWN       = 1 << BTN_DOWN

; ======================================================================

; Macro definitions

dbw:        macro
    db      \1
    dw      \2
    endm

dstr:       macro
    db      \1,0
    db      \3
    db      \2
    endm
    
wait_vram:  macro
.\@:
    ldh     a,[rSTAT]
    and     STATF_BUSY
    jr      nz,.\@
    endm

; ======================================================================

; Hardware defines
include "hardware.inc/hardware.inc"

; RAM defines
section "Player variables",wram0

MenuRAM:

SongNameBuffer:     ds  20
AuthorBuffer:       ds  20
CurrentRaster:      db
MaxRaster:          db
MinRaster:          db

MenuCharCounts:     ds  12
ScreenBuffer:       ds  32*32

RasterBufferSCX:    ds  SCRN_Y
RasterBufferSCY:    ds  SCRN_Y

MenuRAM_End:

section "System variables",hram

hConsoleType:       db  ; 0 = DMG, 1 = MGB, 2 = SGB, 3 = SGB2, 4 = GBC, 5 = GBA
hCurrentFrame:      db
hHeldButtons:       db  ; buttons held on this frame
hPressedButtons:    db  ; newly pressed buttons on this frame
hReleasedButtons:   db  ; newly released buttons on this frame
hEnableInput:       db
hTempAF:            dw
hTempBC:            dw
hTempDE:            dw
hTempHL:            dw
hTempSP:            dw
hVBlank:            db
hLCDC:              db
hTimer:             db
hSerial:            db
hJoypad:            db
hSoftResetTimer:    db
hROMB0:             db

; ================================================================

section "Reset $00",rom0[$00]
_Bankswitch:
    ld      a,b
    ld      [rROMB0],a
    ldh     [hROMB0],a
    ret
    
section "Reset $08",rom0[$08]
Reset08:
    ret

section "Reset $10",rom0[$10]
Reset10:
    ret

section "Reset $18",rom0[$18]
Reset18:
    ret

section "Reset $20",rom0[$20]
Reset20:
    ret

section "Reset $28",rom0[$28]
Reset28:
    ret

section "Reset $30",rom0[$30]
Reset30:
    ret

section "Reset $38",rom0[$38]
_Trap:
    ld      b,b
    jr      @

; ================================================================

section "VBlank interrupt vector",rom0[$40]
IRQ_VBlank: jp  DoVBlank

section "LCD status interrupt vector",rom0[$48]
IRQ_LCDC:   jp  DoLCDC

section "Timer interrupt vector",rom0[$50]
IRQ_Timer:  reti

section "Serial interrupt vector",rom0[$58]
IRQ_Serial: reti

section "Joypad interrupt vector",rom0[$60]
IRQ_Joypad: reti

; ================================================================

section "Cartridge header",rom0[$100]

Header_EntryPoint:  
    jr  ProgramStart                                    ;
    ds  2,0                                             ; padding
Header_NintendoLogo:    ds  48,0                        ; handled by RGBFIX
Header_Title:           db  "DEVSOUND X"                ; must be 15 chars or less!
                        ds  (Header_Title + 15) - @,0   ; padding
Header_CGBSupport:      db  CART_COMPATIBLE_DMG_GBC     ;
Header_NewLicenseCode:  dw                              ; not needed
Header_SGBSupport:      db  $03                         ; $03 = enable SGB features (requires old license code to be set to $33)
Header_CartridgeType:   db  CART_ROM_MBC5               ; 
Header_ROMSize:         ds  1                           ; handled by RGBFIX
Header_RAMSize:         db  0                           ; not used
Header_DestinationCode: db  1                           ; 0 = Japan, 1 = not Japan
Header_OldLicenseCode:  db  $33                         ; must be $33 for SGB support
Header_Revision:        db  -1                          ; revision (-1 for prerelease builds)
Header_Checksum:        db  0                           ; handled by RGBFix
Header_ROMChecksum:     dw  0                           ; handled by RGBFix

; ================================================================

ProgramStart:
    di
    ld      sp,$e000
    
    ; determine console type
    ; dmg0:     a = $01, b = $ff, c = $13
    ; dmg:      a = $01, b = $00, c = $13
    ; mgb/mgl:  a = $ff, b = $00, c = $13
    ; sgb:      a = $01, b = $00, c = $14
    ; sgb2:     a = $ff, b = $00, c = $14
    ; cgb:      a = $11, b = $00
    ; agb:      a = $11, b = $01
    ; reset:    a = $ed
        
    cp      $ed             ; is this a soft reset?
    jr      z,.skip         ; if yes, skip
    cp      BOOTUP_A_CGB
    jr      z,.color
.mono
    dec     a               ; a = 0 on DMG/SGB, a = $FE on MGB/MGL/SGB2
    jr      z,:+
    ld      a,SYSTEM_MGB
:   ld      b,a
    ld      a,c
    sub     $13             ; a = 0 on DMG/MGB/MGL, a = 1 on SGB/SGB2
    jr      z,:+
    ld      a,b
    add     SYSTEM_SGB
    jr      .setmodel
:   ld      a,b
    jr      .setmodel
.color
    call    DoubleSpeed
    ld      a,SYSTEM_CGB
    add     b
.setmodel
    ldh     [hConsoleType],a
.skip
    push    af
    xor     a
    ldh     [rSCX],a
    ldh     [rSCY],a
    ldh     [rNR52],a   ; disable sound output
    
    ldh     a,[hConsoleType]
    cp      SYSTEM_CGB
    jr      nc,.gbcboot
    
    ld      a,IEF_VBLANK
    ldh     [rIE],a
    ei
    
    ld      b,3
    pop     af
    cp      $ed
    jr      z,.softreset
.hardreset
    ld      hl,.colors_hardreset
    jr      :+
.softreset
    ld      hl,.colors_softreset
:   push    hl
    ld      a,b
    add     l
    ld      l,a
    ld      a,[hl]
    ldh     [rBGP],a
    pop     hl
    ld      a,8
    call    WaitFrames
    dec     b
    jr      nz,:-
    jr      :++

.gbcboot
    ld      a,IEF_VBLANK
    ldh     [rIE],a
    ei
    pop     af
    cp      $ed
    jr      nz,:++
    call    PalFadeOutWhite
:   halt
    call    Pal_DoFade
    call    UpdatePalettes
    ld      a,[sys_FadeState]
    bit     0,a
    jr      nz,:-
    jr      :+    

.colors_hardreset
    db      %00000000
    db      %01010100
    db      %10101000
    db      %11111100
.colors_softreset
    db      %00000000
    db      %00000001
    db      %00000110
    db      %00011011

:   di
.skip2
    xor     a
    ldh     [rLCDC],a
    ; clear OAM
    ld      bc,$7e00 | low(hConsoleType+1)
    xor     a
:   ld      [c],a
    inc     c
    dec     b
    jr      nz,:-
    ; clear menu RAM
    ld      hl,MenuRAM
    ld      bc,MenuRAM_End-MenuRAM
:   xor     a
    ld      [hl+],a
    dec     bc
    ld      a,b
    or      c
    jr      nz,:-
    
    ; clear tilemap area
    ld      a,$80
    ld      hl,_SCRN0
    ld      bc,_SCRN1-_SCRN0
    call    Fill16
    
    ; Initialize screen
    ld      b,bank(GFXData)
    rst     _Bankswitch
    
    ldh     a,[hConsoleType]
    cp      SYSTEM_CGB
    jr      c,.notgbc
    ld      hl,LogoTiles_Color
    ld      de,_VRAM
    ld      bc,LogoTiles_Color.end-LogoTiles_Color
    call    Copy16
    
    ld      hl,LogoMap_Color
    ld      de,_SCRN0
    ld      bc,$1406
    call    LoadTilemapColor
    
    ld      hl,LogoPal_Color
    xor     a
    call    LoadPal
    ld      a,1
    call    LoadPal
    ld      a,2
    call    LoadPal
    ld      a,3
    call    LoadPal
    ld      a,4
    call    LoadPal
    ld      a,5
    call    LoadPal
    ld      a,6
    call    LoadPal
    ld      a,7
    call    LoadPal
    call    CopyPalettes
    
    jr      .continue
.notgbc
    ld      hl,LogoTiles_Mono
    ld      de,_VRAM
    ld      bc,LogoTiles_Mono.end-LogoTiles_Mono
    call    Copy16
    
    ld      hl,LogoMap_Mono
    ld      de,_SCRN0
    ld      bc,$1406
    call    LoadTilemap
.continue
    
    ; load blank tile
    ; (TODO: Replace with font)
    xor     a
    ldh     [rVBK],a
    ld      a,%11111111
    ld      hl,_VRAM + ($80 * 16)
    ld      b,8
:   ld      [hl+],a
    cpl
    ld      [hl+],a
    cpl
    dec     b
    jr      nz,:-
    
    ld      a,%00011011
    ldh     [rBGP],a
    
    ld      a,%10010001
    ldh     [rLCDC],a
    ld      a,IEF_VBLANK
    ldh     [rIE],a
    ei
    
    ld      b,bank(DevSoundX)
    rst     _Bankswitch
    xor     a
:   call    DSX_Init
    ld      hl,DSX_TestSong
    call    DSX_PlaySong
    
    ld      a,-1
    ld      [MinRaster],a
    
    ld      a,1
    ldh     [hEnableInput],a
    
;   ld      hl,$0100
;   call    SGB_SendGFX
    
;   ld      a,PCT_TRN << 3 | 1
;   ld      b,0
;   call    SGB_SendAB
    
MainLoop:
    ld      hl,rLY
    xor     a
:   cp      [hl]
    jr      nz,:-
    call    DevSoundX_Update
    ld      a,[hl]
    ld      [CurrentRaster],a
    ld      e,a
    ld      a,[MaxRaster]
    cp      e
    jr      nc,:+
    ld      a,e
    ld      [MaxRaster],a
:   ld      a,[MinRaster]
    cp      e
    jr      c,:+
    ld      a,e
    ld      [MinRaster],a
:;  ld      a,[AverageRaster]
;   and     a
;   jr      z,:+
;   add     e
;   rra
;   jr      :++
;:  ld      a,e
;:  ld      [AverageRaster],a

    call    WaitVBlank
    jr      MainLoop

; INPUT:    (none)
; OUTPUT:   zero flag + A=0 on SGB, zero flag + A=$FF on SGB2
; DESTROYS: -- -- -- --
CheckSGB:
    ld      a,[hConsoleType]
    sub     SYSTEM_SGB
    ret     z
    dec     a
    ret

; INPUT:    a = number of frames
; OUTPUT:   (none)
; DESTROYS: af -- -- --
WaitFrames:
    halt
    dec     a
    jr      nz,WaitFrames
    ret

; INPUT:    bc = number of frames
; OUTPUT:   (none)
; DESTROYS: af bc -- --
WaitFrames16:
    halt
    dec     bc
    ld      a,b
    or      c
    jr      nz,WaitFrames
    ret

; Switches double speed mode on.
; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af -- -- --
DoubleSpeed:
    ldh a,[rKEY1]
    bit 7,a         ; already in double speed?
    ret nz          ; if yes, return
    ld  a,%00110000
    ldh [rP1],a
    xor %00110001   ; a = %00000001
    ldh [rKEY1],a   ; prepare speed switch
    stop
    ret

; ================================================================

; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: -- -- -- --
DoVBlank:
    push    af
    push    bc
    push    de
    push    hl
    ld      a,1
    ldh     [hVBlank],a
    
    call    UpdatePalettes
    
    ldh     a,[hEnableInput]
    and     a
    jr      z,:+
    ldh     a,[hHeldButtons]
    ld      c,a
    ld      a,P1F_5
    ldh     [rP1],a
    ldh     a,[rP1]
    ldh     a,[rP1]
    cpl
    and     $f
    swap    a
    ld      b,a
    
    ld      a,P1F_4
    ldh     [rP1],a
    ldh     a,[rP1]
    ldh     a,[rP1]
    ldh     a,[rP1]
    ldh     a,[rP1]
    ldh     a,[rP1]
    ldh     a,[rP1]
    cpl
    and     $f
    or      b
    ld      b,a
    
    ldh     a,[hHeldButtons]
    xor     b
    and     b
    ldh     [hPressedButtons],a    ; store buttons pressed this frame
    ld      e,a
    ld      a,b
    ldh     [hHeldButtons],a     ; store held buttons
    xor     c
    xor     e
    ldh     [hReleasedButtons],a  ; store buttons released this frame
    ld      a,P1F_5|P1F_4
    ldh     [rP1],a
    
    ; soft reset sequence
    ldh     a,[hHeldButtons]
    cp      _A | _B | _START | _SELECT
    jr      nz,:+
    
    ld      hl,hSoftResetTimer
    inc     [hl]
    ld      a,60
    cp      [hl]
    jr      nz,:+
    ld      a,$ed
    jp      z,ProgramStart
    ld      [hl],0
:    
    pop     hl
    pop     de
    pop     bc
    pop     af
    reti

; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: -- -- -- --
DoLCDC:
    push    af
    ld      a,1
    ldh     [hLCDC],a
    
    pop     hl
    pop     bc
    pop     af
    reti

; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af -- -- --
DoTimer:
    push    af
    ld      a,1
    ldh     [hTimer],a
    pop     af
    ret

; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af -- -- --
WaitVBlank:
    halt
    ldh     a,[hVBlank]
    and     a
    jr      z,WaitVBlank
    xor     a
    ldh     [hVBlank],a
    ret

; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af -- -- --
WaitLCDC:
    halt
    ldh     a,[hLCDC]
    and     a
    jr      z,WaitLCDC
    xor     a
    ldh     [hLCDC],a
    ret

; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af -- -- --
WaitTimer:
    halt
    ldh     a,[hTimer]
    and     a
    jr      z,WaitTimer
    xor     a
    ldh     [hTimer],a
    ret

; ================================================================

; INPUT:    b = bank to switch to
; OUTPUT:   (none)
; DESTROYS: a- -- -- --
DoBankswitch:
    ld      a,b
    ld      [rROMB0],a
    ldh     [hROMB0],a
    ret

; INPUT:    a = fill value, hl = destination, b = length
; OUTPUT:   (none)
; DESTROYS: -f b- -- hl
Fill8:
:   ld      [hl+],a
    dec     b
    jr      nz,:-
    ret

; INPUT:    a = fill value, hl = destination, bc = length
; OUTPUT:   (none)
; DESTROYS: af bc -e hl
Fill16:
    ld      e,a
:   ld      [hl],e
    inc     hl
    dec     bc
    ld      a,b
    or      c
    jr      nz,:-
    ret

; INPUT:    hl = source, de = destination, b = size
; OUTPUT:   (none)
; DESTROYS: af b- de hl
Copy8:
:   ld      a,[hl+]
    ld      [de],a
    inc     de
    dec     b
    jr      nz,:-
    ret

; INPUT:    hl = source, de = destination, bc = size
; OUTPUT:   (none)
; DESTROYS: af bc de hl
Copy16:
:   ld      a,[hl+]
    ld      [de],a
    inc     de
    dec     bc
    ld      a,b
    or      c
    jr      nz,:-
    ret

; INPUT:    hl = source, de = destination, b = width (in tiles), c = height (in tiles)
; OUTPUT:   (none)
; DESTROYS: af bc de hl
LoadTilemap:
:   push    de
:   ld      a,[hl+]
    ld      [de],a
    inc     de
    dec     b
    jr      nz,:-
    pop     de
    push    hl
    ld      hl,$0020
    add     hl,de
    ld      d,h
    ld      e,l
    pop     hl
    ld      b,$14
    dec     c
    jr      nz,:--
    ret

; INPUT:    hl = source, de = destination, b = width (in tiles), c = height (in tiles)
; OUTPUT:   (none)
; DESTROYS: af bc de hl
LoadTilemapColor:
:   push    de
:   xor     a
    ldh     [rVBK],a
    ld      a,[hl+]
    ld      [de],a
    ld      a,1
    ldh     [rVBK],a
    ld      a,[hl+]
    ld      [de],a
    inc     de
    dec     b
    jr      nz,:-
    pop     de
    push    hl
    ld      hl,$0020
    add     hl,de
    ld      d,h
    ld      e,l
    pop     hl
    ld      b,$14
    dec     c
    jr      nz,:--
    ret

; INPUT:    a = line number
;           hl = string pointer
; OUTPUT:   (none)
; DESTROYS: af b- de hl
PrintString:
    push    hl
    push    hl
    ld      de,_SCRN0
    ld      a,l
    ld      h,0
    add     hl,hl   ; x2
    add     hl,hl   ; x4
    add     hl,hl   ; x8
    add     hl,hl   ; x16
    add     hl,hl   ; x32
    ld      a,l
    add     6
    ld      l,a
    jr      nc,:+
    inc     h
:   pop     hl
    ld      b,0
.loop
    ld      a,[hl+]
    sub     32
    push    af
    wait_vram
    pop     af
    ld      [de],a
    inc     de
    inc     b
    and     a
    jr      nz,.loop
    ld      b,[hl]
    pop     af
    ld      hl,MenuCharCounts
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      [hl],b
    ret

MainScreenText:
    dw      .0,.1,DummyStr,.2,.3
.0  dstr    "- DevSound X -",1,@-.0
.1  dstr    "Demo program",1,@-.1
.2  dstr    "Press Select to",1,@-.2
.3  dstr    "switch screens",1,@-.3

NowPlayingText:
    dw      .0,DummyStr,.1,.2
.0  dstr    "- Now playing -",1,@-.0
.1  dstr    "[Song name here]",0,@-.1
.2  dstr    "by [Author here]",0,,@-.2

RastertimeDisplayText:
    dw      .0,DummyStr,.1,.2,.3,.4
.0  dstr    "- Raster time -",0,@-.0
.1  dstr    "Current:       ???",1,@-.1
.2  dstr    "Max:           ???",1,@-.2
.3  dstr    "Min:           ???",1,@-.3
.4  dstr    "Average:       ???",1,@-.4

CreditsText:
    dw      .0,DummyStr
    dw      .1,.2,.3,DummyStr
    dw      .4,.5,DummyStr
    dw      .6,.7,DummyStr
    dw      .8,.9,.10,.11,.12,.13,DummyStr
.0  dstr    "- CREDITS -",0,@-.0
.1  dstr    strcat("DevSound X v",strcat(strsub("{d:__UTC_YEAR__}",3,2),"{d:__UTC_MONTH__}{d:__UTC_DAY__}")) ,1,@-.1
.2  dstr    "Built {d:__UTC_HOUR__}:{d:__UTC_MINUTE__}:{d:__UTC_SECOND__} UTC",1,@-.2
.3  dstr    "RGBDS version {d:__RGBDS_MAJOR__}.{d:__RGBDS_MINOR__}.{d:__RGBDS_PATCH__}",1,@-.3
.4  dstr    "Programming:",1,@-.4
.5  dstr    "DevEd",2,@-.5
.6  dstr    "Logo:",1,@-.6
.7  dstr    "Twoflower",2,@-.7
.8  dstr    "Special thanks:",1,@-.8
.9  dstr    "Beware",2,@-.9
.10 dstr    "Gunpei Yokoi",2,@-.10
.11 dstr    "Hirokazu Tanaka",2,@-.11
.12 dstr    "Tildearrow",2,@-.12
.13 dstr    "Rilden",2,@-.13
    
DummyStr:   dstr "",0,@-DummyStr

; ================================================================

include "SGB.asm"
include "PerFade.asm"

; ================================================================

include "DevSoundX.asm"

; ================================================================

section "GFX data",rom0
GFXData:
LogoTiles_Mono:
    incbin  "GFX/LogoMono.2bpp"
.end

LogoTiles_Color:
    incbin  "GFX/LogoColor.2bpp"
.end

LogoTiles_SGB:
    incbin  "GFX/LogoSGB.2bpp"
.end

LogoMap_Mono:
    incbin  "GFX/LogoMono.til"
.end

LogoMap_Color:
    incbin  "GFX/LogoColor.til"
.end

LogoMap_SGB:
    incbin  "GFX/LogoSGB.til"
.end

LogoPal_Color:
    incbin  "GFX/LogoColor.pal"
.end

LogoPal_SGB:
    incbin  "GFX/LogoSGB.pal"
.end

Pal_Text:
    dw      $0000,$4210,$6318,$7fff
