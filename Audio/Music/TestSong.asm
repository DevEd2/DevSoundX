DSX_TestSong:
    db  4,4
    dw  DSX_TestSequence1
;   dw  DSX_TestSequence2
    dw  DSX_DummyChannel
    dw  DSX_TestSequence3
    dw  DSX_TestSequence4
    if  ENABLE_YMZ284
    dw  DSX_DummyChannel
    dw  DSX_DummyChannel
    dw  DSX_DummyChannel
    endc

DSX_TestSequence1:
:   sound_instrument DSX_TestInstrument
    note C_,4, 2
    release 2
    note D_,4, 2
    release 2
    note E_,4, 2
    release 2
    note F_,4, 2
    release 2
    sound_set_arp_ptr DSX_TestArpSequence
    note G_,4, 2
    release 2
    note A_,4, 2
    release 2
    note B_,4, 2
    release 2
    note C_,5, 2
    release 2
    rest 212
    sound_instrument DSX_TestInstrumentSustain
    note C_,4, 8
    sound_slide_up 8
    wait 8
    note C_,4, 8
    sound_slide_down 8
    wait 8
    note C_,5, 16
    sound_toggle_monty
    sound_slide_down 1
    wait 32
    rest 64
:   note C_,4, 1
    note E_,4, 1
    note G_,4, 1
    sound_loop 4,:-
    rest 1
    sound_call .block1
    rest 1
    note C_,3,8
    sound_portamento 32
    note C_,4,8
    note C_,4,8
    sound_portamento 32
    note C_,3,8
    note C_,5,16
    sound_portamento 32
    sound_toggle_monty
    note C_,2,32
    rest 1
    sound_end
.block1
    note C_,5,1
    note E_,5,1
    note G_,5,1
    note C_,6,1
    note G_,5,1
    note E_,5,1
    note C_,5,1
    sound_ret
    
DSX_TestSequence3:
    sound_instrument DSX_TestInstrumentWave
    rest 32
    note C_,5, 4
    note D_,5, 4
    note E_,5, 4
    note F_,5, 4
    note G_,5, 4
    note A_,5, 4
    note B_,5, 4
    note C_,6, 4
    rest 130
    rest 130
    sound_sample TestSample,128
    sound_end

DSX_TestSequence4:
    rest 64
    sound_instrument DSX_TestInstrumentNoise1
    for n,45
        db n,2
    endr
    sound_instrument DSX_TestInstrumentNoise2
    for n,45
        db n,2
    endr
    sound_end

; ================================================================

; INSTRUMENT FORMAT: [volume pointer], [pulse pointer], [arp pointer], [pitch pointer]
DSX_TestInstrument:
    dw  DSX_TestVolSequence
    dw  DSX_DummyTable
    dw  DSX_TestPulseSequence
    dw  DSX_TestPitchSequence
    dw  DSX_TestVolSequenceEcho,0,0,0

DSX_TestInstrumentEcho:
    dw  DSX_TestVolSequence
    dw  DSX_DummyTable
    dw  DSX_TestPulseSequence
    dw  DSX_TestPitchSequence
    dw  DSX_TestVolSequenceEcho2,0,0,0

DSX_TestInstrumentSustain:
    dw  DSX_TestVolSequenceHold
    dw  DSX_DummyTable
    dw  DSX_TestPulseSequence
    dw  DSX_TestPitchSequence
    dw  0,0,0,0

;DSX_TestInstrumentEcho:
;    dw  DSX_TestVolSequenceEcho
;    dw  DSX_TestArpSequence
;    dw  DSX_TestPulseSequence
;    dw  DSX_TestPitchSequence
;    dw  0,0,0,0

DSX_TestInstrumentWave:
    dw  DSX_TestWaveVolSequence
    dw  DSX_DummyTable
    dw  DSX_TestWaveSequence
    dw  DSX_DummyPitch
    dw  0,0,0,0

DSX_TestInstrumentNoise1:
    dw  DSX_TestNoiseVolSequence
    dw  DSX_DummyTable
    dw  DSX_Noise0Table
    dw  DSX_DummyTable
    dw  0,0,0,0
    
DSX_TestInstrumentNoise2:
    dw  DSX_TestNoiseVolSequence
    dw  DSX_DummyTable
    dw  DSX_Noise1Table
    dw  DSX_DummyTable
    dw  0,0,0,0

DSX_TestVolSequence:
    db  15,14,13,12,11,10,9,8,seq_end

DSX_TestNoiseVolSequence:
    db  15,13,11,9,7,6,5,4,3,3,2,2,1,1,1,0,seq_end

DSX_TestVolSequenceEcho:
    db  3,3,3,2,2,2,2,1,1,1,1,1,0,seq_end

DSX_TestVolSequenceEcho2:
    db  $80|3,$80|3,$80|3,$80|2,$80|2,$80|2,$80|2,$80|1,$80|1,$80|1,$80|1,$80|1,0,seq_end

DSX_TestVolSequenceHold:
    db  15,14,13,12,11,10,9,seq_end

DSX_TestWaveVolSequence:
    db  $20,$20,$20,$20,$20,$20,$20,$20,$80|$60,seq_end

DSX_TestPulseSequence:
    db  0,1,1,1,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,seq_end

DSX_TestArpSequence:
:   db  12,seq_wait,3,0,seq_wait,3
    db  seq_loop,(:- -@)-1

DSX_TestPitchSequence:
    db  8
:   db  1,2,2,1,0,-1,-2,-2,-1,0
    db  pitch_loop,(:- -@)-1

DSX_Noise0Table:
    db  0,seq_end

DSX_Noise1Table:
    db  1,seq_end

DSX_TestWaveSequence:
    db  18,seq_end
    
; ================================================================

TestSample: incbin "Audio/Samples/test.aud"
