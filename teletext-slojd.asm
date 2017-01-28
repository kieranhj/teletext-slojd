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

    \\ Turn ESCAPE into ascii
    LDA #229
    LDX #1
    JSR osbyte

    \\ Init state
    LDA #0
    STA main_state
    STA main_menu

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
    JSR init_canvas

    \\ Init screen
    JSR init_screen

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

    CPX #27
    BEQ escape_pressed_in_editor

    JSR buffer_store_a_keypress
    JMP act_on_key

    .handle_playback
    JSR buffer_get_a_keypress

    CPX #27
    BNE act_on_key

    \\ Remove last escape code
    {
        LDA keypress_ptr
        BNE no_carry 
        DEC keypress_ptr+1
        .no_carry
        DEC keypress_ptr
    }

    LDA #0
    STA main_state
    JMP no_key
 
    \\ Act on key
    .act_on_key
    JSR key_action_on_canvas

    .no_key
    JMP loop

    .escape_pressed_in_editor
    JSR buffer_store_a_keypress

    JSR init_screen
    JSR init_canvas

    LDA #LO(keystroke_buffer)
    STA keypress_ptr
    LDA #HI(keystroke_buffer)
    STA keypress_ptr+1

    LDA #1
    STA main_state

    JMP loop

    .handle_menu

    \\ Toggle Menu

    JMP loop

    .return
    RTS
}

.init_screen
{
    LDA #0
    STA cursor_x
    STA cursor_y

    LDA #LO(MODE7_scr_addr)
    STA writeptr
    LDA #HI(MODE7_scr_addr)
    STA writeptr+1

    LDX #0
    .yloop
    LDY #0
    LDA #32

    .xloop
    STA (writeptr), Y
    INY
    CPY #MODE7_char_width
    BNE xloop

    CLC
    LDA writeptr
    ADC #MODE7_char_width
    STA writeptr
    LDA writeptr+1
    ADC #0
    STA writeptr+1

    INX
    CPX #MODE7_char_height
    BNE yloop

    .return
    RTS
}

\\ Clear canvas
.init_canvas
{
    LDA #0
    STA canvas_x
    STA canvas_y

    LDA #LO(canvas_data)
    STA writeptr
    LDA #HI(canvas_data)
    STA writeptr+1

    LDX #0
    .yloop
    LDY #0
    LDA #32

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
    LDA canvas_addr
    ADC #CANVAS_width
    STA canvas_addr
    LDA canvas_addr+1
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
    BCS right_edge
    INY
    STY cursor_x
    RTS

    .right_edge
    LDY canvas_x
    CPY #CANVAS_width-MODE7_char_width
    BCS return

    INY
    STY canvas_x
    JSR copy_canvas_to_screen

    .return
    RTS
}

.move_cursor_left
{
    LDY cursor_x
    BEQ left_edge
    DEY
    STY cursor_x
    RTS

    .left_edge
    LDY canvas_x
    BEQ return

    DEY
    STY canvas_x
    JSR copy_canvas_to_screen

    .return
    RTS
}

.move_cursor_up
{
    LDY cursor_y
    BEQ top_edge
    DEY
    STY cursor_y
    RTS

    .top_edge
    LDY canvas_y
    BEQ return

    DEY
    STY canvas_y
    JSR copy_canvas_to_screen

    .return
    RTS
}

.move_cursor_down
{
    LDY cursor_y
    CPY #MODE7_char_height-1
    BCS bottom_edge
    INY
    STY cursor_y
    RTS

    .bottom_edge
    LDY canvas_y
    CPY #CANVAS_height-MODE7_char_height
    BCS return

    INY
    STY canvas_y
    JSR copy_canvas_to_screen

    .return
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
