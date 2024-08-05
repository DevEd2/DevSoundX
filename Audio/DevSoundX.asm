; ================================================================
; DevSound X sound driver for Game Boy
; Copyright (c) 2022 DevEd
; 
; Permission is hereby granted, free of charge, to any person obtaining
; a copy of this software and associated documentation files (the
; "Software"), to deal in the Software without restriction, including
; without limitation the rights to use, copy, modify, merge, publish,
; distribute, sublicense, and/or sell copies of the Software, and to
; permit persons to whom the Software is furnished to do so, subject to
; the following conditions:
; 
; The above copyright notice and this permission notice shall be included
; in all copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
; TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
; ================================================================

section "DevSound X RAM defines",wram0

def sizeof_DSX_ChannelStruct = 0

macro DSX_ChannelStruct
DSX_CH\1_Start:
DSX_CH\1_SeqPtr:            dw
DSX_CH\1_ReturnPtr:         dw
DSX_CH\1_VolPtr:            dw
DSX_CH\1_ArpPtr:            dw
DSX_CH\1_NoisePtr:
DSX_CH\1_WavePtr:   
DSX_CH\1_PulsePtr:          dw
if \1 != 4
DSX_CH\1_PitchPtr:          dw
endc
DSX_CH\1_LoopCount:         db
DSX_CH\1_VolDelay:          db
DSX_CH\1_ArpDelay:          db
DSX_CH\1_NoiseDelay:
DSX_CH\1_WaveDelay:
DSX_CH\1_PulseDelay:        db
if \1 != 4
DSX_CH\1_PitchDelay:        db
endc
DSX_CH\1_Tick:              db
DSX_CH\1_Note:              db
DSX_CH\1_Timer:             db
DSX_CH\1_ArpTranspose:      db
if \1 != 4
DSX_CH\1_PitchMode:         db  ; 0 = normal, 1 = slide up, 2 = slide down, 3 = portamento, bit 7 = monty flag
DSX_CH\1_VibOffset:         dw
DSX_CH\1_SlideOffset:       dw
DSX_CH\1_SlideTarget:       dw
DSX_CH\1_SlideSpeed:        db
DSX_CH\1_NoteTarget:        db
DSX_CH\1_Transpose:         db
endc
DSX_CH\1_VolResetPtr:       dw
DSX_CH\1_VolReleasePtr:     dw
DSX_CH\1_ArpResetPtr:       dw
DSX_CH\1_ArpReleasePtr:     dw
DSX_CH\1_WaveResetPtr:
DSX_CH\1_PulseResetPtr:     dw
DSX_CH\1_WaveReleasePtr:
DSX_CH\1_PulseReleasePtr:   dw
if \1 != 4
DSX_CH\1_PitchResetPtr:     dw
DSX_CH\1_PitchReleasePtr:   dw
endc
if \1 == 3
DSX_CH\1_SamplePointer:     dw
DSX_CH\1_SampleLength:      dw
endc
if \1 == 3
DSX_CH\1_NRX0:              db
else
DSX_CH\1_ChannelVol:        db
endc
DSX_CH\1_EchoPos:           db
DSX_CH\1_FirstNote:         db
DSX_CH\1_CurrentWave:
DSX_CH\1_NRX1:              db
DSX_CH\1_CurrentNRX2:       db
DSX_CH\1_PreviousWave:
DSX_CH\1_PreviousNRX2:      db
DSX_CH\1_NRX3:              db
DSX_CH\1_NRX4:              db
DSX_CH\1_End:
endm

DSX_RAMStart:

DSX_MusicPlaying:       db
DSX_GlobalTick:         db
DSX_ChannelFlags:       db  ; upper 4 bits = sfx, lower 4 bits = music
def DSX_MusicMask           = %00001111

DSX_MusicTick:          db  ; increments by 1 each speed tick
DSX_MusicSpeedTick:     db
DSX_MusicSpeed1:        db  ; used on odd speed ticks
DSX_MusicSpeed2:        db  ; used on even speed ticks

DSX_GlobalTranspose:    db

DSX_FreqTablePtr:       dw

DSX_MusicRAM:
    DSX_ChannelStruct       1
    DSX_ChannelStruct       2
    DSX_ChannelStruct       3
    DSX_ChannelStruct       4

DSX_CH1_EchoBuffer:     ds 4
DSX_CH2_EchoBuffer:     ds 4
DSX_CH3_EchoBuffer:     ds 4
DSX_CH4_EchoBuffer:     ds 4
.end
def sizeof_DSX_MusicRAM = .end-DSX_MusicRAM

DSX_RAMEnd:

; ================================================================

; Pitch constants

def PITCH_MODE_NONE         = 0
def PITCH_MODE_SLIDE_UP     = 1
def PITCH_MODE_SLIDE_DOWN   = 2
def PITCH_MODE_PORTAMENTO   = 3

def PITCH_BIT_MONTY         = 7

def PITCH_MODE_MASK         = %00001111
def PITCH_BIT_MASK          = %11110000

; ================================================================

; Command defines + constants

def seq_wait    = $fd
def seq_loop    = $fe
def seq_end     = $ff
; pitch macros use signed int8
def pitch_loop  = $80
def pitch_end   = $7f

; notes
def C_  =   0
def C#  =   1
def D_  =   2
def D#  =   3
def E_  =   4
def F_  =   5
def F#  =   6
def G_  =   7
def G#  =   8
def A_  =   9
def A#  =   10
def B_  =   11

; PARAMETERS: [length]
macro rest
    db      $7f,\1
    endm

macro wait
    db      $7e,\1
    endm

macro release
    db      $7d,\1
    endm

; PARAMETERS: [note, octave, length]
macro note
    db      \1 + (12 * (\2 - 2)), \3
    endm
    
; PARAMETERS: [length]
macro sfix
    note    C_,2,\1
    endm

; PARAMETERS: [instrument, length]
macro sfixins
    sound_instrument \1
    note    C_,2,\2
    endm

; Specifies instrument to use for current channel (Any channel)
; PARAMETERS: [pointer to instrument data]
macro sound_instrument
    db      $80
    dw      \1
    endm

; Jump to another section of sound data (Any channel)
; PARAMETERS: [pointer to jump to]
macro sound_jump
    db      $81
    dw      \1
    endm

; Loop a block of sound data a specified number of times (Any channel)
; PARAMETERS: [number of loops], [return pointer]
macro sound_loop
    db      $82
    db      \1
    dw      \2
    endm

; Call a subsection of sound data (Any channel)
; PARAMETERS: [pointer of section to call]
; WARNING: Subsections cannot be nested!
macro sound_call
    db      $83
    dw      \1
    endm

; Return from a called sound data section (Any channel)
; PARAMETERS: none
; WARNING: Do not use outside of a subsection!
macro sound_ret
    db      $84
    endm

; Slide up (CH1, CH2, CH3)
; PARAMETERS: [speed]
macro sound_slide_up
    db      $85
    db      \1
    endm

; Slide down (CH1, CH2, CH3)
; PARAMETERS: [speed]
macro sound_slide_down
    db      $86
    db      \1
    endm

; Slide to a given note (CH1, CH2, CH3)
; PARAMETERS: [speed]
macro sound_portamento
    db      $87
    db      \1
    endm

; Toggle "monty mode" (only applies pitch slides on even ticks) (CH1, CH2, CH3)
; PARAMETERS: none
macro sound_toggle_monty
    db      $88
    endm

; Play a 1920hz sample (CH3 only)
; PARAMETERS: [pointer, length]
macro sound_sample
    db      $89
    dw      \1
    db      \2
    endm

; Set the volume for the current channel (CH1, CH2, CH4)
; PARAMETERS: [volume (0 - F)]
macro sound_volume
    db      $8a
    db      \1
    endm

; Transpose the CURRENT channel up or down. (CH1, CH2, CH3)
; PARAMETERS: [number of semitones to transpose by]
macro sound_transpose
	db		$8b
	db		\1
	endm

; Transpose ALL channels up or down. (Any channel)
; PARAMETERS: [number of semitones to transpose by]
; NOTE: Can be used on CH4, but does not affect it.
; WARNING: Will override any existing per-channel transposition!
macro sound_transpose_global
	db		$8c
	db		\1
	endm

; Reset the transposition for the CURRENT channel. (CH1, CH2, CH3)
; PARAMETERS: [none]
macro sound_reset_transpose
	db		$8d
	endm

; Reset the transposition for ALL channels. (Any channel)
; PARAMETERS: [none]
; NOTE: Can be used on CH4, but does not affect it.
macro sound_reset_transpose_global
	db		$8e
	endm

; Set the arpeggio pointer. (Any channel)
; PARAMETERS: [pointer]
macro sound_set_arp_ptr
    db      $8f
    dw      \1
    endm

; Set the song speed. (Any channel)
; PARAMETERS [speed 1, speed 2]
macro sound_set_speed
    db      $90
    db      \1,\2
    endm

; Marks the end of the sound data for the current channel. (Any channel)
; PARAMETERS: none
macro sound_end
    db      $ff
endm

; ================================================================

section "DevSound X",romx[$4000]

DevSoundX:
DSX_Init:       jp  DevSoundX_Init
DSX_PlaySong:   jp  DevSoundX_PlaySong
DSX_StopMusic:  jp  DevSoundX_StopMusic
DSX_Update:     jp  DevSoundX_Update
DSX_Thumbprint:
    db      "DevSound X sound driver by DevEd | deved8@gmail.com"

; ================

; Sound initialization routine.
; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af bc hl
DevSoundX_Init:
    ld      hl,rNR52
    ld      [hl],AUDENA_OFF
    ld      [hl],AUDENA_ON
    dec     l
    ld      [hl],%11111111
    dec     l
    ld      [hl],$77

    ; initialize envelope registers for zombie mode
    ld      a,$f0
    ldh     [rNR12],a
    ldh     [rNR22],a
    ldh     [rNR42],a
    and		$80
    ldh     [rNR14],a
    ldh     [rNR24],a
    ldh     [rNR44],a
    ld      a,$18
    ldh     [rNR12],a
    ldh     [rNR22],a
    ldh     [rNR42],a
    
    ; load initial waveform
    ld      hl,DSX_DefaultWave
    call    DevSoundX_LoadWave
    
    ; initialize memory
    ld      hl,DSX_RAMStart
    ld      bc,DSX_RAMEnd-DSX_RAMStart
:   xor     a
    ld      [hl+],a
    dec     bc
    ld      a,b
    or      c
    jr      nz,:-
    ; initialize pointers
    ld      a,low(DSX_DummyChannel)
    ld      [DSX_CH1_SeqPtr],a
    ld      [DSX_CH2_SeqPtr],a
    ld      [DSX_CH3_SeqPtr],a
    ld      [DSX_CH4_SeqPtr],a
    ld      [DSX_CH1_VolPtr],a
    ld      [DSX_CH2_VolPtr],a
    ld      [DSX_CH3_VolPtr],a
    ld      [DSX_CH4_VolPtr],a
    ld      [DSX_CH1_PitchPtr],a
    ld      [DSX_CH2_PitchPtr],a
    ld      [DSX_CH3_PitchPtr],a
    ld      [DSX_CH1_VolResetPtr],a
    ld      [DSX_CH2_VolResetPtr],a
    ld      [DSX_CH3_VolResetPtr],a
    ld      [DSX_CH4_VolResetPtr],a
    ld      [DSX_CH1_PitchResetPtr],a
    ld      [DSX_CH2_PitchResetPtr],a
    ld      [DSX_CH3_PitchResetPtr],a
    ld      a,high(DSX_DummyChannel)
    ld      [DSX_CH1_SeqPtr+1],a
    ld      [DSX_CH2_SeqPtr+1],a
    ld      [DSX_CH3_SeqPtr+1],a
    ld      [DSX_CH4_SeqPtr+1],a
    ld      [DSX_CH1_VolPtr+1],a
    ld      [DSX_CH2_VolPtr+1],a
    ld      [DSX_CH3_VolPtr+1],a
    ld      [DSX_CH4_VolPtr+1],a
    ld      [DSX_CH1_PitchPtr+1],a
    ld      [DSX_CH2_PitchPtr+1],a
    ld      [DSX_CH3_PitchPtr+1],a
    ld      [DSX_CH1_VolResetPtr+1],a
    ld      [DSX_CH2_VolResetPtr+1],a
    ld      [DSX_CH3_VolResetPtr+1],a
    ld      [DSX_CH4_VolResetPtr+1],a
    ld      [DSX_CH1_PitchResetPtr+1],a
    ld      [DSX_CH2_PitchResetPtr+1],a
    ld      [DSX_CH3_PitchResetPtr+1],a
    
    ld      a,1
    ld      [DSX_MusicSpeedTick],a
    ld      a,$f
    ld      [DSX_CH1_ChannelVol],a
    ld      [DSX_CH2_ChannelVol],a
    ld      [DSX_CH4_ChannelVol],a
    
	; set frequency table pointer
    ld      a,low(DSX_FreqTable)
    ld      hl,DSX_FreqTablePtr
    ld      [hl+],a
    ld      [hl],high(DSX_FreqTable)  
    ret

; ================

; INPUT:    hl = song pointer
; OUTPUT:   (none)
; DESTROYS: af hl
DevSoundX_PlaySong:
    ld      a,[hl+]
    ld      [DSX_MusicSpeed1],a
    ld      a,[hl+]
    ld      [DSX_MusicSpeed2],a

    ld      a,[hl+]
    ld      [DSX_CH1_SeqPtr],a
    ld      a,[hl+]
    ld      [DSX_CH1_SeqPtr+1],a

    ld      a,[hl+]
    ld      [DSX_CH2_SeqPtr],a
    ld      a,[hl+]
    ld      [DSX_CH2_SeqPtr+1],a

    ld      a,[hl+]
    ld      [DSX_CH3_SeqPtr],a
    ld      a,[hl+]
    ld      [DSX_CH3_SeqPtr+1],a
    
    ld      a,[hl+]
    ld      [DSX_CH4_SeqPtr],a
    ld      a,[hl]
    ld      [DSX_CH4_SeqPtr+1],a
:   ld      a,DSX_MusicMask
    ld      [DSX_ChannelFlags],a
    xor     a
    ld      [DSX_CH1_Tick],a
    ld      [DSX_CH2_Tick],a
    ld      [DSX_CH3_Tick],a
    ld      [DSX_CH4_Tick],a
    ld      [DSX_MusicTick],a
    ld      [DSX_CH1_PitchMode],a
    ld      [DSX_CH2_PitchMode],a
    ld      [DSX_CH3_PitchMode],a
    ld      [DSX_CH1_SlideOffset],a
    ld      [DSX_CH2_SlideOffset],a
    ld      [DSX_CH3_SlideOffset],a
    ld      [DSX_CH1_SlideTarget],a
    ld      [DSX_CH2_SlideTarget],a
    ld      [DSX_CH3_SlideTarget],a
    inc     a
    ld      [DSX_CH1_Timer],a
    ld      [DSX_CH2_Timer],a
    ld      [DSX_CH3_Timer],a
    ld      [DSX_CH4_Timer],a
    ld      [DSX_MusicSpeedTick],a
    ld      [DSX_MusicPlaying],a
    ld      a,15
    ld      [DSX_CH1_ChannelVol],a
    ld      [DSX_CH2_ChannelVol],a
    ld      [DSX_CH4_ChannelVol],a
    ret

; ================

; Stop music playback.
; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af b hl
DevSoundX_StopMusic:
    xor     a
    ld      [DSX_MusicPlaying],a
    ld      [DSX_ChannelFlags],a
    ld      hl,DSX_MusicRAM
    ld      b,sizeof_DSX_MusicRAM
    xor     a
:   ld      [hl+],a
    dec     b
    jr      nz,:-
    ld      [DSX_CH1_CurrentNRX2],a
    ld      [DSX_CH2_CurrentNRX2],a
    ld      [DSX_CH4_CurrentNRX2],a
    ldh     [rNR12],a
    ldh     [rNR22],a
    ldh     [rNR32],a
    ldh     [rNR42],a
    ld      a,$80
    ldh     [rNR14],a
    ldh     [rNR24],a
    ldh     [rNR44],a
    ld      a,low(DSX_DummyChannel)
    ld      [DSX_CH1_SeqPtr],a
    ld      [DSX_CH2_SeqPtr],a
    ld      [DSX_CH3_SeqPtr],a
    ld      [DSX_CH4_SeqPtr],a
    ld      [DSX_CH1_VolPtr],a
    ld      [DSX_CH2_VolPtr],a
    ld      [DSX_CH3_VolPtr],a
    ld      [DSX_CH4_VolPtr],a
    ld      a,high(DSX_DummyChannel)
    ld      [DSX_CH1_SeqPtr+1],a
    ld      [DSX_CH2_SeqPtr+1],a
    ld      [DSX_CH3_SeqPtr+1],a
    ld      [DSX_CH4_SeqPtr+1],a
    ld      [DSX_CH1_VolPtr+1],a
    ld      [DSX_CH2_VolPtr+1],a
    ld      [DSX_CH3_VolPtr+1],a
    ld      [DSX_CH4_VolPtr+1],a
    ld      a,-1
    ld      [DSX_MusicSpeed1],a
    ld      [DSX_MusicSpeed2],a
    ret

; ================

; Main update routine.
; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: (none)
DevSoundX_Update:
    push    af
    push    bc
    push    de
    push    hl
    call    DevSoundX_UpdateMusic
    call    DevSoundX_UpdateEffects
    call    DevSoundX_UpdateTables
    ; fall through
DevSoundX_UpdateRegisters:
    ld      hl,DSX_CH1_NRX1
    call    .dopulse1   
    ; ch2
    ld      hl,DSX_CH2_NRX1
    call    .dopulse2
    ; ch3
    ; reload wave if needed
    ld      a,[DSX_ChannelFlags]
    bit     2,a
    jr      z,.skipwavemus
    ld      a,[DSX_CH3_SampleLength]
    ld      b,a
    ld      a,[DSX_CH3_SampleLength+1]
    or      b
    jr      nz,.skipwavemus
    ld      a,[DSX_CH3_CurrentNRX2]
    and     a
    jr      z,.skipwavemus
    ld      a,[DSX_CH3_CurrentWave]
    ld      b,a
    ld      a,[DSX_CH3_PreviousWave]
    cp      b
    jr      z,.skipwavemus
    ld      a,b
    ld      [DSX_CH3_PreviousWave],a
    ld      hl,DSX_Wavetables
    swap    a
    ld      b,a
    and     $f0
    ld      c,a
    ld      a,b
    and     $f
    ld      b,a
    add     hl,bc
    call    DevSoundX_LoadWave
.skipwavemus
    ld      hl,DSX_CH3_CurrentNRX2
    call    .dowave
    ; ch4
    ld      hl,DSX_CH4_CurrentNRX2
    call    .donoise
    
    pop     hl
    pop     de
    pop     bc
    pop     af
    ret
.hl
    jp      hl
    
.zvol
    rept    16
        ldh     [c],a
    endr
    ld      a,b
    ret

.dopulse1
    ld      a,[hl+]
    ldh     [rNR11],a
    ld      a,[hl+]
    ld      b,a
    ld      a,[DSX_CH1_ChannelVol]
    and     $f
    swap    a
    or      b
    push    hl
    ld      hl,DSX_VolScaleTable
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    pop     hl
    ld      b,a
    ld      a,[hl+]
    sub     b
    jr      z,:++
    and     $f
    dec     hl
    push    hl
    ld      hl,.zvol
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,$18
    ld      c,low(rNR12)
    call    .hl
    pop     hl
    ld      [hl+],a
:   ld      a,[hl+]
    ldh     [rNR13],a
    ld      a,[hl]
    ldh     [rNR14],a
    ret

.dopulse2
    ld      a,[hl+]
    ldh     [rNR21],a
    ld      a,[hl+]
    ld      b,a
    ld      a,[DSX_CH2_ChannelVol]
    and     $f
    swap    a
    or      b
    push    hl
    ld      hl,DSX_VolScaleTable
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    pop     hl
    ld      b,a
    ld      a,[hl+]
    sub     b
    jr      z,:++
    and     $f
    dec     hl
    push    hl
    ld      hl,.zvol
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,$18
    ld      c,low(rNR22)
    call    .hl
    pop     hl
    ld      [hl+],a
:   ld      a,[hl+]
    ldh     [rNR23],a
    ld      a,[hl]
    ldh     [rNR24],a
    ret

.dowave
    ld      a,[DSX_CH3_SampleLength]
    ld      b,a
    ld      a,[DSX_CH3_SampleLength+1]
    or      b
    ret     nz
    ld      a,[hl+]
    and     %01100000
    ldh     [rNR32],a
    ld      a,[hl+] ; dummy read to skip previous wave byte
    ld      a,[hl+]
    ldh     [rNR33],a
    ld      a,[hl]
    ldh     [rNR34],a
    ret
    
.donoise
    ld      a,[hl+]
    ld      b,a
    ld      a,[DSX_CH4_ChannelVol]
    and     $f
    swap    a
    or      b
    push    hl
    ld      hl,DSX_VolScaleTable
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    pop     hl
    ld      b,a

    ld      a,[hl+]
    and     $f
    sub     b
    jr      z,:++
    dec     hl
    push    hl
    ld      hl,.zvol
    and     $f
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,$18
    ld      c,low(rNR42)
    call    .hl
    pop     hl
    ld      [hl+],a
:   ld      a,[DSX_CH4_NRX1]
    and     1
    swap    a
    rrca
    or      [hl]
    ld      b,a
    ; if noise width is changed, retrigger it to prevent lock-up
    ldh     a,[rNR43]
    xor     b
    bit     3,a
    ld      a,b
    ldh     [rNR43],a
    ret     z
    dec     hl
    ld      a,[hl]
    swap    a
    or      8
    ldh     [rNR42],a
    ld      a,$80
    ldh     [rNR44],a
    ret

; ================

macro DevSoundX_UpdateChannel
DevSoundX_UpdateChannel\1:
    ld      a,[DSX_ChannelFlags]
    bit     \1-1,a
    ret     z

    push    af
    ld      e,a
    
    ld      a,[DSX_CH\1_Timer]
    dec     a
    ld      [DSX_CH\1_Timer],a
    jr      nz,.nope

    ld      hl,DSX_CH\1_SeqPtr
    push    hl
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    jr      .getbyte
.nope
    pop     af
    ret
    
    ; get byte
.getbyte
    ld      a,[hl+]
    cp      $80
    jp      nc,.iscommand
    cp      $7f
    jp      z,.isrest
    cp      $7e
    jp      z,.iswait
    cp      $7d
    jp      z,.isrelease
.isnote
    ld      d,a
    ld      a,[DSX_CH\1_Note]
    ld      e,a
    ld      a,d
    ld      [DSX_CH\1_Note],a
    
    ld      a,[DSX_CH\1_FirstNote]
    and     a
    ld      a,[DSX_CH\1_Note]
    jr      nz,.skipinit
    ld      [DSX_CH\1_FirstNote],a
    push    hl
    ld      hl,DSX_CH\1_EchoBuffer
    ld      [hl+],a
    ld      [hl+],a
    ld      [hl+],a
    ld      [hl+],a
    pop     hl
    
    ; update echo buffer
.skipinit
    ld      c,a
    push    hl
    ld      a,[DSX_CH\1_EchoPos]
    ld      hl,DSX_CH\1_EchoBuffer
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      [hl],c
    ld      a,[DSX_CH\1_EchoPos]
    inc     a
    and     $3
    ld      [DSX_CH\1_EchoPos],a
    pop     hl
    ld      a,[hl+]
    ld      [DSX_CH\1_Timer],a
    if \1 != 4 ; don't reset tables if portamento is active
        ld      a,[DSX_CH\1_PitchMode]  
        and     PITCH_MODE_MASK
        cp      3
        ld      a,0 ; we need flags so xor a is no good
        jr      z,:+
    endc
    
    ld      a,[DSX_CH\1_VolResetPtr]
    ld      [DSX_CH\1_VolPtr],a
    ld      a,[DSX_CH\1_VolResetPtr+1]
    ld      [DSX_CH\1_VolPtr+1],a
    ld      a,[DSX_CH\1_ArpResetPtr]
    ld      [DSX_CH\1_ArpPtr],a
    ld      a,[DSX_CH\1_ArpResetPtr+1]
    ld      [DSX_CH\1_ArpPtr+1],a
    ld      a,[DSX_CH\1_PulseResetPtr]
    ld      [DSX_CH\1_PulsePtr],a
    ld      a,[DSX_CH\1_PulseResetPtr+1]
    ld      [DSX_CH\1_PulsePtr+1],a
    xor     a
    ld      [DSX_CH\1_ArpTranspose],a
:
    if      \1 == 3
        ld      [DSX_CH\1_SamplePointer],a
        ld      [DSX_CH\1_SamplePointer+1],a
        ld      [DSX_CH\1_SampleLength],a
        ld      [DSX_CH\1_SampleLength+1],a
    endc
    if      \1 != 4
        ld      [DSX_CH\1_VibOffset],a
        ld      [DSX_CH\1_VibOffset+1],a
        ld      [DSX_CH\1_SlideOffset],a
        ld      [DSX_CH\1_SlideOffset+1],a
        ld      a,[DSX_CH\1_PitchResetPtr]
        push    hl
        ld      [DSX_CH\1_PitchPtr],a
        ld      l,a
        ld      a,[DSX_CH\1_PitchResetPtr+1]
        ld      [DSX_CH\1_PitchPtr+1],a
        ld      h,a
        ld      a,[hl+]
        ld      [DSX_CH\1_PitchDelay],a
        ld      a,l
        ld      [DSX_CH\1_PitchPtr],a
        ld      a,h
        ld      [DSX_CH\1_PitchPtr+1],a
        ld      a,[DSX_CH\1_PitchMode]
        and     PITCH_MODE_MASK
        cp      PITCH_MODE_PORTAMENTO
        jr      nz,:+
        ld      a,c
        ld      [DSX_CH\1_NoteTarget],a
        ld      b,0
        ld      hl,DSX_FreqTablePtr
        ld      a,[hl+]
        ld      h,[hl]
        ld      l,a
        add     hl,bc
        add     hl,bc
        ld      a,[hl+]
        ld      [DSX_CH\1_SlideTarget],a
        ld      a,[hl]
        ld      [DSX_CH\1_SlideTarget+1],a
        ld      a,e
        ld      [DSX_CH\1_Note],a
        jr      :++
:       xor     a   ; disable slide + monty on new note
        ld      [DSX_CH\1_PitchMode],a
:       pop     hl
    endc
    xor     a
    ld      [DSX_CH\1_VolDelay],a
    ld      [DSX_CH\1_ArpDelay],a
    ld      [DSX_CH\1_PulseDelay],a
    ld      a,[DSX_CH\1_Timer]
    and     a
    jp      z,.getbyte
    jp      .donech\1
.isrest
    ld      [DSX_CH\1_Note],a
    ld      a,[hl+]
    ld      [DSX_CH\1_Timer],a
    ld      a,low(DSX_RestVol)
    ld      [DSX_CH\1_VolPtr],a
    ld      a,high(DSX_RestVol)
    ld      [DSX_CH\1_VolPtr+1],a
    xor     a
    ld      [DSX_CH\1_CurrentNRX2],a
    if      \1 == 3
        ld      [DSX_CH\1_SamplePointer],a
        ld      [DSX_CH\1_SamplePointer+1],a
        ld      [DSX_CH\1_SampleLength],a
        ld      [DSX_CH\1_SampleLength+1],a
    endc
    jp      .donech\1
.iswait
    ld      a,[hl+]
    ld      [DSX_CH\1_Timer],a
    jp      .donech\1
.isrelease
    ld      a,[hl+]
    ld      [DSX_CH\1_Timer],a
    
    push    hl
    ld      hl,DSX_CH\1_VolReleasePtr
    ld      a,[hl+]
    ld      b,a
    or      [hl]
    jr      z,:+
    ld      a,b
    ld      [DSX_CH\1_VolPtr],a
    ld      a,[hl+]
    ld      [DSX_CH\1_VolPtr+1],a
:    
    ld      hl,DSX_CH\1_ArpReleasePtr
    ld      a,[hl+]
    ld      b,a
    or      [hl]
    jr      z,:+
    ld      a,b
    ld      [DSX_CH\1_ArpPtr],a
    ld      a,[hl+]
    ld      [DSX_CH\1_ArpPtr+1],a
:    
    ld      hl,DSX_CH\1_PulseReleasePtr
    ld      a,[hl+]
    ld      b,a
    or      [hl]
    jr      z,:+
    ld      a,b
    ld      [DSX_CH\1_PulsePtr],a
    ld      a,[hl+]
    ld      [DSX_CH\1_PulsePtr+1],a
:    
    if \1 != 4
        ld      hl,DSX_CH\1_PitchReleasePtr
        ld      a,[hl+]
        ld      b,a
        or      [hl]
        jr      z,:+
        ld      a,b
        ld      [DSX_CH\1_PitchPtr],a
        ld      a,[hl+]
        ld      [DSX_CH\1_PitchPtr+1],a
:    
    endc
    pop     hl
    jp      .donech\1
    
.iscommand
    cp      $ff
    jp      z,.end
    push    hl
    ld      hl,.cmdtable
    and     $7f
    cp      NUM_COMMANDS
    jr      nc,.panic
    ld      c,a
    ld      b,0
    add     hl,bc
    add     hl,bc
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    jp      hl
.panic
    ; stack resync
    if \1 != 4
        add     sp,18
    else
        add     sp,16
    endc
    ; stop music
    jp      DevSoundX_StopMusic

.cmdtable
    dw      .instrument
    dw      .jump
    dw      .loop
    dw      .call
    dw      .ret
    dw      .slideup
    dw      .slidedown
    dw      .portamento
    dw      .togglemonty
    dw      .sample
    dw      .setvol
	dw		.settransposechannel
	dw		.settransposeglobal
	dw		.resettransposechannel
	dw		.resettransposeglobal
    dw      .setarpptr
    dw      .setspeed
def NUM_COMMANDS = (@ - .cmdtable) / 2
    
.instrument
    pop     hl
    ld      a,[hl+]
    push    hl
    ld      h,[hl]
    ld      l,a
    
    ld      a,[hl+]
    ld      [DSX_CH\1_VolPtr],a
    ld      [DSX_CH\1_VolResetPtr],a
    ld      a,[hl+]
    ld      [DSX_CH\1_VolPtr+1],a
    ld      [DSX_CH\1_VolResetPtr+1],a
    ld      a,[hl+]
    ld      [DSX_CH\1_ArpPtr],a
    ld      [DSX_CH\1_ArpResetPtr],a
    ld      a,[hl+]
    ld      [DSX_CH\1_ArpPtr+1],a
    ld      [DSX_CH\1_ArpResetPtr+1],a
    ld      a,[hl+]
    ld      [DSX_CH\1_PulsePtr],a
    ld      [DSX_CH\1_PulseResetPtr],a
    ld      a,[hl+]
    ld      [DSX_CH\1_PulsePtr+1],a
    ld      [DSX_CH\1_PulseResetPtr+1],a
    if      \1 != 4
        ld      a,[hl+]
        ld      [DSX_CH\1_PitchResetPtr],a
        ld      a,[hl+]
        ld      [DSX_CH\1_PitchResetPtr+1],a
    else
        inc     hl
        inc     hl
    endc
    
    ld      a,[hl+]
    ld      [DSX_CH\1_VolReleasePtr],a
    ld      a,[hl+]
    ld      [DSX_CH\1_VolReleasePtr+1],a
    ld      a,[hl+]
    ld      [DSX_CH\1_ArpReleasePtr],a
    ld      a,[hl+]
    ld      [DSX_CH\1_ArpReleasePtr+1],a
    ld      a,[hl+]
    ld      [DSX_CH\1_PulseReleasePtr],a
    ld      a,[hl+]
    ld      [DSX_CH\1_PulseReleasePtr+1],a
    if \1 != 4
        ld      a,[hl+]
        ld      [DSX_CH\1_PitchReleasePtr],a
        ld      a,[hl+]
        ld      [DSX_CH\1_PitchReleasePtr+1],a
    endc
    pop     hl
    inc     hl
    jp      .getbyte
    
.jump
    pop     hl
.jump2
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    jp      .getbyte
    
.loop
    pop     hl
.loop2
    ld      a,[hl+]
    ld      d,a
    ld      a,[DSX_CH\1_LoopCount]
    and     a
    jr      nz,.skiploop2
    ld      a,d
    ld      [DSX_CH\1_LoopCount],a
    jr      .jump2
.skiploop2
    ld      a,[DSX_CH\1_LoopCount]
    dec     a
    ld      [DSX_CH\1_LoopCount],a
    and     a
    jr      nz,.jump2
.skiploop
    inc     hl
    inc     hl
    jp      .getbyte

.call
    pop     hl
    push    hl
    inc     hl
    inc     hl
    ld      a,l
    ld      [DSX_CH\1_ReturnPtr],a
    ld      a,h
    ld      [DSX_CH\1_ReturnPtr+1],a
    pop     hl
    jr      .jump2

.ret
    pop     hl
    ld      hl,DSX_CH\1_ReturnPtr
    jr      .jump2

.slideup:
    pop     hl
    if \1 != 4
        ld      a,[hl+]
        ld      [DSX_CH\1_SlideSpeed],a
        ld      a,[DSX_CH\1_PitchMode]
        and     PITCH_BIT_MASK
        or      PITCH_MODE_SLIDE_UP
        ld      [DSX_CH\1_PitchMode],a
    else
        inc     hl
    endc
    jp      .getbyte

.slidedown
    pop     hl
    if \1 != 4
        ld      a,[hl+]
        ld      [DSX_CH\1_SlideSpeed],a
        ld      a,[DSX_CH\1_PitchMode]
        and     PITCH_BIT_MASK
        or      PITCH_MODE_SLIDE_DOWN
        ld      [DSX_CH\1_PitchMode],a
    else
        inc     hl
    endc
    jp      .getbyte

.portamento
    pop     hl
    if \1 != 4
        ld      a,[hl+]
        ld      [DSX_CH\1_SlideSpeed],a
        ld      a,[DSX_CH\1_PitchMode]
        and     PITCH_BIT_MASK
        or      PITCH_MODE_PORTAMENTO
        ld      [DSX_CH\1_PitchMode],a
    else
        inc     hl
    endc
    jp      .getbyte

.togglemonty
    if  \1 != 4
        ld      a,[DSX_CH\1_PitchMode]
        xor     1 << PITCH_BIT_MONTY
        ld      [DSX_CH\1_PitchMode],a
    endc
    pop     hl
    jp      .getbyte

.sample
    pop     hl
    if \1 == 3
        ld      a,[hl+]
        push    hl
        ld      h,[hl]
        ld      l,a
        ld      a,[hl+]
        ld      [DSX_CH\1_SampleLength],a
        ld      a,[hl+]
        ld      [DSX_CH\1_SampleLength+1],a
        ld      a,l
        ld      [DSX_CH\1_SamplePointer],a
        ld      a,h
        ld      [DSX_CH\1_SamplePointer+1],a
        pop     hl
        inc     hl
        jp      .iswait
    else
        inc     hl
        inc     hl
        inc     hl
        jp      .getbyte
    endc

.setvol
    pop     hl
    if \1 != 3
        ld      a,[hl+]
        ld      [DSX_CH\1_ChannelVol],a
    else
        inc     hl
    endc
    jp      .getbyte

.settransposechannel
	pop		hl
	if \1 != 4
		ld		a,[hl+]
		ld		[DSX_CH\1_Transpose],a
	else
		inc		hl
	endc
	jp		.getbyte

.settransposeglobal
	pop		hl
	ld		a,[hl+]
	ld		[DSX_CH1_Transpose],a
	ld		[DSX_CH2_Transpose],a
	ld		[DSX_CH3_Transpose],a
	jp		.getbyte

.resettransposechannel
	pop		hl
	if		\1 != 4
		xor		a
		ld		[DSX_CH\1_Transpose],a
	endc
	jp		.getbyte

.resettransposeglobal
	pop		hl
	xor		a
	ld		[DSX_CH1_Transpose],a
	ld		[DSX_CH2_Transpose],a
	ld		[DSX_CH3_Transpose],a
	jp		.getbyte

.setarpptr
    pop     hl
    ld      a,[hl+]
    ld      [DSX_CH\1_ArpResetPtr],a
    ld      a,[hl+]
    ld      [DSX_CH\1_ArpResetPtr+1],a
    jp      .getbyte

.setspeed
    pop     hl
    ld      a,[hl+]
    ld      [DSX_MusicSpeed1],a
    ld      a,[hl+]
    ld      [DSX_MusicSpeed2],a
    jp      .getbyte

;.dummyword
;    inc     hl
;.dummybyte
;    inc     hl
;.dummynone
;    jp      .getbyte
    
.end
    ld      a,[DSX_ChannelFlags]
    res     \1 - 1,a
    ld      [DSX_ChannelFlags],a
    pop     hl
    pop     af
    ret

.donech\1:
    ld      e,h
    ld      a,l
    pop     hl
    ld      [hl+],a
    ld      [hl],e
    pop     af
    ret
endm
    DevSoundX_UpdateChannel 1
    DevSoundX_UpdateChannel 2
    DevSoundX_UpdateChannel 3
    DevSoundX_UpdateChannel 4

; ========

; Music update routine.
; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af bc de hl
DevSoundX_UpdateMusic:
    ld      a,[DSX_MusicPlaying]
    and     a
    ret     z
    
    ld      hl,DSX_GlobalTick
    inc     [hl]
    
    ld      hl,DSX_MusicSpeedTick
    dec     [hl]
    ret     nz
    
    ld      hl,DSX_MusicTick
    inc     [hl]
    ld      a,[hl]
    and     1
    jr      nz,.odd
.even
    ld      a,[DSX_MusicSpeed2]
    jr      :+
.odd
    ld      a,[DSX_MusicSpeed1]
:   ld      [DSX_MusicSpeedTick],a
    call    DevSoundX_UpdateChannel1
    call    DevSoundX_UpdateChannel2
    call    DevSoundX_UpdateChannel3
    jp      DevSoundX_UpdateChannel4
    
; ================
    
macro DSX_UpdateTables
; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af bc de hl
DSX_UpdateTables_CH\1:
.dovol      ; volume table
    ld      a,[DSX_CH\1_VolDelay]
    and     a
    jr      z,:+
    dec     a
    ld      [DSX_CH\1_VolDelay],a
    jr      nz,.doarp   
:   ld      hl,DSX_CH\1_VolPtr
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
:   ld      a,[hl+] 
    cp      seq_end
    jr      z,.doarp
    cp      seq_loop
    jr      z,.loopvol
    cp      seq_wait
    jr      z,.waitvol
.setvol
    ; sanitize
    if (\1%4) != 3
        and     $8f
    endc
    ld      [DSX_CH\1_CurrentNRX2],a
.setvolptr
    ld      a,l
    ld      [DSX_CH\1_VolPtr],a
    ld      a,h
    ld      [DSX_CH\1_VolPtr+1],a
    jr      .doarp
.loopvol
    ld      a,[hl+]
    add     l
    ld      l,a
    jr      c,:-
    dec     h
    jr      :-
.waitvol
    ld      a,[hl+]
    ld      [DSX_CH\1_VolDelay],a
    jr      .setvolptr

.doarp      ; arpeggio table
    ld      a,[DSX_CH\1_ArpDelay]
    and     a
    jr      z,:+
    dec     a
    ld      [DSX_CH\1_ArpDelay],a
    jr      nz,.dopulse
:   ld      hl,DSX_CH\1_ArpPtr
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
:   ld      a,[hl+] 
    cp      seq_end
    jr      z,.dopulse
    cp      seq_loop
    jr      z,.looparp
    cp      seq_wait
    jr      z,.waitarp
.setarp
    ld      [DSX_CH\1_ArpTranspose],a
.setarpptr
    ld      a,l
    ld      [DSX_CH\1_ArpPtr],a
    ld      a,h
    ld      [DSX_CH\1_ArpPtr+1],a
    jr      .dopulse
.looparp
    ld      a,[hl+]
    add     l
    ld      l,a
    jr      c,:-
    dec     h
    jr      :-
.waitarp
    ld      a,[hl+]
    ld      [DSX_CH\1_ArpDelay],a
    jr      .setarpptr

.dopulse    ; pulse table
    ld      a,[DSX_CH\1_PulseDelay]
    and     a
    jr      z,:+
    dec     a
    ld      [DSX_CH\1_PulseDelay],a
    jr      nz,.dopitch
:   ld      hl,DSX_CH\1_PulsePtr
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
:   ld      a,[hl+] 
    cp      seq_end
    jr      z,.dopitch
    cp      seq_loop
    jr      z,.looppulse
    cp      seq_wait
    jr      z,.waitpulse
.setpulse
    ; sanitize
    if (\1 == 1) | (\1 == 2)
        rrca
        rrca
        and     %11000000
    endc
    if \1 == 4
        and 1
    endc
    ld      [DSX_CH\1_NRX1],a
.setpulseptr
    ld      a,l
    ld      [DSX_CH\1_PulsePtr],a
    ld      a,h
    ld      [DSX_CH\1_PulsePtr+1],a
    jr      .dopitch
.looppulse
    ld      a,[hl+]
    add     l
    ld      l,a
    jr      c,:-
    dec     h
    jr      :-
.waitpulse
    ld      a,[hl+]
    ld      [DSX_CH\1_PulseDelay],a
    jr      .setpulseptr
    
.dopitch
if \1 != 4
    ld      a,[DSX_CH\1_PitchDelay]
    and     a
    jr      z,:+
    dec     a
    ld      [DSX_CH\1_PitchDelay],a
    jr      nz,.dofreq
:   ld      hl,DSX_CH\1_PitchPtr
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
:   ld      a,[hl+]
    cp      pitch_end
    jr      z,.dofreq
    cp      pitch_loop
    jr      z,.looppitch
.setpitch
    ld      [DSX_CH\1_VibOffset],a
    cp      1 << 7
    ccf
    sbc     a    
    ld      [DSX_CH\1_VibOffset+1],a
.setpitchptr
    ld      a,l
    ld      [DSX_CH\1_PitchPtr],a
    ld      a,h
    ld      [DSX_CH\1_PitchPtr+1],a
    jr      .dofreq
.looppitch
    ld      a,[hl+]
    add     l
    ld      l,a
    jr      c,:-
    dec     h
    jr      :-
endc

.dofreq ; set frequency
    ld      a,[DSX_CH\1_ArpTranspose]
    cp      $40
    jr      c,:+
    sub     $80
    jr      nc,.gotnote
    ; values $40~$7f is now $c0~$ff
    cpl         ; = $3f~$00
    sub     $3f ; = $00~-$3f
:   ld      c,a
    ; check for echo
    ld      a,[DSX_CH\1_CurrentNRX2]
    bit     7,a
    jr      z,.noecho
    ld      hl,DSX_CH\1_EchoBuffer
    ld      a,[DSX_CH\1_EchoPos]
    sub     2
    and     $3
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    jr      .addtranspose
.noecho
    ld      a,[DSX_CH\1_Note]
.addtranspose
    if      \1 != 4
        ld      b,a
        ld      a,[DSX_CH\1_Transpose]
        add     b
    endc
    add     c
.gotnote
    if \1 != 4
        ld      c,a
        ld      hl,DSX_FreqTablePtr
        ld      a,[hl+]
        ld      h,[hl]
        ld      l,a
        ld      b,0
        add     hl,bc
        add     hl,bc
        ld      a,[hl+]
        ld      b,[hl]
        ld      c,a
        ; add pitch macro offset
        ld      hl,DSX_CH\1_VibOffset
        ld      a,[hl+]
        ld      h,[hl]
        ld      l,a
        add     hl,bc
        ; add note slide offset
        ld      a,[DSX_CH\1_PitchMode]
        and     a
        jr      z,:++
        bit     PITCH_BIT_MONTY,a
        jr      z,:+
        ld      a,[DSX_GlobalTick]
        and     1
        jr      z,:++
:       ld      b,h
        ld      c,l
        ld      hl,DSX_CH\1_SlideOffset
        ld      a,[hl+]
        ld      h,[hl]
        ld      l,a
        add     hl,bc
:       ; set frequency
        ld      a,l
        ld      [DSX_CH\1_NRX3],a
        ld      a,h
        and     $7
        ld      [DSX_CH\1_NRX4],a
    else
        ld      hl,DSX_NoiseTable
        add     l
        ld      l,a
        jr      nc,:+
        inc     h
:       ld      a,[hl]
        ld      [DSX_CH4_NRX3],a
    endc
    ret
endm
    DSX_UpdateTables    1
    DSX_UpdateTables    2
    DSX_UpdateTables    3
    DSX_UpdateTables    4

; Update routine for macros.
; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af bc de hl
DevSoundX_UpdateTables:
    ld      a,[DSX_MusicPlaying]
    and     a
    ret     z
    call    DSX_UpdateTables_CH1
    call    DSX_UpdateTables_CH2
    call    DSX_UpdateTables_CH3
    jp      DSX_UpdateTables_CH4

; ================

; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af bc de hl
macro DSX_UpdateEffects
DSX_UpdateEffects_CH\1:
    if \1 != 4
    ; process pitch bends
    ld      a,[DSX_CH\1_PitchMode]
    and     PITCH_MODE_MASK
    and     a   ; PITCH_MODE_NONE
    jp      z,.donepitch
    dec     a   ; PITCH_MODE_SLIDE_UP
    jr      z,.slideup
    dec     a   ; PITCH_MODE_SLIDE_DOWN
    jr      z,.slidedown
    dec     a   ; PITCH_MODE_PORTAMENTO
    jr      z,.portamento
.slideup
    ld      a,[DSX_CH\1_SlideSpeed]
    ld      c,a
    ld      b,0
    jr      .doslide
.slidedown
    ld      a,[DSX_CH\1_SlideSpeed]
    cpl
    inc     a
    ld      c,a
    ld      b,$ff
.doslide
    ld      hl,DSX_CH\1_SlideOffset
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    add     hl,bc
    ld      a,l
    ld      [DSX_CH\1_SlideOffset],a
    ld      a,h
    ld      [DSX_CH\1_SlideOffset+1],a
    jp      .donepitch
.portamento
    ld      a,[DSX_CH\1_Note]
    ld      c,a
    ld      b,0
    ld      hl,DSX_FreqTablePtr
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    add     hl,bc
    add     hl,bc
    ld      a,[hl+]
    ld      b,[hl]
    ld      c,a
    ld      hl,DSX_CH\1_SlideTarget
    ld      a,[hl+]
    ld      d,[hl]
    ld      e,a
    ld      hl,DSX_CH\1_SlideOffset
    call    DSX_Compare16
    jr      z,.donepitch
    jr      nc,.portadown
.portaup
    push    bc
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    ld      a,[DSX_CH\1_SlideSpeed]
    ld      c,a
    ld      b,0
    add     hl,bc
    ld      a,l
    ld      [DSX_CH\1_SlideOffset],a
    ld      a,h
    ld      [DSX_CH\1_SlideOffset+1],a
    pop     bc
    push    hl
    add     hl,bc
    ld      b,h
    ld      c,l
    call    DSX_Compare16
    pop     hl
    jr      z,.doneporta
    jr      c,.doneporta
    jr      .stopporta
.portadown
    push    bc
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    ld      a,[DSX_CH\1_SlideSpeed]
    cpl
    inc     a
    ld      c,a
    ld      b,$ff
    add     hl,bc
    ld      a,l
    ld      [DSX_CH\1_SlideOffset],a
    ld      a,h
    ld      [DSX_CH\1_SlideOffset+1],a
    pop     bc
    push    hl
    add     hl,bc
    ld      b,h
    ld      c,l
    call    DSX_Compare16
    pop     hl
    jr      z,.doneporta
    jr      nc,.doneporta
    jr      .stopporta
.doneporta
    ld      a,l
    ld      [DSX_CH\1_SlideOffset],a
    ld      a,h
    ld      [DSX_CH\1_SlideOffset+1],a
    jr      .donepitch
.stopporta
    ; FIXME: this kills monty mode
    ld      a,[DSX_CH\1_NoteTarget]
    ld      [DSX_CH\1_Note],a
    xor     a
    ld      [DSX_CH\1_SlideSpeed],a
    ld      [DSX_CH\1_SlideOffset],a
    ld      [DSX_CH\1_SlideOffset+1],a
    ld      a,[DSX_CH\1_PitchMode]
    and     PITCH_BIT_MASK
    ld      [DSX_CH\1_PitchMode],a
.donepitch
    endc
    
    if \1 == 3
.dosample
    ld      hl,DSX_CH3_SampleLength
    ld      a,[hl+]
    or      [hl]
    dec     hl
    jr      z,.nosample
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    
    dec     hl
    ld      a,l
    or      h
    jr      z,.stopsample
    ld      a,l
    ld      [DSX_CH3_SampleLength],a
    ld      a,h
    ld      [DSX_CH3_SampleLength+1],a  

    ld      hl,DSX_CH3_SamplePointer
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    call    DevSoundX_LoadWave
    ld      a,$20
    ldh     [rNR32],a
    xor     a
    ldh     [rNR33],a
    ld      a,4
    ldh     [rNR34],a
    ld      a,l
    ld      [DSX_CH3_SamplePointer],a
    ld      a,h
    ld      [DSX_CH3_SamplePointer+1],a
    jr      .nosample
.stopsample
    xor     a
    ldh     [rNR32],a
.nosample
    endc
    ret
endm

    DSX_UpdateEffects   1
    DSX_UpdateEffects   2
    DSX_UpdateEffects   3
    DSX_UpdateEffects   4

; Update routine for pitch bends + other effects.
; INPUT:    (none)
; OUTPUT:   (none)
; DESTROYS: af bc de hl
DevSoundX_UpdateEffects:
    ld      a,[DSX_MusicPlaying]
    and     a
    ret     z
    call    DSX_UpdateEffects_CH1
    call    DSX_UpdateEffects_CH2
    call    DSX_UpdateEffects_CH3
    jp      DSX_UpdateEffects_CH4

; ================

; Load a waveform.
; INPUT:    hl = pointer to waveform
; OUTPUT:   (none)
; DESTROYS: af
DevSoundX_LoadWave:
    ; GBA antispike
    ldh     a,[rNR51]
    push    af
    and     %10111011
    ldh     [rNR51],a
    ; disable + re-enable wave channel (makes wave RAM writable)
    push    hl
    ld      hl,rNR30
    ld      [hl],AUD3ENA_OFF
    ld      [hl],AUD3ENA_ON
    ; copy wave from HL to wave RAM
    pop     hl
def i = 0
    rept    16
        ld      a,[hl+]
        ldh     [_AUD3WAVERAM+i],a
def i = i+1
    endr
    ; trigger wave channel
    ld      a,%10000000
    ldh     [rNR34],a
    pop     af
    ldh     [rNR51],a
    ret 

; ================

; 16-bit compare
; INPUT:    bc = value 1
;           de = value 2
; OUTPUT:   zero = set if equal
;           carry = set if bc < de
; DESTROYS: a
DSX_Compare16:
    ld  a,b
    cp  d
    ret nz
    ld  a,c
    cp  e
    ret

; ================

; standard frequency table (A=440)
DSX_FreqTableA440:
DSX_FreqTable:
;        C-x  C#x  D-x  D#x  E-x  F-x  F#x  G-x  G#x  A-x  A#x  B-x
    dw  $02c,$09d,$107,$16b,$1c9,$223,$277,$2c7,$312,$358,$39b,$3da ; octave 1
    dw  $416,$44e,$483,$4b5,$4e5,$511,$53b,$563,$589,$5ac,$5ce,$5ed ; octave 2
    dw  $60b,$627,$642,$65b,$672,$689,$69e,$6b2,$6c4,$6d6,$6e7,$6f7 ; octave 3
    dw  $706,$714,$721,$72d,$739,$744,$74f,$759,$762,$76b,$773,$77b ; octave 4
    dw  $783,$78a,$790,$797,$79d,$7a2,$7a7,$7ac,$7b1,$7b6,$7ba,$7be ; octave 5
    dw  $7c1,$7c5,$7c8,$7cb,$7ce,$7d1,$7d4,$7d6,$7d9,$7db,$7dd,$7df ; octave 6
    dw  $7e1,$7e2,$7e4,$7e6,$7e7,$7e9,$7ea,$7eb,$7ec,$7ed,$7ee,$7ef ; octave 7
    dw  $7f0,$7f1,$7f2,$7f3,$7f4,$7f4,$7f5,$7f6,$7f6,$7f7,$7f7,$7f8 ; octave 8
; alternate frequency table (A=432)
DSX_FreqTableA432:
;        C-x  C#x  D-x  D#x  E-x  F-x  F#x  G-x  G#x  A-x  A#x  B-x
;   dw  $007,$079,$0e6,$14c,$1ac,$207,$25d,$2ae,$2fa,$342,$386,$3c7 ; octave 1
;   dw  $403,$43d,$473,$4a6,$4d6,$503,$52e,$557,$57d,$5a1,$5c3,$5e3 ; octave 2
;   dw  $602,$61e,$639,$653,$66b,$682,$697,$6ab,$6bf,$6d1,$6e2,$6f2 ; octave 3
;   dw  $701,$70f,$71d,$729,$735,$741,$74c,$756,$75f,$768,$771,$779 ; octave 4
;   dw  $780,$788,$78e,$795,$79b,$7a0,$7a6,$7ab,$7b0,$7b4,$7b8,$7bc ; octave 5
;   dw  $7c0,$7c4,$7c7,$7ca,$7cd,$7d0,$7d3,$7d5,$7d8,$7da,$7dc,$7de ; octave 6
;   dw  $7e0,$7e2,$7e4,$7e5,$7e7,$7e8,$7e9,$7eb,$7ec,$7ed,$7ee,$7ef ; octave 7
;   dw  $7f0,$7f1,$7f2,$7f3,$7f3,$7f4,$7f5,$7f5,$7f6,$7f7,$7f7,$7f8 ; octave 8


DSX_NoiseTable:
    db  $a4
    db  $97,$96,$95,$94
    db  $87,$86,$85,$84
    db  $77,$76,$75,$74
    db  $67,$66,$65,$64
    db  $57,$56,$55,$54
    db  $47,$46,$45,$44
    db  $37,$36,$35,$34
    db  $27,$26,$25,$24
    db  $17,$16,$15,$14
    db  $07,$06,$05,$04
    db  $03,$02,$01,$00

DSX_VolScaleTable:
    db       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db       0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
    db       0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2
    db       0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3
    db       0, 0, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4
    db       0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4, 5, 5, 5
    db       0, 0, 1, 1, 2, 2, 3, 3, 3, 4, 4, 5, 5, 5, 6, 6
    db       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7
    db       0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 7, 8, 8
    db       0, 1, 1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 7, 8, 9, 9
    db       0, 1, 1, 2, 3, 3, 4, 5, 5, 6, 7, 7, 8, 9, 9,10
    db       0, 1, 1, 2, 3, 4, 4, 5, 6, 7, 7, 8, 9,10,10,11
    db       0, 1, 2, 2, 3, 4, 5, 6, 6, 7, 8, 9,10,10,11,12
    db       0, 1, 2, 3, 3, 4, 5, 6, 7, 8, 9,10,10,11,12,13
    db       0, 1, 2, 3, 4, 5, 6, 7, 7, 8, 9,10,11,12,13,14
    db       0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15	

DSX_RestVol:
DSX_DummyTable:
DSX_DummyChannel:
    sound_end
DSX_DummyPitch:
    db  1,0,pitch_end

db      "$$endcode$$"

; ================================================================

include "Audio/Waves.asm"
include "Audio/Songs.asm"
