.RAMSECTION "GameVars" BANK 0 SLOT "ZeroPage"
  bcd_lives         db
  bcd_score         dw
.ENDS

.RAMSECTION "StatusStrings" BANK 0 SLOT "WRAM"
  str_lives         dsb 4
  str_score         dsb 6
.ENDS

.SECTION "GameRoutines" BANK 1 SLOT "FixedROM"
init_game:
  stz bcd_lives
  stz bcd_score
  stz bcd_score+1
  ldx #9
-
  stz str_lives.w,x
  dex
  bpl -
  lda #ASC('f')
  sta str_lives.w
  lda #ASC('x')
  sta str_lives.w+1
  lda #ASC('0')
  sta str_lives.w+3
  sta str_score.w+5
  rts
.ENDS
