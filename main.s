.INCLUDE "gametank_cpu.i"

.ROMBANKSIZE $4000
.ROMBANKS 2

.BANK 1 SLOT 4

reset:
  ; Init Code
  stz BANK_FLAGS  ; Reset bank settings
  lda #%01001001  ; Enable blitter and colorfill mode
  sta DMA_FLAGS   ; Setup blitter
  
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
  
.ORGA $FFFA
  .DW nmi
  .DW reset
  .DW irq