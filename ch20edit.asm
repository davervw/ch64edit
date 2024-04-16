; ch20edit.asm

charrom = $8000
charout = $ffd2
getkey = $ffe4

*=$1001
start:
!byte $0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 

*=$1800
new_start:
!byte $00,$0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 
  lda #>new_start
  sta $2c ; reset basic start

  ; initialize screen
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

; copy charrom to ram 
  lda #0
  sta $fb
  sta $fd
  sta $22
  lda #>start
  sta $fc
  sta $23
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

main:
  jsr dispchar
--jsr getkey
  beq -- ; no key pressed

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
  bne --
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

clear_header:
  !byte $93

header:
  !byte $12,$20,$37,$36,$35,$34,$33,$32,$31,$30,$20,$0d,$00

blanks:
  !byte $92,$20,$20,$20,$20,$20,$20,$20,$20,$12,$00

copyright:
  !byte 13
  !text "CH20EDIT"
  !byte 13
  !text "(C) 2024 DAVEVW.COM"
  !byte 0
