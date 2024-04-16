; ch20edit.asm

charrom = $8000
charout = $ffd2
getkey = $ffe4
setlfs = $ffba
setnam = $ffbd
save = $ffd8

*=$1001
start:
!byte $0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 

*=$1800
new_start:
!byte $00,$0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 
  lda $2c
  cmp #>new_start
  beq init_screen ; skip one-time init
  lda #>new_start
  sta $2c ; reset basic start

  lda $9005
  and #$F0
  sta $9005 ; turn off programmable characters

; copy charrom to ram 
  lda #0
  sta $fb
  sta $fd
  lda #>(start-1)
  sta $fc
  lda #>charrom
  sta $fe
  lda #$08
  sta $ff ; store count
  ldy #$00
- lda ($fd),y
  sta ($fb),y
  iny
  bne -
  inc $fc
  inc $fe
  dec $ff
  bne -

init_screen:
  lda #<clear_header
  ldx #>clear_header
  jsr strout

  ; fill color ram so we can poke characters to video ram to be seen
  ldy #$00
  lda $0286
- sta $9600,y
  sta $9700,y
  iny
  bne -

  lda #$30 ; zero character
  sta $fd  ; init first digit
  lda #$08
  sta $ff  ; set count
- lda #$12 ; rvs on
  jsr charout
  lda $fd  ; retrieve digit
  jsr charout
  lda #<blanks
  ldx #>blanks
  jsr strout
  lda $fd ; retrieve digit
  jsr charout
  lda #$0d ; carriage return
  jsr charout
  inc $fd  ; ++digit
  dec $ff  ; --count
  bne -
  lda #<header
  ldx #>header
  jsr strout
  lda #<copyright
  ldx #>copyright
  jsr strout

  lda #0
  sta $27
  lda #0
  sta $28
  lda #23
  sta $29
  lda #$1e
  sta $2a
  lda #<(start-1)
  sta $22
  lda #>(start-1)
  sta $23

main:
  clc
  lda $a2
  adc #$1e
  sta $a3
  jsr dispchar
- jsr chkblink
  jsr getkey
  beq - ; no key pressed

  cmp #$4e ; 'N' key
  bne ++
  lda $22
  adc #$07
  sta $22
  bcc main
  inc $23
  lda $23
  cmp #$18
  bcc main
  lda #$10
  sta $23
+ bne main

++cmp #$42 ; 'B' key
  bne ++
  sec
  lda $22
  sbc #$08
  sta $22
  bcs main
  dec $23
  lda $23
  cmp #$10
  bcs main
  lda #$17
  sta $23
  bne main

++cmp #$11 ; cursor down key
  bne ++
  jsr blinkoff
  clc
  lda $29
  adc #22
  sta $29
  lda $28
  adc #1
  and #7
  sta $28
  bne +
  sec
  lda $29
  sbc #(22*8)
  sta $29
+ jmp -

++cmp #$91 ; cursor up key
  bne ++
  jsr blinkoff
  sec
  lda $29
  sbc #22
  sta $29
  sec
  lda $28
  sbc #1
  and #7
  sta $28
  cmp #7
  bne +
  clc
  lda $29
  adc #(22*8)
  sta $29
+ jmp -

++cmp #$1D ; cursor right key
  bne ++
  jsr blinkoff
  inc $29
  clc
  lda $27
  adc #1
  sta $27
  and #7
  bne +
  sec
  lda $29
  sbc #8
  sta $29
  lda #0
  sta $27
+ jmp -

++cmp #$9D ; cursor left key
  bne ++
  jsr blinkoff
  dec $29
  dec $27
  bpl +
  clc
  lda $29
  adc #8
  sta $29
  lda #7
  sta $27
+ jmp -

++cmp #$20 ; space key
  bne ++
  jsr blinkoff
  ldx $27
  ldy $28
  lda ($22),y
  eor bitmask,x
  sta ($22),y
  jmp main

++cmp #$03 ; break key
  bne ++
  jsr blinkoff
  lda $9005
  and #$F0
  ora #$0C
  sta $9005 ; turn on programmable characters
  
  lda #<$1e00
  ldx #>$1e00
  sta $fb
  stx $fc
  lda #16
  sta $ff
  lda #0
  sta $fd
---
  ldy #0
--lda $fd
  sta ($fb),y
  inc $fd
  iny
  cpy #16
  bcc --
  clc
  lda $fb
  adc #22
  sta $fb
  bcc +
  inc $fc
+ dec $ff
  bne ---

  lda #<exit
  ldx #>exit
  jsr strout
  rts

++cmp #$53 ; 'S' key
  bne ++
  jsr blinkoff
  lda #$0d
  jsr charout
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
  jsr save
  lda #<press_key
  ldx #>press_key
  jsr strout
--jsr getkey
  beq --
  jmp init_screen

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

dispchar:
  lda #$17
  sta $24
  lda #$1e
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
  lda #$2a ; '*' asterisk
+ sta ($24),y
  inc $24
  dex
  bne -
  clc
  lda $24
  adc #$0d
  sta $24
  iny
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
  ldx #$0b
  stx $24
  sec
  ror $ff
  ldy #$00
  jsr disphex
  inc $24
  clc
  ror $ff
  ldx #$08
- clc
  lda $24
  adc #$14
  sta $24
  lda ($22),y
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
  pla
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
  lda ($29),y
  and #$7f
  sta ($29),y
  clc
  lda $a2
  adc #2
  sta $a3
  rts

bitmask:
  !byte $80,$40,$20,$10,$08,$04,$02,$01

clear_header:
  !byte $93

header:
  !byte $12,$20,$37,$36,$35,$34,$33,$32,$31,$30,$20,$0d,$00

blanks:
  !byte $92,$20,$20,$20,$20,$20,$20,$20,$20,$12,$00

copyright:
  !text 13,18,"B",146,"ACK ",18,"N",146,"EXT ",18,"S",146,"AVE",13
  !text 18,"SPACE",146,32,18,"STOP",13
  !text 13
  !text "CH20EDIT",13
  !text "(C) 2024 DAVEVW.COM"
  !byte 0

exit:
  !byte 20,20,20,13,13,13,13,0

filename:
  !text "@0:FONT.BIN"
filename_end:

press_key: !text 13, 13, "PRESS ANY KEY", 13, 0
