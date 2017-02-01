\\ MODE 7 keystroke logging editor

_LOAD_ON_START = FALSE
_START_CANVAS_CENTRE = TRUE
_COLOUR_LEFT_EDGE = TRUE
_START_GRAPHICS_CANVAS = TRUE

\\ Include bbc.h
BRKV=&202
BYTEV=&20A
WRCHV=&20E
EVNTV=&220

osrdch=&FFE0
oswrch=&FFEE
osword=&FFF1
osbyte=&FFF4
oscli=&FFF7
osfile=&FFDD

argv = &F2

MODE7_scr_addr = &7C00
MODE7_char_width = 40
MODE7_char_height = 25

CANVAS_width = 80               ; can be upto 255
CANVAS_height = 50              ; can be upto 255
CANVAS_size = CANVAS_width * CANVAS_height

IF _START_CANVAS_CENTRE
CANVAS_default_x = (CANVAS_width - MODE7_char_width) / 2
CANVAS_default_y = (CANVAS_height - MODE7_char_height) / 2
ELSE
CANVAS_default_x = 0
CANVAS_default_y = 0            ; start top left
ENDIF

AUTOREPEAT_delay = 32
AUTOREPEAT_period = 4

KEY_backspace = &7F
KEY_cursor_up = &8B
KEY_cursor_down = &8A
KEY_cursor_left = &88
KEY_cursor_right = &89

FNKEY_0 = &C0
FNKEY_1 = &C1
FNKEY_2 = &C2
FNKEY_3 = &C3
FNKEY_4 = &C4
FNKEY_5 = &C5
FNKEY_6 = &C6
FNKEY_7 = &C7
FNKEY_8 = &C8
FNKEY_9 = &C9

FNKEY_shift_0 = &E0
FNKEY_shift_1 = &E1
FNKEY_shift_2 = &E2
FNKEY_shift_3 = &E3
FNKEY_shift_4 = &E4
FNKEY_shift_5 = &E5
FNKEY_shift_6 = &E6
FNKEY_shift_7 = &E7
FNKEY_shift_8 = &E8
FNKEY_shift_9 = &E9

FNKEY_ctrl_0 = &90
FNKEY_ctrl_1 = &91
FNKEY_ctrl_2 = &92
FNKEY_ctrl_3 = &93
FNKEY_ctrl_4 = &94
FNKEY_ctrl_5 = &95
FNKEY_ctrl_6 = &96
FNKEY_ctrl_7 = &97
FNKEY_ctrl_8 = &98
FNKEY_ctrl_9 = &99

TELETEXT_graphic_red = 145
TELETEXT_graphic_green = 146
TELETEXT_graphic_yellow = 147
TELETEXT_graphic_blue = 148
TELETEXT_graphic_magenta = 149
TELETEXT_graphic_cyan = 150
TELETEXT_graphic_white = 151

TELETEXT_alpha_red = 129
TELETEXT_alpha_green = 130
TELETEXT_alpha_yellow = 131
TELETEXT_alpha_blue = 132
TELETEXT_alpha_magenta = 133
TELETEXT_alpha_cyan = 134
TELETEXT_alpha_white = 135

TELETEXT_contiguous_graphics = 153
TELETEXT_separated_graphics = 154
TELETEXT_new_background = 157
TELETEXT_black_background = 156
TELETEXT_hold_graphics = 158
TELETEXT_release_graphics = 159
TELETEXT_normal_height = 140
TELETEXT_double_height = 141
TELETEXT_flash = 136
TELETEXT_steady = 137

ORG &70
GUARD &8F

.readptr SKIP 2
.writeptr SKIP 2

.main_menu SKIP 1               ; 0=not enabled, 1=enabled
.main_state SKIP 1              ; 0=edit, 1=playback

.keypress_ptr SKIP 2            ; pointer into keypress buffer

.cursor_x SKIP 1
.cursor_y SKIP 1

.canvas_x SKIP 1
.canvas_y SKIP 1

.canvas_addr SKIP 2             ; address of top-left corner of canvas

.cursor_addr SKIP 2             ; screen address of cursor
.cursor_mode SKIP 1             ; 0=graphics, non-zero=text


\\ ZP

ORG &1900
GUARD &7C00

.start

.main
{
    LDX #&FF:TXS

    \\ Own error handler
    LDX #LO(error_handler)
    LDY #HI(error_handler)
    SEI
    STX BRKV
    STY BRKV+1
    CLI

    \\ Turn off cursor editing
    LDA #4
    LDX #1
    LDY #0
    JSR osbyte

    \\ Tell FN keys to report ascii from &C0
    LDA #225
    LDX #FNKEY_0
    LDY #0
    JSR osbyte

    \\ Tell Shift-FN keys to report ascii from &D0
    LDA #226
    LDX #FNKEY_shift_0
    LDY #0
    JSR osbyte

    \\ Turn ESCAPE into ascii
    LDA #229
    LDX #1
    LDY #0
    JSR osbyte

    \\ Autorepeat config
    LDA #11
    LDX #AUTOREPEAT_delay
    LDY #0
    JSR osbyte

    LDA #12
    LDX #AUTOREPEAT_period
    LDY #0
    JSR osbyte

    \\ Init state
    LDA #0
    STA main_state
    STA main_menu

    \\ Init keypress buffer
    JSR init_buffer
    
    \\ Init canvas
    JSR init_canvas

    \\ Init screen
    JSR init_screen

    IF _LOAD_ON_START
    LDA #LO(keystroke_buffer)
    STA osfile_params + 2
    LDA #HI(keystroke_buffer)
    STA osfile_params + 3

	LDA #0
	STA osfile_params + 6
    
	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
	LDA #&FF
    JSR osfile

    LDA #1
    STA main_state      ; playback!
    ENDIF

    .^main_loop

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

    \\ Editor mdde
    JSR editor_get_a_key

    CPX #&FF
    BEQ no_key

    CPX #27
    BEQ escape_pressed_in_editor

    \\ Store our keypress
    JSR buffer_store_a_keypress

    \\ Must have run out of buffer
    CPX #27
    BEQ escape_pressed_in_editor

    JMP act_on_key

    .handle_playback
    JSR buffer_get_a_keypress

    CPX #27
    BNE act_on_key

    JSR exit_playback
    JMP main_loop
 
    \\ Act on key
    .act_on_key
    JSR key_action_on_canvas

    .no_key
    JMP main_loop

    .escape_pressed_in_editor

    JSR enter_menu
    JMP main_loop

    .handle_menu

    JSR editor_get_a_key

    CPX #27
    BNE not_escape

    \\ Toggle Menu

    JSR exit_menu
    JMP main_loop

    .not_escape

    CPX #'1':BNE not_1
    LDX #27
    JSR buffer_store_a_keypress         ; currently marks end of keypress buffer

    JSR enter_playback
    JSR exit_menu
    JMP main_loop

    .not_1
    CPX #'2':BNE not_2
    JSR save_buffer
    JMP main_loop

    .not_2
    CPX #'3':BNE not_3
    JSR load_buffer
    JSR enter_playback
    JSR exit_menu
    JMP main_loop

    .not_3
    CPX #'4':BNE not_4
    JSR new_are_you_sure
    JMP main_loop

    .not_4
    CPX #'*':BNE not_star
    JSR star_command
    JMP main_loop
    .not_star

    JMP main_loop

    .return
    RTS
}

.confirm_text
{
    EQUS "New canvas, are you sure? ", 0
}

.new_are_you_sure
{
    LDX #LO(confirm_text)
    LDY #HI(confirm_text)
    JSR write_string

    JSR editor_get_a_key
    JSR oswrch
    CPX #'Y'
    BNE return

    \\ New
    JSR init_buffer
    JSR init_canvas
    JSR init_screen
    JSR exit_menu
    RTS

    .return
    LDX #LO(menu_prompt)
    LDY #HI(menu_prompt)
    JSR write_string

    RTS
}

.init_buffer
{
    LDA #LO(keystroke_buffer)
    STA keypress_ptr
    LDA #HI(keystroke_buffer)
    STA keypress_ptr+1

    .return
    RTS
}

.enter_playback
{
    \\ Initialise screen & canvas
    JSR init_canvas
    JSR init_screen

    \\ Reset keystroke buffer pointer
    LDA #LO(keystroke_buffer)
    STA keypress_ptr
    LDA #HI(keystroke_buffer)
    STA keypress_ptr+1

    \\ Enter playback state
    LDA #1
    STA main_state

    .return
    RTS
}

.remove_last_keypress
{
    \\ Should probably error check here...

    LDA keypress_ptr
    BNE no_carry 
    DEC keypress_ptr+1
    .no_carry
    DEC keypress_ptr

    RTS
}


.exit_playback
{
    \\ Remove last escape code
    JSR remove_last_keypress

    \\ Enter editor
    LDA #0
    STA main_state

    .return
    RTS
}

.exit_menu
{
    JSR clear_screen
    JSR copy_canvas_to_screen
    JSR update_cursor

    LDA #0
    STA main_menu
    
    .return
    RTS
}

.menu_text
{
   \\ EQUB 30           ; reset cursor top left
    EQUS "Teletext Slojd", 13,10
    EQUS "1) Playback", 13,10
    EQUS "2) Save keystrokes", 13,10
    EQUS "3) Load keystrokes", 13,10
    EQUS "4) New", 13,10
    EQUS "*) Command"
}
.menu_prompt
{
    EQUS 10, 13, " > ", 0
}

.write_string
{
    STX loop+1
    STY loop+2

    LDX #0
    .loop
    LDA menu_text, X
    BEQ done_loop
    JSR oswrch
    INX
    JMP loop
    .done_loop
    
    .return
    RTS
}

.hex_to_ascii
{
    EQUS "0123456789abcdef"
}

.bytes_free_text
{
    EQUS " bytes free", 13, 10, 0
}

MACRO COUNT_16BIT ptr, value
{
    LDX #0
    .loop
    LDA ptr+1
    CMP #HI(value)
    BCC finished
    BEQ test_lo

    .continue
    SEC
    LDA ptr
    SBC #LO(value)
    STA ptr
    LDA ptr+1
    SBC #HI(value)
    STA ptr+1
    INX
    JMP loop

    .test_lo
    LDA ptr
    CMP #LO(value)
    BCS continue 

    .finished
}
ENDMACRO

.write_bytes_free
{
    \\ Subtract our keypress pointer from top of memory
    SEC
    LDA #LO(MODE7_scr_addr)
    SBC keypress_ptr
    STA readptr
    LDA #HI(MODE7_scr_addr)
    SBC keypress_ptr+1
    STA readptr+1

    \\ Must be a better way to do this but anyway...
    COUNT_16BIT readptr, 10000
    LDA hex_to_ascii, X:JSR oswrch

    COUNT_16BIT readptr, 1000
    LDA hex_to_ascii, X:JSR oswrch

    COUNT_16BIT readptr, 100
    LDA hex_to_ascii, X:JSR oswrch

    COUNT_16BIT readptr, 10
    LDA hex_to_ascii, X:JSR oswrch

    LDX readptr
    LDA hex_to_ascii, X:JSR oswrch

    LDX #LO(bytes_free_text)
    LDY #HI(bytes_free_text)
    JSR write_string

    .return
    RTS
}

.enter_menu
{
    JSR clear_screen

    JSR write_bytes_free

    LDX #LO(menu_text)
    LDY #HI(menu_text)
    JSR write_string

    LDA #1
    STA main_menu

    .return
    RTS
}

.init_screen
{
    LDA #0
    STA cursor_y
    IF _COLOUR_LEFT_EDGE
    LDA #1
    ENDIF
    STA cursor_x

    JSR clear_screen
    JSR copy_canvas_to_screen
    JSR update_cursor

    .return
    RTS
}

.clear_screen
{
    LDA #22
    JSR oswrch
    LDA #7
    JSR oswrch

    .return
    RTS
}

\\ Clear canvas
.init_canvas
{
    LDA #CANVAS_default_x
    STA canvas_x
    LDA #CANVAS_default_y
    STA canvas_y

    LDA #LO(canvas_data)
    STA writeptr
    LDA #HI(canvas_data)
    STA writeptr+1

    LDX #0
    .yloop
    LDY #0

    IF _START_GRAPHICS_CANVAS
    LDA #TELETEXT_graphic_white
    STA (writeptr), Y
    INY
    ENDIF

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
IF _COLOUR_LEFT_EDGE
.copy_canvas_to_screen
{
    LDA #LO(canvas_data)
    STA readptr
    LDA #HI(canvas_data)
    STA readptr+1

    \\ Calculate start of canvas line

    LDX canvas_y
    BEQ yloop_done
    .yloop
    CLC
    LDA readptr
    ADC #CANVAS_width
    STA readptr
    LDA readptr+1
    ADC #0
    STA readptr+1
    DEX
    BNE yloop
    .yloop_done

    \\ Copy to
    LDA #LO(MODE7_scr_addr)
    STA writeptr
    LDA #HI(MODE7_scr_addr)
    STA writeptr+1

    LDX #0

    .line_loop

    \\ Look for first colour code before canvas
    LDY canvas_x
    BEQ no_colour_found
    DEY
    .search_loop
    LDA (readptr), Y
    CMP #TELETEXT_graphic_red
    BCC try_alpha
    CMP #TELETEXT_graphic_white+1
    BCS try_alpha

    \\ Found a graphics code
    JMP found_colour

    .try_alpha
    CMP #TELETEXT_alpha_red
    BCC continue
    CMP #TELETEXT_alpha_white+1
    BCS continue

    \\ Found an alpha code
    JMP found_colour

    .continue
    CPY #0
    BEQ no_colour_found
    DEY
    JMP search_loop

    .no_colour_found
    LDA #32

    .found_colour
    \\ Save our colour code in column 0

    LDY #0
    STA (writeptr), Y

    \\ Can't indirect index X so mod code
    LDA writeptr
    STA screen_write_addr+1
    LDA writeptr+1
    STA screen_write_addr+2

    \\ Save X our row counter
    STX row_count+1

    \\ Start at column 1 on screen
    LDX #1
    LDY canvas_x

    .copy_loop
    LDA (readptr), Y        ; canvas
    .screen_write_addr
    STA &FFFF, X            ; screen

    INY
    INX

    CPX #MODE7_char_width
    BNE copy_loop

    \\ Next line of both
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

    .row_count
    LDX #0
    INX
    CPX #MODE7_char_height
    BNE line_loop

    .return
    RTS
}
ELSE
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
ENDIF

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
    \\ Check if we've reached the top of buffer
    LDA keypress_ptr
    CMP #LO(MODE7_scr_addr-1)
    BNE ok_to_store
    LDA keypress_ptr+1
    CMP #HI(MODE7_scr_addr-1)
    BCC ok_to_store

    \\ Can store escape in last block
    CPX #27
    BEQ ok_to_store

    \\ But otherwise don't store but flag back
    LDX #27
    RTS

    .ok_to_store
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

    IF _COLOUR_LEFT_EDGE
    SEC
    LDA cursor_x
    SBC #1              ; actually 1, because cursor X can never be 0
    CLC
    ADC canvas_addr
    ELSE
    CLC
    LDA canvas_addr
    ADC cursor_x
    ENDIF

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

.calc_cursor_addr
{
    LDY cursor_y
    CLC
    LDA mode7_addr_y_LO, Y
    ADC cursor_x
    STA cursor_addr
    LDA mode7_addr_y_HI, Y
    ADC #0
    STA cursor_addr+1

    .return
    RTS
}

.update_cursor
{
    \\ Character row adddress
    LDY cursor_y
    LDA mode7_addr_y_LO, Y
    STA readptr
    LDA mode7_addr_y_HI, Y
    STA readptr+1
    
    \\ Cursor type
    LDX #0             ; line

    LDY cursor_x
    .loop
    LDA (readptr), Y
    CMP #TELETEXT_graphic_red
    BCC try_alpha
    CMP #TELETEXT_graphic_white+1
    BCS try_alpha

    \\ Found a graphics code
    LDX #18
    JMP scanned_line

    .try_alpha
    CMP #TELETEXT_alpha_red
    BCC continue
    CMP #TELETEXT_alpha_white+1
    BCS continue

    \\ Found an alpha code
    JMP scanned_line

    .continue
    CPY #0
    BEQ scanned_line
    DEY
    JMP loop

    .scanned_line

    \\ Solid cursor
    LDA #10
    STA &FE00
    STX cursor_mode
    STX &FE01

    \\ Calc exact cursor address
    CLC
    LDA readptr
    ADC cursor_x
    STA cursor_addr
    LDA readptr+1
    ADC #0
    STA cursor_addr+1

    \\ Set cursor position
    LDA #14
    STA &FE00
    SEC
    LDA cursor_addr+1
    SBC #&74
    EOR #&20
    STA &FE01

    LDA #15
    STA &FE00
    LDA cursor_addr
    STA &FE01

    .return
    RTS
}

.write_to_screen
{
    \\ So we know where to write
    PHA
    JSR calc_cursor_addr
    PLA

    \\ Write
    LDY #0
    STA (cursor_addr), Y

    .return
    RTS
}

.map_key_to_char
{
    STX key_value+1
    LDY #0

    .loop
    LDA map_char_table, Y
    CMP #&FF
    BEQ not_found

    INY
    .key_value
    CMP #0
    BEQ found

    INY
    JMP loop

    .found
    LDA map_char_table, Y
    TAX

    .not_found
    RTS
}

.map_key_to_code                ; must preserve X
{
    STX key_value+1
    LDY #0

    .loop
    LDA map_code_table, Y
    CMP #&FF
    BEQ not_found

    INY
    .key_value
    CMP #0
    BEQ found

    INY
    JMP loop

    .found
    LDA map_code_table, Y

    .not_found
    RTS
}

.key_action_on_canvas
{
    \\ Check for special keys
    CPX #&90
    BCS content_key

    CPX #&7F
    BCS control_key

    \\ Content key
    .content_key

    \\ Check keys for Teletext content codes first
    JSR map_key_to_code
    CMP #&FF
    BNE write_char

    \\ If not then its a regular key

    \\ If we're in alpha mode just write it as is
    LDA cursor_mode
    BEQ alpha_mapping

    \\ If we're in graphics mode do fancy mapping
    JSR map_key_to_char

    .alpha_mapping
    TXA

    .write_char
    JSR write_to_canvas
    JSR write_to_screen

    \\ Update cursor mode
    JSR update_cursor

    \\ Decide whether to move cursor
    LDX cursor_mode
    BNE dont_move_cursor

    \\ Move cursor right in alpha mode
    JSR move_cursor_right
    JSR update_cursor

    .dont_move_cursor
    JMP return

    \\ Control keys, cursor etc.
    .control_key
    CPX #KEY_cursor_up:BNE not_up
    JSR move_cursor_up
    .not_up
    CPX #KEY_cursor_down:BNE not_down
    JSR move_cursor_down
    .not_down
    CPX #KEY_cursor_left:BNE not_left
    JSR move_cursor_left
    .not_left
    CPX #KEY_cursor_right:BNE not_right
    JSR move_cursor_right
    .not_right
    CPX #KEY_backspace:BNE not_backsp
    JSR move_cursor_left
    LDA #32
    JSR write_to_canvas
    JSR write_to_screen

    .not_backsp
    JSR update_cursor
    JMP return

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
    IF _COLOUR_LEFT_EDGE
    CPY #1
    ENDIF
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

.osfile_params
{
    EQUW input_buffer
    EQUD 0                  ; load address
    EQUD 0                  ; exec address
    EQUD keystroke_buffer   ; start addr
    EQUD 0                  ; end addr
}

\\ Save buffer

.save_text
{
    EQUS "Save filename? ", 0
}

.done_text
{
    EQUS "   Success!", 0
}

.input_buffer
EQUS "HELLO", 13
SKIP 24

.input_params
{
    EQUW input_buffer
    EQUB 29
    EQUB ' '
    EQUB 127
}

.save_buffer
{
    LDX #LO(save_text)
    LDY #HI(save_text)
    JSR write_string
    
    LDA #0
    LDX #LO(input_params)
    LDY #HI(input_params)
    JSR osword

    BCS return

    LDX #27
    JSR buffer_store_a_keypress         ; currently marks end of keypress buffer

	LDA #LO(keystroke_buffer)
    STA osfile_params + 2
	LDA #HI(keystroke_buffer)
    STA osfile_params + 3

	LDA #LO(keystroke_buffer)
    STA osfile_params + 10
	LDA #HI(keystroke_buffer)
    STA osfile_params + 11

    LDA keypress_ptr
    STA osfile_params + 14
    LDA keypress_ptr+1
    STA osfile_params + 15
    
	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
    LDA #0
    JSR osfile

    JSR remove_last_keypress

    LDX #LO(done_text)
    LDY #HI(done_text)
    JSR write_string

    .return
    LDX #LO(menu_prompt)
    LDY #HI(menu_prompt)
    JSR write_string

    RTS
}

\\ Load buffer
.load_text
{
    EQUS "Load filename? ", 0
}

.load_buffer
{
    LDX #LO(load_text)
    LDY #HI(load_text)
    JSR write_string
    
    LDA #0
    LDX #LO(input_params)
    LDY #HI(input_params)
    JSR osword

    BCS return

    LDA #LO(keystroke_buffer)
    STA osfile_params + 2
    LDA #HI(keystroke_buffer)
    STA osfile_params + 3

	LDA #0
	STA osfile_params + 6
    
	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
	LDA #&FF
    JSR osfile

    LDX #LO(done_text)
    LDY #HI(done_text)
    JSR write_string

    .return
    LDX #LO(menu_prompt)
    LDY #HI(menu_prompt)
    JSR write_string

    RTS
}

.error_text
{
    EQUS "   ERROR: ", 0
}

.error_handler
{
    LDX #LO(error_text)
    LDY #HI(error_text)
    JSR write_string

    LDY &FE
    LDX &FD
    INX
    BNE no_carry
    INY
    .no_carry
    JSR write_string

    LDX #LO(menu_prompt)
    LDY #HI(menu_prompt)
    JSR write_string

    LDX #&FF:TXS
    JMP main_loop
}

.star_command
{
    TXA:JSR oswrch

    LDA #0
    LDX #LO(input_params)
    LDY #HI(input_params)
    JSR osword

    BCS return

    LDX #LO(input_buffer)
    LDY #HI(input_buffer)
    JSR oscli

    .return
    LDX #LO(menu_prompt)
    LDY #HI(menu_prompt)
    JSR write_string

    RTS
}

\\ Lookups

PIXEL_TL=1
PIXEL_TR=2
PIXEL_ML=4
PIXEL_MR=8
PIXEL_BL=16
PIXEL_BR=64
ALL_PIXELS=PIXEL_TL+PIXEL_TR+PIXEL_ML+PIXEL_MR+PIXEL_BL+PIXEL_BR

MACRO KEY_TO_CHAR key, pixel
{
    EQUB key, 32 OR (pixel)
}
ENDMACRO

MACRO KEY_TO_INVCHAR key, pixel
{
    EQUB key, 32 OR (pixel EOR ALL_PIXELS)
}
ENDMACRO

MACRO KEY_TO_CODE key, code
{
    EQUB key, code
}
ENDMACRO

.map_char_table
{
    \\ Zero + 6 pixels
    KEY_TO_CHAR ' ', 0
    
    \\ One pixels
    KEY_TO_CHAR 'Q', PIXEL_TL
    KEY_TO_CHAR 'A', PIXEL_ML
    KEY_TO_CHAR 'Z', PIXEL_BL
    
    KEY_TO_CHAR 'W', PIXEL_TR
    KEY_TO_CHAR 'S', PIXEL_MR
    KEY_TO_CHAR 'X', PIXEL_BR

    \\ Five pixels
    KEY_TO_INVCHAR 'q', PIXEL_TL
    KEY_TO_INVCHAR 'a', PIXEL_ML
    KEY_TO_INVCHAR 'z', PIXEL_BL
    KEY_TO_INVCHAR 'w', PIXEL_TR
    KEY_TO_INVCHAR 's', PIXEL_MR
    KEY_TO_INVCHAR 'x', PIXEL_BR

    \\ Two pixels
    KEY_TO_CHAR 'E', PIXEL_TL+PIXEL_TR
    KEY_TO_CHAR 'D', PIXEL_ML+PIXEL_MR
    KEY_TO_CHAR 'C', PIXEL_BL+PIXEL_BR

    KEY_TO_CHAR 'R', PIXEL_TL+PIXEL_ML
    KEY_TO_CHAR 'F', PIXEL_TL+PIXEL_BL
    KEY_TO_CHAR 'V', PIXEL_ML+PIXEL_BL

    KEY_TO_CHAR 'T', PIXEL_TR+PIXEL_MR
    KEY_TO_CHAR 'G', PIXEL_TR+PIXEL_BR
    KEY_TO_CHAR 'B', PIXEL_MR+PIXEL_BR

    KEY_TO_CHAR 'Y', PIXEL_TL+PIXEL_MR
    KEY_TO_CHAR 'H', PIXEL_TL+PIXEL_BR
    KEY_TO_CHAR 'N', PIXEL_BR+PIXEL_ML

    KEY_TO_CHAR 'U', PIXEL_TR+PIXEL_ML
    KEY_TO_CHAR 'J', PIXEL_TR+PIXEL_BL
    KEY_TO_CHAR 'M', PIXEL_BL+PIXEL_MR

    \\ Four pixels
    KEY_TO_INVCHAR 'e', PIXEL_TL+PIXEL_TR
    KEY_TO_INVCHAR 'd', PIXEL_ML+PIXEL_MR
    KEY_TO_INVCHAR 'c', PIXEL_BL+PIXEL_BR

    KEY_TO_INVCHAR 'r', PIXEL_TL+PIXEL_ML
    KEY_TO_INVCHAR 'f', PIXEL_TL+PIXEL_BL
    KEY_TO_INVCHAR 'v', PIXEL_ML+PIXEL_BL

    KEY_TO_INVCHAR 't', PIXEL_TR+PIXEL_MR
    KEY_TO_INVCHAR 'g', PIXEL_TR+PIXEL_BR
    KEY_TO_INVCHAR 'b', PIXEL_MR+PIXEL_BR

    KEY_TO_INVCHAR 'y', PIXEL_TL+PIXEL_MR
    KEY_TO_INVCHAR 'h', PIXEL_TL+PIXEL_BR
    KEY_TO_INVCHAR 'n', PIXEL_BR+PIXEL_ML

    KEY_TO_INVCHAR 'u', PIXEL_TR+PIXEL_ML
    KEY_TO_INVCHAR 'j', PIXEL_TR+PIXEL_BL
    KEY_TO_INVCHAR 'm', PIXEL_BL+PIXEL_MR

    \\ Three pixels

    KEY_TO_CHAR 'I', PIXEL_MR+PIXEL_ML+PIXEL_BL         ; mid left up arrow
    KEY_TO_INVCHAR 'i', PIXEL_MR+PIXEL_ML+PIXEL_BL      ; invert

    KEY_TO_CHAR 'K', PIXEL_TL+PIXEL_ML+PIXEL_MR         ; mid left down arrow
    KEY_TO_INVCHAR 'k', PIXEL_TL+PIXEL_ML+PIXEL_MR      ; invert

    KEY_TO_CHAR ',', PIXEL_TR+PIXEL_TL+PIXEL_ML         ; top left arrow
    KEY_TO_INVCHAR '<', PIXEL_TR+PIXEL_TL+PIXEL_ML      ; bottom right arrow

    KEY_TO_CHAR 'O', PIXEL_MR+PIXEL_ML+PIXEL_BR         ; mid right up arrow
    KEY_TO_INVCHAR 'o', PIXEL_MR+PIXEL_ML+PIXEL_BR      ; invert

    KEY_TO_CHAR 'L', PIXEL_TR+PIXEL_ML+PIXEL_MR         ; mid right down arrow
    KEY_TO_INVCHAR 'l', PIXEL_TR+PIXEL_ML+PIXEL_MR      ; invert

    KEY_TO_CHAR '.', PIXEL_TR+PIXEL_TL+PIXEL_MR         ; top right arrow
    KEY_TO_INVCHAR '>', PIXEL_TR+PIXEL_TL+PIXEL_MR      ; bottom left arrow

    KEY_TO_CHAR 'P', PIXEL_TR+PIXEL_ML+PIXEL_BL         ; top left curve
    KEY_TO_INVCHAR 'p', PIXEL_TR+PIXEL_ML+PIXEL_BL         ; invert

    KEY_TO_CHAR ';', PIXEL_TL+PIXEL_ML+PIXEL_BR         ; top right curve
    KEY_TO_INVCHAR '+', PIXEL_TL+PIXEL_ML+PIXEL_BR         ; invert


    KEY_TO_CHAR '[', PIXEL_TR+PIXEL_ML+PIXEL_BR         ; left face
    KEY_TO_INVCHAR '{', PIXEL_TR+PIXEL_ML+PIXEL_BR         ; left face
    KEY_TO_INVCHAR ']', PIXEL_TR+PIXEL_ML+PIXEL_BR         ; right face
    KEY_TO_CHAR '}', PIXEL_TR+PIXEL_ML+PIXEL_BR         ; right face

    KEY_TO_CHAR '/', PIXEL_TL+PIXEL_ML+PIXEL_BL         ; left vertical bar
    KEY_TO_INVCHAR '?', PIXEL_TL+PIXEL_ML+PIXEL_BL         ; right vertical bar

    KEY_TO_INVCHAR ':', PIXEL_TL+PIXEL_ML+PIXEL_BL         ; right vertical bar
    KEY_TO_CHAR '*', PIXEL_TL+PIXEL_ML+PIXEL_BL         ; left vertical bar

    EQUB &FF
}

.map_code_table
{
    \\ FN keys for graphic colour
    KEY_TO_CODE FNKEY_1, TELETEXT_graphic_red
    KEY_TO_CODE FNKEY_2, TELETEXT_graphic_green
    KEY_TO_CODE FNKEY_3, TELETEXT_graphic_yellow
    KEY_TO_CODE FNKEY_4, TELETEXT_graphic_blue
    KEY_TO_CODE FNKEY_5, TELETEXT_graphic_magenta
    KEY_TO_CODE FNKEY_6, TELETEXT_graphic_cyan
    KEY_TO_CODE FNKEY_7, TELETEXT_graphic_white

    \\ Shift FN keys for alpha colour
    KEY_TO_CODE FNKEY_shift_1, TELETEXT_alpha_red
    KEY_TO_CODE FNKEY_shift_2, TELETEXT_alpha_green
    KEY_TO_CODE FNKEY_shift_3, TELETEXT_alpha_yellow
    KEY_TO_CODE FNKEY_shift_4, TELETEXT_alpha_blue
    KEY_TO_CODE FNKEY_shift_5, TELETEXT_alpha_magenta
    KEY_TO_CODE FNKEY_shift_6, TELETEXT_alpha_cyan
    KEY_TO_CODE FNKEY_shift_7, TELETEXT_alpha_white

    \\ Ctrl FN keys for all other teletext codes
    KEY_TO_CODE FNKEY_ctrl_0, TELETEXT_black_background
    KEY_TO_CODE FNKEY_ctrl_1, TELETEXT_new_background
    KEY_TO_CODE FNKEY_ctrl_2, TELETEXT_contiguous_graphics
    KEY_TO_CODE FNKEY_ctrl_3, TELETEXT_separated_graphics
    KEY_TO_CODE FNKEY_ctrl_4, TELETEXT_steady
    KEY_TO_CODE FNKEY_ctrl_5, TELETEXT_flash
    KEY_TO_CODE FNKEY_ctrl_6, TELETEXT_normal_height
    KEY_TO_CODE FNKEY_ctrl_7, TELETEXT_double_height
    KEY_TO_CODE FNKEY_ctrl_8, TELETEXT_release_graphics
    KEY_TO_CODE FNKEY_ctrl_9, TELETEXT_hold_graphics

    KEY_TO_CODE 13, &7F            ; return = block

    EQUB &FF
}

\\ Look up tables
.mode7_addr_y_HI
FOR n,0,24,1
EQUB HI(MODE7_scr_addr + n * MODE7_char_width)
NEXT

.mode7_addr_y_LO
FOR n,0,24,1
EQUB LO(MODE7_scr_addr + n * MODE7_char_width)
NEXT

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
