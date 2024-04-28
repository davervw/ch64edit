; ch64edit.asm

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

undo_buffer = $33c
undo_limit = 24 ; must save extra one space for redo (uses 25)
jiffyclock = $a2 ; increased by one every 1/60 of a second
jiffyblink = $a3
undo_count = $a4
redo_count = $a5
clipboard = $251
clipboard_present = $a7
save_cursor = $a8
tempbuff = $a9 ; 8 bytes free to use temporarily a9-b0
lineptr = $b4
border = 53280
background = 53281
foreground = 646
charptr = $22
cursorptr = $24
temp2 = $26
pixelx = $27
pixely = $28
pixelptr = $29
basicstartptr = $2b ; 43/44
ptr1 = $fb
ptr2 = $fd
temp = $ff

clearchar = $93
spacechar = $20
starchar = $2a ; asterisk

*=$0801 ; C64 start
start:
!byte $0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 ; 10 SYS6157 (without leading zero)

; 0800-17ff is reserved for editable character images, will be initialized from charrom $D000 for one-time initialization

*=$1800
new_start:
!byte $00,$0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 ; 10 SYS6157 (with leading zero)
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

; setup values for different charsets
  lda $D018
  and #$F0
  sta vicpage
  ora #4
  sta choose_charset_rom
  jsr choose_rom_ram_sets

  jsr init_irq_scanline

  lda basicstartptr+1
  cmp #>new_start
  beq init_screen ; skip one-time init
  lda #>new_start
  sta basicstartptr+1 ; reset basic start
  ; TODO: make sure basicstartptr set to 1

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
  jsr set2copyfordisplay

init_screen:
  lda #clearchar
  jsr charout

  bit hide_mode
  bmi ++
  lda #<title_header
  ldx #>title_header
  jsr strout
  lda #<lines
  ldx #>lines
  sta lineptr
  stx lineptr+1
  jsr linesout

  ; fill color ram so we can poke characters to video ram to be seen
  jsr fill_color

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
  jsr linesout
  inc ptr2  ; ++digit
  dec temp  ; --count
  bne -
  lda #<header
  ldx #>header
  jsr strout
  jsr linesout
++jsr all_chars

  lda #0
  sta pixelx
  lda #0
  sta pixely
  lda #(columns+16)
  sta pixelptr
  lda #>video
  sta pixelptr+1

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
  bcc +
  inc pixelptr+1
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
  lda pixelptr+1
  sbc #>(columns*8)
  sta pixelptr+1
+ jmp main_save

++cmp #$91 ; cursor up key
  bne ++
up:
  lda pixelptr
  sbc #columns
  sta pixelptr
  bcs +
  dec pixelptr+1
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
  lda pixelptr+1
  adc #>(columns*8)
  sta pixelptr+1
+ jmp main_save

++cmp #$1D ; cursor right key
  bne ++
right:
  inc pixelptr
  lda pixelx
  adc #0
  sta pixelx
  and #7
  bne +
  sec
  lda pixelptr
  sbc #8
  sta pixelptr
  lda #0
  sta pixelx
+ jmp main_save

++cmp #$9D ; cursor left key
  bne ++
left:  
  dec pixelptr
  dec pixelx
  bpl +
  clc
  lda pixelptr
  adc #8
  sta pixelptr
  lda #7
  sta pixelx
+ jmp main_save

++cmp #$13 ; HOME key
  bne ++
home:  
  lda #0
  sta pixelx
  sta pixely
  lda #(columns+16)
  sta pixelptr
  lda #>video
  sta pixelptr+1
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
  lda choose_charset1
  sta $D018 ; turn on programmable characters
  
  clc
  lsr hide_mode

  lda #<done
  ldx #>done
  jsr strout

  jsr fill_color
  jsr all_chars

  rts

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
  stx pixel_char
  sta pixel_char_alternate
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
dec_foreground:
  dec foreground
  lda foreground
  eor background
  and #15
  beq dec_foreground
  jsr fill_color
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
dec_background:
  dec background
  lda background
  eor foreground
  and #15
  beq dec_background
  jmp -

++cmp #$87 ; F5 key
  bne ++
inc_border:  
  inc border
  jmp -

++cmp #$8b ; F6 key
  bne ++
dec_border:  
  dec border
  jmp ++

++cmp #$48 ; "H" key
  bne ++
hide:
  lda hide_mode
  eor #$80
  sta hide_mode
  jmp init_screen

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
linesout:
  lda #<lines_margin
  ldx #>lines_margin
  jsr strout
  lda lineptr
  ldx lineptr+1
  jsr strout
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
  sta cursorptr
  lda #>video
  sta cursorptr+1
  lda #$08
  sta temp
  ldy #$00
--ldx #$08
  lda (charptr),y
  sta temp2
- lda #spacechar
  asl temp2
  bcc +
  lda pixel_char
+ sta (cursorptr),y
  inc cursorptr
  bne +
  inc cursorptr+1
+ dex
  bne -
  clc
  lda cursorptr
  adc #(columns-9)
  sta cursorptr
  bcc +
  inc cursorptr+1
+ iny
  dec temp
  bne --
  bit hide_mode
  bpl +
  jmp all_chars
+ jsr charptr_to_offset
  ldx #(15+10)
  stx cursorptr
  ldx #>video
  stx cursorptr+1
  sec
  ror temp
  ldy #$00
  jsr disphex
  inc cursorptr
  bne +
  inc cursorptr+1
+ clc
  ror temp
  ldx #$08
- clc
  lda cursorptr
  adc #(columns-2)
  sta cursorptr
  bcc +
  inc cursorptr+1
+ lda (charptr),y
  jsr disphex
  iny
  dex
  bne -
  rts

disphex:
  pha
  lsr
  lsr
  lsr
  lsr
  jsr dispnybl
  inc cursorptr
  bne +
  inc cursorptr+1
+ pla
  and #$0f
  ; fall through
dispnybl:
  ora #$30 ; '0' screen code
  cmp #$3a
  bcc +    ; branch if less
  sbc #$39 ; subtract to get to 'A' to 'F' screen codes
+ bit temp
  bpl +
  ora #$80 ; reverse text
+ sta (cursorptr),y
  rts

chkblink:
  sec
  lda jiffyblink
  cmp jiffyclock
  bne +
  lda jiffyclock
  adc #$1d
  sta jiffyblink
  ldy #0
  lda (pixelptr),y
  eor #$80
  sta (pixelptr),y
+ rts

blinkoff:
  ldy #0
  lda save_cursor
  sta (pixelptr),y
  clc
  lda jiffyclock
  adc #2
  sta jiffyblink
  rts

fill_color:
  ldy #$00
  lda foreground
- sta color_ram,y
  sta color_ram+$100,y
  sta color_ram+$200,y
  sta color_ram+$300,y
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

bitmask:
  !byte $80,$40,$20,$10,$08,$04,$02,$01

invmask:
 !byte $7f,$cf,$df,$ef,$f7,$fc,$fd,$fe

title_header:
  !text 13
  !text " ",18,"  CH64EDIT  ",13
  !text " ",18,"  (C) 2024  ",13
  !text " ",18,"  DAVID R.  ",13
  !text " ",18," VAN WAGNER ",13
  !text " ",18," DAVEVW.COM ",13
  !text $13
header:  
  !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
  !byte $12,$20,$37,$36,$35,$34,$33,$32,$31,$30,$20,$00

lines:
  !text 13,0
  !text 18,"@-+*/YZXCV",13,0
  !text 18,"B",146,"ACK ",18,"R",146,"OTATE",13,0
  !text 18,"N",146,"EXT ",18,"M",146,"IRROR",13,0
  !text 18,"<>^V",146," ",18,"F",146,"LIP",13,0
  !text 18,"F1",146," ",18,"F3",146," ",18,"F5",146," ",13,0
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
  !byte 147,0

filename:
  !text "@0:FONT.BIN"
filename_end:

press_key: !text 13, 13, 18, "PRESS ANY KEY", 13, 0

; screen code to display large pixel
;pixel_space: !byte 32
pixel_char: !byte 160 ; reverse space screen code
pixel_char_alternate !byte starchar

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
