; ch20edit.asm

*=$1001
!byte $0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 

*=$1800
!byte $00,$0b,$18,$0a,$00,$9e,$36,$31,$35,$37,$00,$00,$00 
  lda #$18
  sta $2c
  lda #$00
  ldx #$1d
  jsr $18f2
  lda #$30
  sta $fd
  lda #$08
  sta $ff
  lda #$12
  jsr $ffd2
  lda $fd
  jsr $ffd2
  lda #$0e
  ldx #$1d
  jsr $1888
  lda $fd
  jsr $ffd2
  lda #$0d
  jsr $ffd2
  inc $fd
  dec $ff
  bne $1820
  lda #$01
  ldx #$1d
  jsr $1888
  lda #$00
  sta $fb
  sta $fd
  sta $22
  lda #$10
  sta $fc
  sta $23
  lda #$80
  sta $fe
  lda #$08
  sta $ff
  ldy #$00
  lda ($fd),y
  sta ($fb),y
  iny
  bne $1860
  inc $fc
  inc $fe
  dec $ff
  bne $1860
  jsr $1904
  jsr $ffe4
  beq $1872
  cmp #$4e
  bne $1899
  lda $22
  adc #$07
  sta $22
  bcc $1885
  inc $23
  jmp $18b5
  sta $fb
  stx $fc
  ldy #$00
  lda ($fb),y
  beq $1898
  jsr $ffd2
  iny
  bne $188e
  rts
  cmp #$42
  bne $1872
  sec
  lda $22
  sbc #$08
  sta $22
  bcs $18a8
  dec $23
  lda $23
  cmp #$10
  bcs $18b2
  lda #$17
  sta $23
  jmp $186f
  lda $23
  cmp #$18
  bcc $18bf
  lda #$10
  sta $23
  jmp $186f
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  tax
  jsr $1888
  ldy #$00
  lda $0286
  sta $9600,y
  sta $9700,y
  iny
  bne $18fa
  rts
  lda #$17
  sta $24
  lda #$1e
  sta $25
  lda #$08
  sta $ff
  ldy #$00
  ldx #$08
  lda ($22),y
  sta $26
  lda #$20
  asl $26
  bcc $1920
  lda #$2a
  sta ($24),y
  inc $24
  dex
  bne $1918
  clc
  lda $24
  adc #$0d
  sta $24
  iny
  dec $ff
  bne $1912
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
  jsr $1966
  inc $24
  clc
  ror $ff
  ldx #$08
  clc
  lda $24
  adc #$14
  sta $24
  lda ($22),y
  jsr $1966
  iny
  dex
  bne $1955
  rts
  pha
  lsr
  lsr
  lsr
  lsr
  ora #$30
  cmp #$3a
  bcc $1973
  sbc #$39
  bit $ff
  bpl $1979
  ora #$80
  sta ($24),y
  inc $24
  pla
  and #$0f
  ora #$30
  cmp #$3a
  bcc $1988
  sbc #$39
  bit $ff
  bpl $198e
  ora #$80
  sta ($24),y
  rts

*=$1d00
clear_header:
!byte $93

header:
!byte $12,$20,$37,$36,$35,$34,$33,$32,$31,$30,$20,$0d,$00

blanks:
!byte $92,$20,$20,$20,$20,$20,$20,$20,$20,$12,$00
