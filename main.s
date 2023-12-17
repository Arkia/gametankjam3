.INCLUDE "gametank_cpu.i"
.INCLUDE "acp/acp.i"

.ROMBANKSIZE $4000
.ROMBANKS 2

.SECTION "MainProg" BANK 1 SLOT 4
reset:
  ; Init Code
  cld
  stz BANK_FLAGS  ; Reset bank settings
  lda #%01001001  ; Enable blitter and colorfill mode
  sta DMA_FLAGS   ; Setup blitter
  lda #$7F        ; Disable ACP
  sta AUDIO_RATE
  
  ldx #0
-
  lda acp_prog.w,x
  sta ACP_PROG_START,x
  inx
  cpx #acp_size
  bne -
  
  ldx #5
-
  lda acp_vectors.w,x
  sta $3FFA,x
  dex
  bpl -
  
  ldx #VOICE_COUNT-1
-
  stz VOICE_VOLUME,x
  dex
  bpl -
  
  ldx #2
-
  lda #15
  sta VOICE_VOLUME,x
  lda chord_step_lo.w,x
  sta VOICE_STEP_LO,x
  lda chord_step_hi.w,x
  sta VOICE_STEP_HI,x
  dex
  bpl -
  
  stz AUDIO_RESET
  lda #$FF
  sta AUDIO_RATE
  
  lda #16
  sta DMA_VX
  sta DMA_VY
  sta DMA_WIDTH
  sta DMA_HEIGHT
  lda #%00011000
  sta DMA_COLOR
  lda #1
  sta DMA_START
  
main_loop:
  bra main_loop
  
irq:
  rti
  
nmi:
  rti
  
chord_step_lo:
  .DB $DC $1F $48
chord_step_hi:
  .DB $04 $06 $07
.ENDS

.SECTION "ACPImport" BANK 0 SLOT 3
  acp_prog:
    .INCBIN "acp/acp.dat" READ -6 FREADSIZE acp_size
  acp_vectors:
    .INCBIN "acp/acp.dat" SKIP acp_size
.ENDS
  
.SECTION "VectorTable" BANK 1 SLOT 4 ORGA $FFFA FORCE
  .DW nmi
  .DW reset
  .DW irq
.ENDS