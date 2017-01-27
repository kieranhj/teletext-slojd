\\ MODE 7 keystroke logging editor


\\ Include bbc.h
BYTEV=&20A
WRCHV=&20E
EVNTV=&220

osrdch=&FFE0
oswrch=&FFEE
osbyte=&FFF4
osfile=&FFDD

argv = &F2

MODE7_scr_addr = &7C00
MODE7_char_width = 40
MODE7_char_height = 25

CANVAS_width = 80               ; can be upto 255
CANVAS_height = 50              ; can be upto 255
CANVAS_size = CANVAS_width * CANVAS_height

FNKEY_0 = &C0
FNKEY_shift_0 = &80
FNKEY_ctrl_0 = &90

STATE_edit = 0
STATE_playback = 1

ORG &70
GUARD &8F

.readptr SKIP 2
.writeptr SKIP 2

.main_menu SKIP 1
.main_state SKIP 1              ; edit, playback

.keypress_ptr SKIP 2

.cursor_x SKIP 1
.cursor_y SKIP 1

.canvas_x SKIP 1
.canvas_y SKIP 1

.canvas_addr SKIP 2

.scr_ptr SKIP 2

.debounce SKIP 1

\\ ZP

ORG &1900
GUARD &7C00

.start

.main
{
    \\ MODE 7
    LDA #22
    JSR oswrch
    LDA #7
    JSR oswrch

    \\ Turn off cursor editing
    LDA #4
    LDX #1
    JSR osbyte

    \\ Tell FN keys to report ascii from &C0
    LDA #225
    LDX #FNKEY_0
    JSR osbyte

    LDA #&FF
    STA debounce

    \\ Init state
    LDA #0
    STA main_state
    STA main_menu

    LDA #0
    STA cursor_x
    STA cursor_y
    STA canvas_x
    STA canvas_y

    LDA #LO(keystroke_buffer)
    STA keypress_ptr
    LDA #HI(keystroke_buffer)
    STA keypress_ptr+1
    
    \\ Solid cursor
    LDA #10
    STA &FE00
    LDA #0
    STA &FE01

    \\ Init canvas
    JSR clear_canvas

    .loop

    \\ Vsync
    LDA #19
    JSR osbyte

    \\ Menu or not?

    LDA main_menu
    BNE handle_menu

    \\ In edit/playback

    LDA main_state
    BNE handle_playback

    \\ Toggle Menu

    \\ Edit
    JSR editor_get_a_key
    CPX #&FF
    BEQ no_key

    JSR buffer_store_a_keypress
    JMP act_on_key

    .handle_playback
    JSR buffer_get_a_keypress

    \\ Act on key
    .act_on_key
    JSR key_action_on_canvas

    .no_key
    JMP loop

    .handle_menu

    \\ Toggle Menu

    JMP loop

    .return
    RTS
}

\\ Clear canvas
.clear_canvas
{
    LDA #LO(canvas_data)
    STA writeptr
    LDA #HI(canvas_data)
    STA writeptr+1

    LDA #32

    LDX #0
    .yloop
    LDY #0
    .xloop
    STA (writeptr), Y
    INY
    CPY #CANVAS_width
    BNE xloop

    CLC
    LDA writeptr
    ADC #CANVAS_width
    STA writeptr
    LDA writeptr+1
    ADC #0
    STA writeptr+1

    INX
    CPX #CANVAS_height
    BNE yloop

    .return
    RTS
}

.calc_canvas_addr
{
    CLC
    LDA #LO(canvas_data)
    ADC canvas_x
    STA canvas_addr
    LDA #HI(canvas_data)
    ADC #0
    STA canvas_addr+1

    LDX canvas_y
    BEQ yloop_done
    .yloop
    CLC
    LDA #LO(canvas_data)
    ADC #CANVAS_width
    STA canvas_addr
    LDA #HI(canvas_data)
    ADC #0
    STA canvas_addr+1
    DEX
    BNE yloop
    .yloop_done

    .return
    RTS
}

\\ Copy canvas to screen
.copy_canvas_to_screen
{
    JSR calc_canvas_addr

    \\ Copy from
    LDA canvas_addr
    STA readptr
    LDA canvas_addr+1
    STA readptr+1

    \\ Copy to
    LDA #LO(MODE7_scr_addr)
    STA writeptr
    LDA #HI(MODE7_scr_addr)
    STA writeptr+1

    LDX #0
    .copyloop

    \\ From canvas to screen
    LDY #0
    .lineloop
    LDA (readptr), Y
    STA (writeptr), Y
    INY
    CPY #MODE7_char_width
    BNE lineloop

    \\ Next line of canvas
    CLC
    LDA readptr
    ADC #CANVAS_width
    STA readptr
    LDA readptr+1
    ADC #0
    STA readptr+1
    
    \\ Next line of screen
    CLC
    LDA writeptr
    ADC #MODE7_char_width
    STA writeptr
    LDA writeptr+1
    ADC #0
    STA writeptr+1

    INX
    CPX #MODE7_char_height
    BNE copyloop

    .return
    RTS
}

\\ Editor fns

\\ Get a key
.editor_get_a_key
{
    \\ Use OSRDCH for easy input
    JSR osrdch
    TAX             ; return in X
    BCC return      ; read OK

IF 0
    \\ Try keyboard scan instead
    LDA #&79
    LDX #&10
    JSR osbyte

    \\ No keypressed
    CPX #&FF
    BEQ return
    CPX debounce
    BEQ no_key
    
    CPX #32:BNE not_f0
    LDX #140:JMP got_key
    .not_f0
    CPX #71:BNE not_f1
    LDX #141:JMP got_key
    .not_f1
    CPX #72:BNE not_f2
    LDX #142:JMP got_key
    .not_f2
    CPX #73:BNE not_f3
    LDX #143:JMP got_key
    .not_f3
    CPX #14:BNE not_f4
    LDX #144:JMP got_key
    .not_f4
    CPX #74:BNE not_f5
    LDX #145:JMP got_key
    .not_f5
    CPX #75:BNE not_f6
    LDX #146:JMP got_key
    .not_f6
    CPX #16:BNE not_f7
    LDX #147:JMP got_key
    .not_f7
    CPX #76:BNE not_f8
    LDX #148:JMP got_key
    .not_f8
    CPX #77:BNE not_f9
    LDX #149:JMP got_key
    .not_f9
    JMP no_key

    .got_key
    STX debounce
    JMP return
ENDIF

    \\ No key
    .no_key
    LDX #&FF

    .return
    RTS
}

.buffer_store_a_keypress
{
    TXA

    LDY #0
    STA (keypress_ptr), Y

    INC keypress_ptr
    BNE no_carry
    INC keypress_ptr+1
    .no_carry

    .return
    RTS
}

.buffer_get_a_keypress
{
    \\ Maybe need a delay?
    \\ Also need a signal for end of buffer

    LDY #0
    LDA (keypress_ptr), Y
    TAX

    INC keypress_ptr
    BNE no_carry
    INC keypress_ptr+1
    .no_carry

    .return
    RTS
}

.write_to_canvas
{
    PHA

    JSR calc_canvas_addr

    CLC
    LDA canvas_addr
    ADC cursor_x
    STA writeptr
    LDA canvas_addr+1
    ADC #0
    STA writeptr+1

    LDX cursor_y
    BEQ yloop_done
    .yloop
    CLC
    LDA writeptr
    ADC #CANVAS_width
    STA writeptr
    LDA writeptr+1
    ADC #0
    STA writeptr+1
    DEX
    BNE yloop
    .yloop_done

    LDY #0
    PLA
    STA (writeptr), Y

    .return
    RTS
}

.calc_scr_ptr
{
    CLC
    LDA #LO(MODE7_scr_addr)
    ADC cursor_x
    STA scr_ptr
    LDA #HI(MODE7_scr_addr)
    ADC #0
    STA scr_ptr+1

    LDX cursor_y
    BEQ yloop_done
    .yloop
    CLC
    LDA scr_ptr
    ADC #MODE7_char_width
    STA scr_ptr
    LDA scr_ptr+1
    ADC #0
    STA scr_ptr+1
    DEX
    BNE yloop
    .yloop_done

    .return
    RTS
}

.set_cursor
{
    LDA #14
    STA &FE00
    SEC
    LDA scr_ptr+1
    SBC #&74
    EOR #&20
    STA &FE01

    LDA #15
    STA &FE00
    LDA scr_ptr
    STA &FE01

    .return
    RTS
}

.write_to_screen
{
    PHA
    JSR calc_scr_ptr
    PLA

    LDY #0
    STA (scr_ptr), Y

    .return
    RTS
}

.key_action_on_canvas
{
    CPX #FNKEY_0
    BCS colour_key

    CPX #127
    BCS control_key

    \\ Content key
    TXA
    JSR write_to_screen
    JSR write_to_canvas
    JMP return

    .control_key
    CPX #139:BNE not_up
    JSR move_cursor_up
    .not_up
    CPX #138:BNE not_down
    JSR move_cursor_down
    .not_down
    CPX #136:BNE not_left
    JSR move_cursor_left
    .not_left
    CPX #137:BNE not_right
    JSR move_cursor_right
    .not_right

    JSR calc_scr_ptr
    JSR set_cursor
    JMP return

    .colour_key
    TXA
    SEC
    SBC #48
    JSR write_to_screen
    JSR write_to_canvas

    .return
    RTS
}

.move_cursor_right
{
    LDY cursor_x
    CPY #MODE7_char_width-1
    BCS return
    INY

    .return
    STY cursor_x
    RTS
}

.move_cursor_left
{
    LDY cursor_x
    BEQ return
    DEY

    .return
    STY cursor_x
    RTS
}

.move_cursor_up
{
    LDY cursor_y
    BEQ return
    DEY

    .return
    STY cursor_y
    RTS
}

.move_cursor_down
{
    LDY cursor_y
    CPY #MODE7_char_height-1
    BCS return
    INY

    .return
    STY cursor_y
    RTS
}

\\ Menu actions

\\ Save buffer

\\ Load buffer

\\ Clear buffer


\\ Lookups

\\ Mapping of keys to screen?
\\ If using actual key presses then need to store combinations, i.e. CTRL+
\\ Better to store an ascii value with control codes for special keys
\\ Main pain is fn keys which don't come through in osrdch but do with INKEY
\\ Maybe should have done all this in BASIC?  :S

.end

\\ Run-time data

ALIGN &100
.canvas_data
SKIP CANVAS_size

PRINT "Canvas start= ", ~canvas_data
PRINT "Canvas size= ", CANVAS_size

ALIGN &100
.keystroke_buffer

PRINT "Keystroke start= ", ~keystroke_buffer
PRINT "Keystroke max size= ", (&7C00 - keystroke_buffer)

SAVE "TTSLOJD", start, end, main, start
