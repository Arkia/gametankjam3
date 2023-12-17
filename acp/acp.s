.MEMORYMAP
DEFAULTSLOT 2
SLOT 0 $0000 $0100 "ZeroPage"
SLOT 1 $0100 $0100 "Stack"
SLOT 2 $0200 $0E00 "WRAM"
.ENDME

.DEFINE DAC_OUT $80FF
.DEFINE VOICE_COUNT 8

.RAMSECTION "ZP" BANK 0 SLOT 0
voice_volume  DSB VOICE_COUNT
voice_duty    DSB VOICE_COUNT
voice_step_lo DSB VOICE_COUNT
voice_step_hi DSB VOICE_COUNT
voice_pos_lo  DSB VOICE_COUNT
voice_pos_hi  DSB VOICE_COUNT
sample_acc    DB
.ENDS

.ROMBANKSIZE $0E00
.ROMBANKS 1

.BANK 0 SLOT 2
.ORGA $0F00

acp_reset:
  sei
  cld
  ldx #VOICE_COUNT-1
-
  stz voice_pos_lo,x
  stz voice_pos_hi,x
  dex
  bpl -
  cli
acp_loop:
  bra acp_loop
  
acp_irq:
  stz sample_acc
  
  ldx #VOICE_COUNT-1
sample_loop:
  clc                   ; 2
  lda voice_pos_lo,x    ; 4 (6)
  adc voice_step_lo,x   ; 4 (10)
  sta voice_pos_lo,x    ; 4 (14)
  lda voice_pos_hi,x    ; 4 (18)
  adc voice_step_hi,x   ; 4 (22)
  sta voice_pos_hi,x    ; 4 (26)
  cmp voice_duty,x      ; 4 (30)
  lda voice_volume,x    ; 4 (34)
  bcc +
  eor #$FF
  ina
+
  clc
  adc sample_acc
  bvc +
  lda #$7F
  bbr7 sample_acc,+
  lda #$80
+
  sta sample_acc
  dex
  bpl sample_loop
  lda sample_acc
  bpl +
  ina
+
  clc
  adc #127
  sta DAC_OUT
  rti
  
acp_nmi:
  rti
  
  .DW acp_nmi
  .DW acp_reset
  .DW acp_irq