; ch64edit.asm - Character Sets Editor for Commodore 64
; 
; Copyright (c) 2024 by David R. Van Wagner
; MIT LICENSE
; github.com/davervw/ch64edit
; davevw.com
;

video = $0400
color_ram = $D800
columns = 40
rows = 25

charrom = $d000
charout = $ffd2
getkey = $ffe4
setlfs = $ffba
setnam = $ffbd
fsave = $ffd8
fload = $ffd5

undo_buffer = $33c
undo_limit = 24 ; must save extra one space for redo (uses 25)
jiffyclock = $a2 ; increased by one every 1/60 of a second
jiffyblink = $a3
undo_count = $a4
redo_count = $a5
clipboard = $251
clipboard_present = $a6
save_cursor = $a7
tempbuff = $a8 ; 8 bytes free to use temporarily a8-af
colorptr = $b0
pixelcolorptr = $b2 ; pointer to pixel cursor in color ram
lineptr = $b4 ; used with menulinesout
border = 53280
background = 53281
foreground = 646
charptr = $22 ; pointer to character image data for display/edit
dispptr = $24 ; pointer to screen for displaying pixels and hex values
temp2 = $26
pixelx = $27 ; left(0) to right(7)
pixely = $28 ; up(0) to down(7)
pixelptr = $29 ; pointer to pixel cursor in video ram
basicstartptr = $2b ; 43/44
ptr1 = $fb
ptr2 = $fd
temp = $ff

clearchar = $93
homechar = $13
spacechar = $20
starchar = $2a ; asterisk

*=$0801 ; C64 start
start:
!byte $0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 ; 10 SYS6157 (without leading zero byte because starts at offset 0)

; 0800-17ff is reserved for editable character images, will be initialized from charrom $D000 for one-time initialization

*=$1800
new_start:
!byte $00,$0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 ; 10 SYS6157 (with leading zero byte because starts at offset 1)
begin:
  ; everytime init values
  jsr reset_undo
  clc
  ror clipboard_present
  clc
  ror hide_mode
  lda #<(start-1)
  sta charptr
  lda #>(start-1)
  sta charptr+1
  jsr set_inverse_cursor
; setup values for different charsets
  lda $D018
  and #$F0
  sta vicpage
  ora #4
  sta choose_charset_rom
  
  ; everytime option to load config
  jsr check_load_config ; do before switching to RAM set
  jsr choose_rom_ram_sets
  jsr init_irq_scanline

  ; check if can skip one-time init
  lda basicstartptr+1
  cmp #>new_start
  beq init_screen ; skip one-time init

; one-time init begins
  lda #<(new_start+1)
  ldx #>(new_start+1)
  sta basicstartptr
  stx basicstartptr+1 ; reset basic start

; copy charrom to ram
  lda #0
  sta ptr1
  sta ptr2
  lda #>(start-1)
  sta ptr1+1
  ldx #>charrom
+ stx ptr2+1
  lda #16
  sta temp ; store count
  ldy #$00
  sei 
  jsr bank_charrom
- lda (ptr2),y
  sta (ptr1),y
  iny
  bne -
  inc ptr1+1
  inc ptr2+1
  dec temp
  bne -
  jsr bank_norm
  cli

init_screen:
  jsr set2copyfordisplay
  lda #clearchar
  jsr charout
init_screen_no_clear:
  jsr fill_color ; fill color ram so we can poke characters to video ram to be seen
  lda #homechar
  jsr charout
  bit hide_mode
  bmi ++
  lda foreground
  pha
  lda title_color
  sta foreground
  lda #<title
  ldx #>title
  jsr strout
  pla
  sta foreground
  lda #<header
  ldx #>header
  jsr strout
  lda #<menus
  ldx #>menus
  sta lineptr
  stx lineptr+1
  jsr menulinesout
  lda #$30 ; zero character
  sta ptr2  ; init first digit
  lda #$08
  sta temp  ; set count
- lda #<left_margin
  ldx #>left_margin
  jsr strout
  lda ptr2  ; retrieve digit
  jsr charout
  lda #<blanks
  ldx #>blanks
  jsr strout
  lda #spacechar
  jsr charout
  jsr menulinesout
  inc ptr2  ; ++digit
  dec temp  ; --count
  bne -
  jsr draw_header
  jsr menulinesout
++jsr all_chars

  lda #0
  sta pixelx
  lda #0
  sta pixely
  lda #(columns+16)
  ldx #>video
  sta pixelptr
  stx pixelptr+1
  ldx #>(color_ram)
  sta pixelcolorptr
  stx pixelcolorptr+1

main:
  clc
  lda jiffyclock
  adc #>video
  sta jiffyblink
  jsr dispchar
main_save:
  ldy #0
  lda (pixelptr),y
  sta save_cursor
- lda $D018
  and #ptr2+1
  cmp #$10
  bne +
  lda #$12
  sta $D018
+ jsr chkblink
  jsr getkey
  beq - ; no key pressed
  pha
  jsr blinkoff
  pla

  cmp #$4e ; 'N' key
  bne ++
next_char:
  jsr reset_undo
  lda charptr
  adc #$07
  sta charptr
  bcc main
  inc charptr+1
  lda charptr+1
  cmp #(>start)+8
  bcc main
  lda #>start
  sta charptr+1
  bne main

++cmp #$2b ; '+' key
  bne ++
pgup:
  jsr reset_undo
  lda charptr
  adc #$7f
  sta charptr
  bcc main
  inc charptr+1
  lda charptr+1
  cmp #(>start)+8
  bcc main
  lda #>start
  sta charptr+1
  bne main

++cmp #$42 ; 'B' key
  bne ++
back_char:
  jsr reset_undo
  lda charptr
  sbc #$08
  sta charptr
  bcs main
  dec charptr+1
  lda charptr+1
  cmp #>start
  bcs main
  lda #(>start)+7
  sta charptr+1
  jmp main

++cmp #$2D ; '-' key
  bne ++
pgdn:
  jsr reset_undo
  lda charptr
  sbc #$80
  sta charptr
  bcs +
  dec charptr+1
  lda charptr+1
  cmp #>start
  bcs +
  lda #(>start)+7
  sta charptr+1
+ jmp main

++cmp #$11 ; cursor down key
  bne ++
down:
  lda pixelptr
  adc #(columns-1)
  sta pixelptr
  sta pixelcolorptr
  bcc +
  inc pixelptr+1
  inc pixelcolorptr+1
  clc
+ lda pixely
  adc #1
  and #7
  sta pixely
  bne +
  sec
  lda pixelptr
  sbc #<(columns*8)
  sta pixelptr
  sta pixelcolorptr
  lda pixelptr+1
  sbc #>(columns*8)
  sta pixelptr+1
  lda pixelcolorptr+1
  sbc #>(columns*8)
  sta pixelcolorptr+1
+ jmp main_save

++cmp #$91 ; cursor up key
  bne ++
up:
  lda pixelptr
  sbc #columns
  sta pixelptr
  sta pixelcolorptr
  bcs +
  dec pixelptr+1
  dec pixelcolorptr+1
  sec
+ lda pixely
  sbc #1
  and #7
  sta pixely
  cmp #7
  bne +
  clc
  lda pixelptr
  adc #<(columns*8)
  sta pixelptr
  sta pixelcolorptr
  lda pixelptr+1
  adc #>(columns*8)
  sta pixelptr+1
  lda pixelcolorptr+1
  adc #>(columns*8)
  sta pixelcolorptr+1
+ jmp main_save

++cmp #$1D ; cursor right key
  bne ++
right:
  inc pixelptr
  inc pixelcolorptr
  lda pixelx
  adc #0
  sta pixelx
  and #7
  bne +
  sec
  lda pixelptr
  sbc #8
  sta pixelptr
  sta pixelcolorptr
  lda #0
  sta pixelx
+ jmp main_save

++cmp #$9D ; cursor left key
  bne ++
left:  
  dec pixelptr
  dec pixelcolorptr
  dec pixelx
  bpl +
  clc
  lda pixelptr
  adc #8
  sta pixelptr
  sta pixelcolorptr
  lda #7
  sta pixelx
+ jmp main_save

++cmp #homechar ; HOME key
  bne ++
home:  
  lda #0
  sta pixelx
  sta pixely
  lda #(columns+16)
  sta pixelptr
  sta pixelcolorptr
  lda #>video
  sta pixelptr+1
  lda #>color_ram
  sta pixelcolorptr+1
  jmp main_save

++cmp #spacechar ; space key
  bne ++
toggle_bit:
  jsr save_undo  
  ldx pixelx
  ldy pixely
  lda (charptr),y
  eor bitmask,x
  sta (charptr),y
  jmp main

++cmp #$03 ; stop key
  bne ++
bye:
  ; avoid BREAK message by waiting for stop key to be released
  lda $91 ; stop key pressed?
  cmp #$7f ; stop
  beq bye ; pause while stop pressed

  jsr choose_rom_only_sets
  jsr stop_irq_scanline

  lda choose_charset_rom
  sta $D018 ; turn off programmable characters

  jsr check_save_config

  jsr choose_rom_ram_sets ; guarantee choose_charset1 is RAM
  lda choose_charset1
  sta $D018 ; turn on programmable characters
  
  lda #<done
  ldx #>done
  jsr strout

  clc
  lsr hide_mode
  lda charset2_color
  pha ; save color because we're gonna change it temporarily
  lda background
  sta charset2_color ; make invisible
  jsr fill_color
  jsr all_chars
  pla
  sta charset2_color ; restore color

  ; adjust next token ptr to $180a if was $080a
  lda $7a
  cmp #<(start+9)
  bne +
  lda $7b
  cmp #>start
  bne +
  lda #>new_start
  sta $7b

+ rts

++cmp #$53 ; 'S' key
  bne ++
save_font:
  jsr save_scanline_choices
  ; clear screen
  lda #clearchar
  jsr charout
  ; setup and save
  lda #10
  sta $39
  lda #0
  sta $3a
  lda #$c0 ; KERNAL control and error messages
  sta $9d ; set messages to be displayed
  lda #1
  ldx #8
  ldy #15
  jsr setlfs
  lda #(filename_end - filename)
  ldx #<filename
  ldy #>filename
  jsr setnam
  lda #<(start-1)
  sta ptr1
  lda #>(start-1)
  sta ptr1+1
  lda #ptr1
  ldx #<(new_start)
  ldy #>(new_start)
  jsr fsave
  ; prompt
  lda #<press_key
  ldx #>press_key
  jsr strout
--jsr getkey
  beq --
  jsr restore_scanline_choices
  jmp init_screen

++cmp #clearchar ; CLR key
  bne ++
clear:  
  jsr save_undo  
  lda #0
  ldy #7
--sta (charptr),y
  dey
  bpl --
  jmp main

++cmp #$12 ; RVS key
  bne ++
rvs:  
  jsr save_undo  
  ldy #7
--lda (charptr),y
  eor #$FF
  sta (charptr),y
  dey
  bpl --
  jmp main

++cmp #$3C ; '<' key
  bne ++
shiftleft:  
  jsr save_undo  
  ldy #7
--lda (charptr),y
  asl
  sta (charptr),y
  dey
  bpl --
  jmp main

++cmp #$3E ; '>' key
  bne ++
shiftright:  
  jsr save_undo  
  ldy #7
--lda (charptr),y
  lsr
  sta (charptr),y
  dey
  bpl --
  jmp main

++cmp #$D6 ; capital 'V' key
  bne ++
shiftdown:  
  jsr save_undo  
  ldy #7
--dey
  lda (charptr),y
  iny
  sta (charptr),y
  dey
  bpl --
  iny
  lda #0
  sta (charptr),y
  jmp main

++cmp #$5E ; '^' key
  bne ++
shiftup:  
  jsr save_undo  
  ldx #7
  ldy #0
--iny
  lda (charptr),y
  dey
  sta (charptr),y
  iny
  dex
  bne --
  lda #0
  sta (charptr),y
  jmp main

++cmp #$46 ; 'F' key
  bne ++
flip:  
  jsr save_undo  
  ldy #3
  sty temp
  iny
  sty ptr2+1
--ldy temp
  lda (charptr),y
  pha
  ldy ptr2+1
  lda (charptr),y
  tax
  pla
  sta (charptr),y
  ldy temp
  txa
  sta (charptr),y
  inc ptr2+1
  dec temp
  bpl --
  jmp main

++cmp #$52 ; 'R' key
  bne ++
rotate:  
  jsr save_undo  
  ldy #0
---ldx #0
--lda (charptr),y
  asl
  sta (charptr),y
  ror tempbuff,x
  inx
  cpx #8
  bne --
  iny
  cpy #8
  bne ---
  ldy #7
--lda tempbuff,y
  sta (charptr),y
  dey
  bpl --
  jmp main

++cmp #$4d ; 'M' key
  bne ++
mirror:  
  jsr save_undo  
  ldy #7
---ldx #7
--lda (charptr),y
  lsr
  sta (charptr),y
  lda tempbuff,y
  rol
  sta tempbuff,y
  dex
  bpl --
  dey
  bpl ---
  ldy #7
--lda tempbuff,y
  sta (charptr),y
  dey
  bpl --
  jmp main

++cmp #$40 ; '@' key
  bne ++
toggle_chars:
  lda choose_charset1
  cmp choose_charset_rom
  beq +
  jsr choose_rom_only_sets
  jmp -
+ jsr choose_rom_ram_sets
  jmp -

++cmp #starchar ; '*' key
  bne ++
toggle_pixel_char:
  lda pixel_char
  ldx pixel_char_alternate
  ldy pixel_char_alternate2
  stx pixel_char
  sty pixel_char_alternate
  sta pixel_char_alternate2
  lda pixel_space
  ldx pixel_space_alternate
  ldy pixel_space_alternate2
  stx pixel_space
  sty pixel_space_alternate
  sta pixel_space_alternate2
  jsr set_inverse_cursor
  jsr redraw_footer
  jmp main

++cmp #$5A ; 'Z' key
  bne ++
restore_undo:
  ldx undo_count
  beq +
  lda redo_count
  bne +++
  jsr save_undo
  dec undo_count
  ldx undo_count
+++inc redo_count
  dex
  stx undo_count
redo_undo:  
  txa
  jsr set_undo_ptr
  ldy #7
--lda (ptr1),y
  sta (charptr),y
  dey
  bpl --
+ jmp main

++cmp #$43 ; 'C' key
  bne ++
copy:
  ldy #7
--lda (charptr),y
  sta clipboard,y
  dey
  bpl --
  sty clipboard_present
  jmp -

++cmp #$56; 'V' key
  bne ++
paste:
  bit clipboard_present
  bpl +
  jsr save_undo
  ldy #7
--lda clipboard,y
  sta (charptr),y
  dey
  bpl --
+ jmp main

++cmp #$58; 'X' key
  bne ++
cut:
  jsr save_undo
  ldy #7
--lda (charptr),y
  sta clipboard,y
  lda #0
  sta (charptr),y
  dey
  bpl --
  sty clipboard_present
  jmp main

++cmp #$59 ; 'Y' key
  bne ++
redo:
  lda redo_count
  beq ++
  dec redo_count
  inc undo_count
  ldx undo_count
  jmp redo_undo

++cmp #$2F ; '/' key
  bne ++
toggle_case:
  jsr reset_undo
  lda #<(start-1)
  ldx #>(start-1)
  sta ptr1
  stx ptr1+1
  ldx #(>(start-1))+8
  sta ptr2
  stx ptr2+1
  ldx #8
  stx temp
  ldy #0
--lda (ptr1),y
  tax
  lda (ptr2),y
  sta (ptr1),y
  txa
  sta (ptr2),y
  iny
  bne --
  inc ptr1+1
  inc ptr2+1
  dec temp
  bne --
  jsr set2copyfordisplay
  jmp main

++cmp #$85 ; F1 key
  bne ++
inc_foreground:  
  inc foreground
  lda foreground
  eor background
  and #15
  beq inc_foreground
  jsr fill_color
  jmp -

++cmp #$89 ; F2 key
  bne ++
inc_cursor:
  clc
  lda pixel_cursor_color
  adc #1
  and #15
  sta pixel_cursor_color
  lda background
  eor pixel_cursor_color
  and #15
  beq inc_cursor
  jsr dispchar
  jmp -

++cmp #$86 ; F3 key
  bne ++
inc_background:
  inc background
  lda background
  eor foreground
  and #15
  beq inc_background
  jmp -

++cmp #$8a ; F4 key
  bne ++
inc_charset1_color
  clc
  lda charset1_color
  adc #1
  and #15
  sta charset1_color
  eor background
  and #15
  beq inc_charset1_color
  jsr fill_color
  jmp -

++cmp #$87 ; F5 key
  bne ++
inc_border:  
  inc border
  jmp -

++cmp #$8b ; F6 key
  bne ++
inc_charset2_color
  clc
  lda charset2_color
  adc #1
  and #15
  sta charset2_color
  eor background
  and #15
  beq inc_charset2_color
  jsr fill_color
  jmp -

++cmp #$88 ; F7 key
  bne ++
inc_pixel:
  clc
  lda pixel_char_color
  adc #1
  and #15
  sta pixel_char_color
  lda background
  eor pixel_char_color
  and #15
  beq inc_pixel
  jsr dispchar
  jmp -

++cmp #$8c ; F8 key
  bne ++
inc_space:
  clc
  lda pixel_space_color
  adc #1
  and #15
  sta pixel_space_color
  jsr dispchar
  jmp -

++cmp #$2C ; "," key
  bne ++
inc_title_color:
  clc
  lda title_color
  adc #1
  and #15
  sta title_color
  jsr fill_color
  jmp -

++cmp #$2E ; "." key
  bne ++
inc_menu_color:
  clc
  lda menu_color
  adc #1
  and #15
  sta menu_color
  jsr fill_color
  jmp -

++cmp #$48 ; "H" key
  bne ++
hide:
  lda hide_mode
  eor #$80
  sta hide_mode
  jmp init_screen

++cmp #$30 ; "0" key
  bcc ++
  cmp #$3A ; greater than "9" key
  bcs ++
theme_number:
  and #$0f
  jsr set_theme
  jmp init_screen_no_clear

++jmp -

strout:
  sta ptr1
  stx ptr1+1
  ldy #$00
- lda (ptr1),y
  beq +
  jsr charout
  iny
  bne - ; assume <= 256 length
+ rts

; output multiple buffers in a row in subsequent calls, kept track of by b4/b5
menulinesout:
  lda #<lines_margin
  ldx #>lines_margin
  jsr strout
  lda foreground
  pha
  lda menu_color
  sta foreground
  lda lineptr
  ldx lineptr+1
  jsr strout
  pla
  sta foreground
  iny
  tya
  clc
  adc lineptr
  sta lineptr
  bcc +
  inc lineptr+1
+ rts

dispchar:
  lda #(columns+16)
  ldx #>video
  sta dispptr
  stx dispptr+1
  ldx #>color_ram
  sta colorptr
  stx colorptr+1
  lda #$08
  sta temp
  ldy #$00
--ldx #$08
  lda (charptr),y
  sta temp2
- lda pixel_space_color
  asl temp2
  bcc +
  lda pixel_char_color
+ sta (colorptr),y
  lda pixel_space
  bcc +
  lda pixel_char
+ sta (dispptr),y
  inc dispptr
  inc colorptr
  bne +
  inc dispptr+1
  inc colorptr+1
+ dex
  bne -
  clc
  lda dispptr
  adc #(columns-9)
  sta dispptr
  sta colorptr
  bcc +
  inc dispptr+1
  inc colorptr+1
+ iny
  dec temp
  bne --
  bit hide_mode
  bpl +
  jmp all_chars
+ jsr charptr_to_offset
  ldx #(15+10)
  stx dispptr
  stx colorptr
  ldx #>video
  stx dispptr+1
  ldx #>color_ram
  stx colorptr+1
  sec
  ror temp ; set inverse flag for disp_hex
  ldy #$00
  jsr disp_hex
  inc dispptr
  inc colorptr
  bne +
  inc dispptr+1
  inc colorptr+1
+ clc
  ror temp ; clear inverse flag for disp_hex
  ldx #$08
- clc
  lda dispptr
  adc #(columns-3)
  sta dispptr
  sta colorptr
  bcc +
  inc dispptr+1
  inc colorptr+1
+ lda border_char
  bit inverse_cursor
  bmi +
  lda #229 ; inverse leftmost vertical bar
+ sta (dispptr),y
  inc dispptr
  bne +
  inc dispptr+1
+ lda (charptr),y
  jsr disp_hex
  iny
  dex
  bne -
  rts

disp_hex:
  pha
  lsr
  lsr
  lsr
  lsr
  jsr disp_nybble
  inc dispptr
  inc colorptr
  bne +
  inc dispptr+1
  inc colorptr+1
+ pla
  and #$0f
  ; fall through
disp_nybble:
  ora #$30 ; '0' screen code
  cmp #$3a
  bcc +    ; branch if less
  sbc #$39 ; subtract to get to 'A' to 'F' screen codes
+ bit temp
  bpl +
  ora #$80 ; reverse text
+ sta (dispptr),y
  rts

chkblink:
  sec
  lda jiffyblink
  cmp jiffyclock
  bne ++
  lda jiffyclock
  adc #$1d
  sta jiffyblink
  ldy #0
  lda pixel_char_color
  bit inverse_cursor
  bpl +
  lda (pixelptr),y
  eor #$80
  sta (pixelptr),y
--lda pixel_cursor_color
- sta (pixelcolorptr),y
  rts
+ lda (pixelcolorptr),y
  and #15
  cmp pixel_cursor_color
  bne --
  jsr restore_cursor_color
++rts

blinkoff:
  ldy #0
  lda save_cursor
  sta (pixelptr),y
  jsr restore_cursor_color
  clc
  lda jiffyclock
  adc #2
  sta jiffyblink
  rts

fill_color:
  ; top line visible grid border and character index
  ; and bottom grid border
  ldx #12
  lda foreground
- sta color_ram+14,x
  sta color_ram+14+(9*40),x ; 9 lines down
  dex
  bne -
  ; titles, copyright, menus, and grid side borders
  ldx #16
  ldy #0
- lda title_color
  cpy #15
  bcc +
  lda foreground
+ sta color_ram+1*40,y
  sta color_ram+2*40,y
  sta color_ram+3*40,y
  sta color_ram+4*40,y
  sta color_ram+5*40,y
  sta color_ram+6*40,y
  sta color_ram+7*40,y
  sta color_ram+8*40,y
  sta color_ram+9*40,y
  lda foreground
  cpy #3
  bcc +
  lda menu_color
+ sta color_ram+24+(1*40),y
  sta color_ram+24+(2*40),y
  sta color_ram+24+(3*40),y
  sta color_ram+24+(4*40),y
  sta color_ram+24+(5*40),y
  sta color_ram+24+(6*40),y
  sta color_ram+24+(7*40),y
  sta color_ram+24+(8*40),y
  sta color_ram+24+(9*40),y
  iny
  dex
  bne -
  ; charset 1
  ldy #0
  lda charset1_color
- sta color_ram+(11*40),y
  iny
  bne -
  ; charset 2
  lda charset2_color
- sta color_ram+(18*40),y
  iny
  bne -
  rts

all_chars:
  lda #<(video+(11*columns))
  ldx #>(video+(11*columns))
  sta ptr1
  stx ptr1+1
  bit hide_mode
  bpl +
  ldy #0
  lda #spacechar
- sta (ptr1),y
  iny
  bne -
  jsr charptr_to_offset
  tay
  sta (ptr1),y
  rts
+ jsr disp_char_set
  bit hide_mode
  bmi +
  lda #<(video+(18*columns))
  ldx #>(video+(18*columns))
  sta ptr1
  stx ptr1+1
; continues
disp_char_set:
  ldy #0
- tya
  sta (ptr1),y
  iny
  bne -
+ rts

reset_undo:
  lda #0
  sta undo_count
  sta redo_count
  rts

save_undo:
  lda undo_count
  cmp #undo_limit
  bcc +
  ; full, so throw away oldest
  ldx #0
  ldy #8
--lda undo_buffer,y
  sta undo_buffer,x
  inx
  iny
  cpy #$c4
  bne --
  ldx #(undo_limit-1)
  stx undo_count
  txa
+ jsr set_undo_ptr
  ldy #7
- lda (charptr),y
  sta (ptr1),y
  dey
  bpl -
  inc undo_count
  iny
  sty redo_count
  clc
  rts

set_undo_ptr:
  asl
  asl
  asl
  clc
  adc #<undo_buffer
  sta ptr1
  ldx #>undo_buffer
  bcc +
  inx
+ stx ptr1+1
  rts

bank_norm
  lda $01
  ora #$07
  sta $01
  rts

bank_charrom ; note caller responsible for disabling/enabling interrupts or equivalent
  lda $01
  and #$F8
  ora #$03
  sta $01
  rts

charptr_to_offset:
  lda charptr+1
  sta temp
  lda charptr
  lsr temp
  ror
  lsr temp
  ror
  lsr temp
  ror
  rts

set2copyfordisplay:
  ; also copy second set to $3800 for VIC-II raster interrupt display
  ; (because $1000 RAM can't be displayed by VIC-II, shows ROM instead)
  lda #<(start-1+2048)
  ldx #>(start-1+2048)
  sta ptr1
  stx ptr1+1
  ldx #$38
  sta ptr2
  stx ptr2+1
  ldx #8
  stx temp
  ldy #0
--lda (ptr1),y
  sta (ptr2),y
  iny
  bne --
  inc ptr1+1
  inc ptr2+1
  dec temp
  bne --
  rts

irq_scanline:
  bit $d019 ; vic-ii irq status
  bmi + ; branch if not a vic-ii irq
jmp_orig_irq:
  jmp $ea31 ; resume IRQ (note: self modifying code, see init_irq_scanline)
+ lda $d019
  and #$01
  beq jmp_orig_irq ; branch if not a scanline irq

  lda scanline_set
  bpl +

- lda $d012 ; vic-ii scanline
  cmp #$c2
  bcc -
  ldx #$0a
- dex
  bne -
  lda choose_charset2 ; show second RAM charset
  sta $d018
  lda #$00
  sta $d012
  sta scanline_set

  ; vic-ii scanline 8th bit cleared
  lda $d011
  and #$7f
  sta $d011

  lda #$01
  sta $d019
  jmp ++

+ beq +

; approaching 8A scanline
- lda $d012 ; vic-ii scanline
  cmp #$8a
  bcc -
  ldx #$0a
- dex
  bne -
  lda choose_charset1 ; show first RAM charset
  sta $d018
  lda #$a4
  sta $d012
  sta scanline_set

  ; vic-ii scanline 8th bit cleared
  lda $d011
  and #$7f
  sta $d011

  lda #$01
  sta $d019
  jmp ++

  ; zero scanline
+ lda choose_charset_rom ; show ROM charset
  sta $d018
  lda #$68
  sta $d012
  sta scanline_set

  ; vic-ii scanline 8th bit cleared
  lda $d011
  and #$7f
  sta $d011

  lda #$01
  sta $d019

; return from ROM IRQ handler
++pla
  tay
  pla
  tax
  pla
  rti

init_irq_scanline:  
  sei ; disallow IRQ
  lda #$00 ; rotatable high bit in enabled state
  sta scanline_set
  lda #$00
  sta $d012
  lda $d011
  and #$7f
  sta $d011
  lda $0314
  ldx $0315
  cpx #>irq_scanline
  beq + ; branch if already set
  sta jmp_orig_irq+1
  stx jmp_orig_irq+2
  lda #<irq_scanline
  ldx #>irq_scanline
  sta $0314
  stx $0315
+ lda $d01a
  ora #$01
  sta $d01a
  cli ; re-enable IRQ
  rts

stop_irq_scanline:
  sei
  lda jmp_orig_irq+1
  ldx jmp_orig_irq+2
  sta $0314
  stx $0315
  lda $d01a
  and #$fe
  sta $d01a
  lda #1
  sta $d019
  cli
  rts

choose_rom_ram_sets:
  lda choose_charset_rom
  and #$F0
  ora #$02
  sta choose_charset1
  and #$F0
  ora #14
  sta choose_charset2
  rts

choose_rom_only_sets:
  lda choose_charset_rom
  sta choose_charset1
  ora #2
  sta choose_charset2
  rts

save_scanline_choices:
  ; remember scanline interrupt fonts, switch to one ROM set only during save
  lda choose_charset1
  sta save_choose_charset1
  lda choose_charset2
  sta save_choose_charset2
  lda choose_charset_rom
  sta choose_charset1
  sta choose_charset2
  rts

restore_scanline_choices:
  lda save_choose_charset1
  sta choose_charset1
  lda save_choose_charset2
  sta choose_charset2
  rts 

set_inverse_cursor:
  lda #$80
  sta inverse_cursor
  lda pixel_char
  cmp pixel_space
  bne +
  lsr inverse_cursor
+ rts

restore_cursor_color:
  ldy pixely
  lda (charptr),y
  ldx pixelx
  and bitmask, x
  cmp #1 ; set C if pixel is on
  lda pixel_space_color
  bcc +
  lda pixel_char_color
+ ldy #0
  sta (pixelcolorptr),y
  rts

redraw_footer:
  lda #<pre_repeat_footer
  ldx #>pre_repeat_footer
  jsr strout
  jsr draw_header
  lda #$92
  jmp charout

draw_header:
  lda #<header
  ldx #>header
  bit inverse_cursor
  bmi +
  lda #<grid_footer
  ldx #>grid_footer
+ jmp strout

set_theme:
  cmp #0
  bne +
  lda #10
+ cmp #11
  bcc +
  rts
+ tay
  lda #<themes
  ldx #>themes
  sta ptr1
  stx ptr1+1
- dey
  beq +
  clc
  lda ptr1
  adc #(active_config_end - active_config)
  sta ptr1
  lda ptr1+1
  adc #0
  sta ptr1+1
  bne -
+ ldy #0
  lda (ptr1),y
  sta foreground
  iny
  lda (ptr1),y
  sta background
  iny
  lda (ptr1),y
  sta border
  iny
  lda (ptr1),y
  sta pixel_space_color
  iny
  lda (ptr1),y
  sta pixel_char_color
  iny
  lda (ptr1),y
  sta pixel_cursor_color
  iny
  lda (ptr1),y
  sta pixel_space
  iny
  lda (ptr1),y
  sta pixel_char
  iny
  lda (ptr1),y
  sta border_char
  iny
  lda (ptr1),y
  sta charset1_color
  iny
  lda (ptr1),y
  sta charset2_color
  iny
  lda (ptr1),y
  sta title_color
  iny
  lda (ptr1),y
  sta menu_color
  jsr set_inverse_cursor
  jsr fill_color
  jmp fixup_alternates

fixup_alternates:
  lda pixel_char
  cmp #160
  bne +
  lda #spacechar
  sta pixel_space_alternate
  lda #starchar
  sta pixel_char_alternate
  lda #207
  sta pixel_space_alternate2
  sta pixel_char_alternate2
  rts
+ cmp #starchar
  bne +
  lda #207
  sta pixel_space_alternate
  sta pixel_char_alternate
  lda #spacechar
  sta pixel_space_alternate2
  lda #160
  sta pixel_char_alternate2
  rts
+ lda #spacechar
  sta pixel_space_alternate
  lda #160
  sta pixel_char_alternate
  lda #spacechar
  sta pixel_space_alternate2
  lda #starchar
  sta pixel_char_alternate2
  rts

check_load_config:
  lda #<ask_load_config
  ldx #>ask_load_config
  jsr strout
  jsr getyesno
  bne ++
  ; setup and save
  lda #$ff
  sta file_config+9 ; to help detect version <2 configuration (no charset colors)
  sta file_config+11 ; to help detect version <3 configuration (no title/menu colors)
  lda #10
  sta $39
  lda #0
  sta $3a
  lda #$c0 ; KERNAL control and error messages
  sta $9d ; set messages to be displayed
  lda #1
  ldx #8
  ldy #0
  jsr setlfs
  lda #(config_filename_end - load_config_filename)
  ldx #<load_config_filename
  ldy #>load_config_filename
  jsr setnam
  lda #0
  ldx #<file_config
  ldy #>file_config
  jsr fload
  ; check version 1 configuration (no colors for charset1/charset2)
  lda file_config+9
  cmp #$ff
  bne +
  lda file_config ; foreground color
  sta file_config+9 ; charset1 color
  sta file_config+10 ; charset2 color
+ lda file_config+11
  cmp #$ff
  bne +
  lda file_config ; foreground color
  sta file_config+11 ; titles color
  sta file_config+12 ; menus color
  ; install configuration options
+ ldx #(active_config_end - active_config)
  ldy #0
- lda file_config, y
  sta active_config, y
  iny
  dex
  bne -
  lda save_foreground
  ldx save_background
  ldy save_border
  sta foreground
  stx background
  sty border
  jsr set_inverse_cursor
  jsr fixup_alternates
++rts

check_save_config:
  lda foreground
  and #15
  sta save_foreground
  lda background
  and #15
  sta save_background
  lda border
  and #15
  sta save_border
  jsr compare_config
  beq +
  jsr save_scanline_choices
  lda #<config_changed
  ldx #>config_changed
  jsr strout
  jsr getyesno
  bne +
  ; setup and save
  lda #10
  sta $39
  lda #0
  sta $3a
  lda #$c0 ; KERNAL control and error messages
  sta $9d ; set messages to be displayed
  lda #1
  ldx #8
  ldy #15
  jsr setlfs
  lda #(config_filename_end - save_config_filename)
  ldx #<save_config_filename
  ldy #>save_config_filename
  jsr setnam
  lda #<active_config
  sta ptr1
  lda #>active_config
  sta ptr1+1
  lda #ptr1
  ldx #<active_config_end
  ldy #>active_config_end
  jsr fsave
  ; prompt
  lda #<press_key
  ldx #>press_key
  jsr strout
--jsr getkey
  beq --
  jsr restore_scanline_choices
+ rts

compare_config:
  ldx #(active_config_end - active_config)
  ldy #0
- lda file_config, y
  cmp active_config, y
  bne +
  iny
  dex
  bne -
+ rts

getyesno:
- jsr getkey
  beq -
+ cmp #78 ; key "N"
  bne +
  lda #<no
  ldx #>no
  jsr strout
  lda #1
  bne ++
+ cmp #89 ; key "Y"
  beq +++
  cmp #13
  bne -
+++lda #<yes
  ldx #>yes
  jsr strout
++rts

bitmask:
  !byte $80,$40,$20,$10,$08,$04,$02,$01

invmask:
  !byte $7f,$cf,$df,$ef,$f7,$fc,$fd,$fe

title:
  !text 13
  !text " ",18,"  CH64EDIT  ",13
  !text " ",18,"  (C) 2024  ",13
  !text " ",18,"  DAVID R.  ",13
  !text " ",18," VAN WAGNER ",13
  !text " ",18," DAVEVW.COM ",13
  !text $13
  !byte 0

header:  
  !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
  !byte $12,$20,$37,$36,$35,$34,$33,$32,$31,$30,$20
  !byte 0

grid_footer:
  !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
  !byte $12,$20,$A3,$A3,$A3,$A3,$A3,$A3,$A3,$A3,$20
  !byte 0

pre_repeat_footer:
  !byte $13,$92,$11,$11,$11,$11,$11,$11,$11,$11,$11,0

menus:
  !text 13,0
  !text 18,"@-+*/YZXCV",13,0
  !text 18,"B",146,"ACK ",18,"R",146,"OTATE",13,0
  !text 18,"N",146,"EXT ",18,"M",146,"IRROR",13,0
  !text 18,"<>^V",146," ",18,"F",146,"LIP",13,0
  !text 18,"F1",146,"-",18,"F8",146," ",18,",.",146," ",18,"0-9",146,0
  !text 18,"HOME",146," ",18,"CLR",13,0
  !text 18,"RVS",146,"  ",18,"SPACE",13,0
  !text 18,"STOP",146," ",18,"S",146,"AVE",13,0
  !text 18,"H",146,"IDE",13,0
  
blanks:
  !byte $92,$20,$20,$20,$20,$20,$20,$20,$20,$12,$00

left_margin:
  !byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d,$12,$00

lines_margin:
  !byte $92,$20,$20,$20,$00

done:
  !text 147,"BYE!",13,0

filename:
  !text "@0:FONT.BIN"
filename_end:

save_config_filename:
  !text "@0:"
load_config_filename
  !text "FONT.CFG"
config_filename_end:

press_key: !text 13, 13, 18, "PRESS ANY KEY", 13, 0

ask_load_config: !text 147, 13, "LOAD CONFIGURATION (Y/N)? ", 18, "Y", 146, 157, 0 
config_changed: !text 147, 13, "SAVE CONFIGURATION (Y/N)? ", 18, "Y", 146, 157, 0
yes: !text "YES", 13, 0
no: !text "NO", 13, 0

themes:
  !byte 14, 6, 14, 14, 0, 1, 32, 160, 160, 14, 14, 14, 14 ; standard colors, black pixels in editor, white pixel cursor, solid pixels
  !byte 1, 0, 15, 0, 1, 11, 207, 207, 160, 1, 1, 1, 1 ; high contrast black on white, some gray, grid pixels
  !byte 5, 0, 0, 0, 5, 5, 32, 42, 160, 5, 5, 5, 5 ; high contrast simple green on black, asterisks
  !byte 6, 1, 3, 15, 0, 3, 207, 207, 160, 6, 6, 6, 6 ; Vic-20 inspired, grid
  !byte 0, 11, 12, 15, 0, 14, 207, 207, 160, 0, 0, 0, 0 ; darker, lower contrast grays, grid
  !byte 13, 6, 7, 7, 2, 4, 207, 207, 160, 4, 13, 1, 8 ; bright primary colors, grid
  !byte 11, 0, 8, 15, 8, 9, 32, 160, 160, 11, 11, 11, 11 ; dark pumpkin solid
  !byte 13, 11, 13, 12, 0, 4, 32, 160, 160, 13, 13, 13, 13 ; C128 inspired, solid
  !byte 0, 1, 14, 15, 14, 5, 207, 207, 160, 0, 0, 0, 0 ; Plus/4 inspired, grid
  !byte 14, 0, 0, 0, 11, 6, 32, 160, 160, 14, 14, 14, 14 ; dark mode, solid

;******************************
active_config:
save_foreground !byte 0
save_background !byte 0
save_border !byte 0

pixel_space_color !byte 14
pixel_char_color !byte 0
pixel_cursor_color !byte 1

; screen code to display large pixel
pixel_space: !byte 32
pixel_char: !byte 160 ; reverse space screen code
border_char !byte 160

charset1_color !byte 14
charset2_color !byte 14

title_color !byte 14
menu_color !byte 14

active_config_end: !byte 0 ; unused byte
;***************

pixel_space_alternate !byte 32
pixel_char_alternate !byte starchar

pixel_space_alternate2 !byte 207
pixel_char_alternate2 !byte 207

inverse_cursor !byte 0x80
hide_mode: !byte 0

scanline_set: !byte 0

; values stored at $D018 based on scanline
vicpage: !byte 16 ; upper 4 bits
choose_charset_rom: !byte 16+4
choose_charset1: !byte 16+2
choose_charset2: !byte 16+14

; safe storage while saving to counter visual issues with interrupts being disabled during saves
save_choose_charset1: !byte 0
save_choose_charset2: !byte 0

file_config: ; must be at end of program, available space