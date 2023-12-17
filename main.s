.INCLUDE "gametank_cpu.i"
.INCLUDE "acp/acp.i"

.ROMBANKSIZE $4000
.ROMBANKS 2

.SECTION "MainProg" BANK 1 SLOT 4
reset:
  ; Init Code
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
  bne -
  
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