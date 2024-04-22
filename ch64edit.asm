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
undo_count = $a4
redo_count = $a5
clipboard = $251
clipboard_present = $a7
save_cursor = $a8
border = 53280
background = 53281
foreground = 646

*=$0801 ; C64 start
start:
!byte $0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 

*=$1800
new_start:
!byte $00,$0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00
begin:
  jsr reset_undo
  clc
  ror clipboard_present
  lda $2c
  cmp #>new_start
  beq init_screen ; skip one-time init
  lda #>new_start
  sta $2c ; reset basic start

; copy charrom to ram
  lda #0
  sta $fb
  sta $fd
  lda #>(start-1)
  sta $fc
  ldx #>charrom
+ stx $fe
  lda #16
  sta $ff ; store count
  ldy #$00
  sei 
  jsr bank_charrom
- lda ($fd),y
  sta ($fb),y
  iny
  bne -
  inc $fc
  inc $fe
  dec $ff
  bne -
  jsr bank_norm
  cli

init_screen:
  lda $D018
  and #$F0
  ora #$02
  sta $D018 ; turn on programmable characters

  lda #<clear_header
  ldx #>clear_header
  jsr strout
  lda #<lines
  ldx #>lines
  sta $b4
  stx $b5
  jsr linesout

  ; fill color ram so we can poke characters to video ram to be seen
  jsr fill_color

  lda #$30 ; zero character
  sta $fd  ; init first digit
  lda #$08
  sta $ff  ; set count
- lda #<left_margin
  ldx #>left_margin
  jsr strout
  lda $fd  ; retrieve digit
  jsr charout
  lda #<blanks
  ldx #>blanks
  jsr strout
  lda #$20 ; space
  jsr charout
  jsr linesout
  inc $fd  ; ++digit
  dec $ff  ; --count
  bne -
  lda #<header
  ldx #>header
  jsr strout
  jsr linesout
  jsr all_chars

  lda #0
  sta $27
  lda #0
  sta $28
  lda #(columns+16)
  sta $29
  lda #>video
  sta $2a
  lda #<(start-1)
  sta $22
  lda #>(start-1)
  sta $23

main:
  clc
  lda $a2
  adc #>video
  sta $a3
  jsr dispchar
main_save:
  ldy #0
  lda ($29),y
  sta save_cursor
- lda $D018
  and #$fe
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
  lda $22
  adc #$07
  sta $22
  bcc main
  inc $23
  lda $23
  cmp #(>start)+8
  bcc main
  lda #>start
  sta $23
  bne main

++cmp #$2b ; '+' key
  bne ++
pgup:
  jsr reset_undo
  lda $22
  adc #$7f
  sta $22
  bcc main
  inc $23
  lda $23
  cmp #(>start)+8
  bcc main
  lda #>start
  sta $23
  bne main

++cmp #$42 ; 'B' key
  bne ++
back_char:
  jsr reset_undo
  lda $22
  sbc #$08
  sta $22
  bcs main
  dec $23
  lda $23
  cmp #>start
  bcs main
  lda #(>start)+7
  sta $23
  jmp main

++cmp #$2D ; '-' key
  bne ++
pgdn:
  jsr reset_undo
  lda $22
  sbc #$80
  sta $22
  bcs +
  dec $23
  lda $23
  cmp #>start
  bcs +
  lda #(>start)+7
  sta $23
+ jmp main

++cmp #$11 ; cursor down key
  bne ++
down:
  lda $29
  adc #(columns-1)
  sta $29
  bcc +
  inc $2a
  clc
+ lda $28
  adc #1
  and #7
  sta $28
  bne +
  sec
  lda $29
  sbc #<(columns*8)
  sta $29
  lda $2a
  sbc #>(columns*8)
  sta $2a
+ jmp main_save

++cmp #$91 ; cursor up key
  bne ++
up:
  lda $29
  sbc #columns
  sta $29
  bcs +
  dec $2a
  sec
+ lda $28
  sbc #1
  and #7
  sta $28
  cmp #7
  bne +
  clc
  lda $29
  adc #<(columns*8)
  sta $29
  lda $2a
  adc #>(columns*8)
  sta $2a
+ jmp main_save

++cmp #$1D ; cursor right key
  bne ++
right:
  inc $29
  lda $27
  adc #0
  sta $27
  and #7
  bne +
  sec
  lda $29
  sbc #8
  sta $29
  lda #0
  sta $27
+ jmp main_save

++cmp #$9D ; cursor left key
  bne ++
left:  
  dec $29
  dec $27
  bpl +
  clc
  lda $29
  adc #8
  sta $29
  lda #7
  sta $27
+ jmp main_save

++cmp #$13 ; HOME key
  bne ++
home:  
  lda #0
  sta $27
  sta $28
  lda #(columns+16)
  sta $29
  lda #>video
  sta $2a
  jmp main_save

++cmp #$20 ; space key
  bne ++
toggle_bit:
  jsr save_undo  
  ldx $27
  ldy $28
  lda ($22),y
  eor bitmask,x
  sta ($22),y
  jmp main

++cmp #$03 ; stop key
  bne ++
bye:  
  lda $D018
  and #$F0
  ora #$02
  sta $D018 ; turn on programmable characters
  
  lda #<done
  ldx #>done
  jsr strout

  jsr fill_color
  jsr all_chars

  rts

++cmp #$53 ; 'S' key
  bne ++
save_font:
  ldx #13  
--lda #$0d
  jsr charout
  dex
  bne --
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
  sta $fb
  lda #>(start-1)
  sta $fc
  lda #$fb
  ldx #<(new_start)
  ldy #>(new_start)
  jsr fsave
  lda #<press_key
  ldx #>press_key
  jsr strout
--jsr getkey
  beq --
  jmp init_screen

++cmp #$93 ; CLR key
  bne ++
clear:  
  jsr save_undo  
  lda #0
  ldy #7
--sta ($22),y
  dey
  bpl --
  jmp main

++cmp #$12 ; RVS key
  bne ++
rvs:  
  jsr save_undo  
  ldy #7
--lda ($22),y
  eor #$ff
  sta ($22),y
  dey
  bpl --
  jmp main

++cmp #$3C ; '<' key
  bne ++
shiftleft:  
  jsr save_undo  
  ldy #7
--lda ($22),y
  asl
  sta ($22),y
  dey
  bpl --
  jmp main

++cmp #$3E ; '>' key
  bne ++
shiftright:  
  jsr save_undo  
  ldy #7
--lda ($22),y
  lsr
  sta ($22),y
  dey
  bpl --
  jmp main

++cmp #$D6 ; capital 'V' key
  bne ++
shiftdown:  
  jsr save_undo  
  ldy #7
--dey
  lda ($22),y
  iny
  sta ($22),y
  dey
  bpl --
  iny
  lda #0
  sta ($22),y
  jmp main

++cmp #$5E ; '^' key
  bne ++
shiftup:  
  jsr save_undo  
  ldx #7
  ldy #0
--iny
  lda ($22),y
  dey
  sta ($22),y
  iny
  dex
  bne --
  lda #0
  sta ($22),y
  jmp main

++cmp #$46 ; 'F' key
  bne ++
flip:  
  jsr save_undo  
  ldy #3
  sty $ff
  iny
  sty $fe
--ldy $ff
  lda ($22),y
  pha
  ldy $fe
  lda ($22),y
  tax
  pla
  sta ($22),y
  ldy $ff
  txa
  sta ($22),y
  inc $fe
  dec $ff
  bpl --
  jmp main

++cmp #$52 ; 'R' key
  bne ++
rotate:  
  jsr save_undo  
  ldy #0
---ldx #0
--lda ($22),y
  asl
  sta ($22),y
  ror $a9,x
  inx
  cpx #8
  bne --
  iny
  cpy #8
  bne ---
  ldy #7
--lda $a9,y
  sta ($22),y
  dey
  bpl --
  jmp main

++cmp #$4d ; 'M' key
  bne ++
mirror:  
  jsr save_undo  
  ldy #7
---ldx #7
--lda ($22),y
  lsr
  sta ($22),y
  lda $a9,y
  rol
  sta $a9,y
  dex
  bpl --
  dey
  bpl ---
  ldy #7
--lda $a9,y
  sta ($22),y
  dey
  bpl --
  jmp main

++cmp #$40 ; '@' key
  bne ++
toggle_chars:
  lda $D018
  eor #$06
  sta $D018 ; turn on programmable characters
  jmp -

++cmp #$2a ; '*' key
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
--lda ($fb),y
  sta ($22),y
  dey
  bpl --
+ jmp main

++cmp #$43 ; 'C' key
  bne ++
copy:
  ldy #7
--lda ($22),y
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
  sta ($22),y
  dey
  bpl --
+ jmp main

++cmp #$58; 'X' key
  bne ++
cut:
  jsr save_undo
  ldy #7
--lda ($22),y
  sta clipboard,y
  lda #0
  sta ($22),y
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
  sta $fb
  stx $fc
  ldx #(>(start-1))+8
  sta $fd
  stx $fe
  ldx #8
  stx $ff
  ldy #0
--lda ($fb),y
  tax
  lda ($fd),y
  sta ($fb),y
  txa
  sta ($fd),y
  iny
  bne --
  inc $fc
  inc $fe
  dec $ff
  bne --
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
  ; fall through

++jmp -

strout:
  sta $fb
  stx $fc
  ldy #$00
- lda ($fb),y
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
  lda $b4
  ldx $b5
  jsr strout
  iny
  tya
  clc
  adc $b4
  sta $b4
  bcc +
  inc $b5
+ rts

dispchar:
  lda #(columns+16)
  sta $24
  lda #>video
  sta $25
  lda #$08
  sta $ff
  ldy #$00
--ldx #$08
  lda ($22),y
  sta $26
- lda #$20 ; ' ' space
  asl $26
  bcc +
  lda pixel_char
+ sta ($24),y
  inc $24
  bne +
  inc $25
+ dex
  bne -
  clc
  lda $24
  adc #(columns-9)
  sta $24
  bcc +
  inc $25
+ iny
  dec $ff
  bne --
  lda $23
  sta $ff
  lda $22
  lsr $ff
  ror
  lsr $ff
  ror
  lsr $ff
  ror
  ldx #(15+10)
  stx $24
  ldx #>video
  stx $25
  sec
  ror $ff
  ldy #$00
  jsr disphex
  inc $24
  bne +
  inc $25
+ clc
  ror $ff
  ldx #$08
- clc
  lda $24
  adc #(columns-2)
  sta $24
  bcc +
  inc $25
+ lda ($22),y
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
  inc $24
  bne +
  inc $25
+ pla
  and #$0f
  ; fall through
dispnybl:
  ora #$30 ; '0' screen code
  cmp #$3a
  bcc +    ; branch if less
  sbc #$39 ; subtract to get to 'A' to 'F' screen codes
+ bit $ff
  bpl +
  ora #$80 ; reverse text
+ sta ($24),y
  rts

chkblink:
  sec
  lda $a3
  cmp $a2
  bne +
  lda $a2
  adc #$1d
  sta $a3
  ldy #0
  lda ($29),y
  eor #$80
  sta ($29),y
+ rts

blinkoff:
  ldy #0
  lda save_cursor
  sta ($29),y
  clc
  lda $a2
  adc #2
  sta $a3
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
  sta $fb
  stx $fc
  ldy #0
- tya
  sta ($fb),y
  iny
  bne -
  rts

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
- lda ($22),y
  sta ($fb),y
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
  sta $fb
  ldx #>undo_buffer
  bcc +
  inx
+ stx $fc
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

bitmask:
  !byte $80,$40,$20,$10,$08,$04,$02,$01

invmask:
  !byte $7f,$cf,$df,$ef,$f7,$fc,$fd,$fe

clear_header:
  !byte $93
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
  !text 13,0

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
pixel_char: !byte 160
pixel_char_alternate !byte 42
