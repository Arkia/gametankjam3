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
  
  ; Load ACP program
  ldx 0                 ; Data index
-
  lda acp_prog,x        ; Load next program byte
  sta ACP_PROG_START,x  ; Store into audio memory
  inx                   ; Increment index
  cpx acp_size          ; All bytes copied?
  bne -
  
  ldx 0
-
  lda acp_vectors
  sta $3FFA,x
  inx
  cpx 6
  bne -
  
  ldx VOICE_COUNT-1
  lda 8
-
  sta VOICE_VOLUME,x
  dex
  bne -
  
  ldx 0
  lda 0
-
  sta $3300,x
  clc
  adc #4
  inx
  cpx 64
  bne -
  
  stz VOICE_WAVE_LO
  lda $33
  sta VOICE_WAVE_HI
  stz VOICE_VOLUME
  stz VOICE_STEP_LO
  lda $01
  sta VOICE_STEP_HI
  
  lda #1
  sta AUDIO_RESET
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
.ENDS

.SECTION "ACPImport"
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