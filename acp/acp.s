.MEMORYMAP
DEFAULTSLOT 2
SLOT 0 $0000 $0100 "ZeroPage"
SLOT 1 $0100 $0100 "Stack"
SLOT 2 $0200 $0E00 "WRAM"
.ENDME

.DEFINE DAC_OUT $80FF
.DEFINE VOICE_COUNT 6

.RAMSECTION "ZP" BANK 0 SLOT 0
voice_volume  DSB VOICE_COUNT
voice_wave_lo DSB VOICE_COUNT
voice_wave_hi DSB VOICE_COUNT
voice_step_lo DSB VOICE_COUNT
voice_step_hi DSB VOICE_COUNT
voice_pos_lo  DSB VOICE_COUNT
voice_pos_hi  DSB VOICE_COUNT
wave_ptr      DW
sample_acc    DW
.ENDS

.ROMBANKSIZE $0E00
.ROMBANKS 1

.BANK 0 SLOT 2
.ORGA $0F00

acp_reset:
  ldx VOICE_COUNT-1
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
  stz sample_acc+1
  
  ldx VOICE_COUNT-1
sample_loop:
  lda voice_wave_lo,x     ; 4
  sta wave_ptr            ; 3 (7)
  lda voice_wave_hi,x     ; 4 (11)
  sta wave_ptr+1          ; 3 (14)
  clc                     ; 2 (16)
  lda voice_step_lo,x     ; 4 (20)
  adc voice_pos_lo,x      ; 4 (24)
  sta voice_pos_lo,x      ; 4 (28)
  lda voice_step_hi,x     ; 4 (32)
  adc voice_pos_hi,x      ; 4 (36)
  sta voice_pos_hi,x      ; 4 (40)
  lsr a                   ; 2 (42)
  lsr a                   ; 2 (44)
  tay                     ; 2 (46)
  lda (wave_ptr),y        ; 5 (51)
  ldy voice_volume,x      ; 4 (55)
  beq +                   ; 3 (58)
-
  lsr a                   ; 2
  dey                     ; 2 (4)
  bne -                   ; 3 (7)
+                         ; 7 * 8 (114)
  clc                     ; 2 (116)
  adc sample_acc          ; 3 (119)
  sta sample_acc          ; 3 (121)
  dex                     ; 2 (123)
  bpl sample_loop         ; 3 (126)
  sta DAC_OUT
  rti
  
acp_nmi:
  rti
  
  .DW acp_nmi
  .DW acp_reset
  .DW acp_irq