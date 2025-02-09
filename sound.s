.RAMSECTION "SoundEngine" BANK 0 SLOT 0
  sfx_data_lo   dsb 8
  sfx_data_hi   dsb 8
  sfx_index     dsb 8
  sfx_status    dsb 8
  sfx_timer     dsb 8
  sfx_ptr       dw
  sfx_block     db
.ENDS

.SECTION "SoundRoutines" BANK 1 SLOT 4
; Play sound with ID in Y on channel X
play_sound:
  lda sfx_table_lo.w,y    ; Get sound pointer low byte
  sta sfx_data_lo,x       ; Set channel pointer low
  sta temp                ; Store into temp ptr
  lda sfx_table_hi.w,y    ; Get sound pointer high byte
  sta sfx_data_hi,x       ; Set channel pointer high
  sta temp+1              ; Store into temp ptr
  ldy #0                  ; Start index at 0
  lda (temp),y            ; Get duty byte
  sta VOICE_DUTY,x        ; Set channel duty cycle
  iny                     ; Increment index
  sty sfx_index,x         ; Set channel index
  lda #1                  ; Set timer to 1 to trigger next update
  sta sfx_timer,x         ; Set timer
  lda #$80                ; Channel playing bit
  sta sfx_status,x        ; Set channel to playing
  rts                     ; Return

init_sound:
  ldx #42         ; 43 bytes
-
  stz sfx_data_lo,x
  dex
  bpl -

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

  stz AUDIO_RESET
  lda #$FF
  sta AUDIO_RATE
  rts

update_sound:
  lda sfx_block                     ; Check if update is already running
  beq +                             ; If not, then do update
  rts                               ; Otherwise return
+
  inc sfx_block                     ; Set flag for update running
  ldx #VOICE_COUNT-1                ; For each channel
-
  lda sfx_status,x                  ; Get channel status
  bpl @next_channel                 ; If bit 7 is clear, channel is not playing
  dec sfx_timer,x                   ; Decrement delay timer
  bne @next_channel                 ; If timer is not zero, continue
  lda sfx_data_lo,x                 ; Get sound data pointer low
  sta sfx_ptr                       ; Store into temp pointer
  lda sfx_data_hi,x                 ; Get sound data pointer high
  sta sfx_ptr+1                     ; Store into temp pointer
  ldy sfx_index,x                   ; Get data index
  lda (sfx_ptr),y                   ; Load frequency byte
  lsr                               ; Right shift
  sta VOICE_STEP_HI,x               ; Set frequency high
  lda #0                            ; Clear A
  ror                               ; Collect low bit from frequency
  sta VOICE_STEP_LO,x               ; Set frequency low
  iny                               ; Increment index
  lda (sfx_ptr),y                   ; Get volume/delay byte
  pha                               ; Save onto stack
  .REPT 4
    lsr                             ; Shift volume nibble
  .ENDR
  sta VOICE_VOLUME,x                ; Set volume
  pla                               ; Restore volume/delay byte
  and #$0F                          ; Extract delay nibble
  beq @sound_end                    ; If delay is 0, end this sound
  sta sfx_timer,x                   ; Set next delay timer
  iny                               ; Increment index
  sty sfx_index,x                   ; Update index
  bra @next_channel                 ; Next channel
@sound_end:
  stz VOICE_VOLUME,x                ; Silence channel
  stz sfx_status,x                  ; Clear playing bit
@next_channel:
  dex                               ; Decrement channel index
  bpl -                             ; Loop
  stz sfx_block                     ; Clear update running flag
  rts
.ENDS

.SECTION "SoundEffects" BANK 0 SLOT 3
sfx_table_lo:
  .DB <sfx_shoot
  .DB <sfx_eshoot
  .DB <sfx_death
  .DB <sfx_respawn
  .DB <sfx_life_up
sfx_table_hi:
  .DB >sfx_shoot
  .DB >sfx_eshoot
  .DB >sfx_death
  .DB >sfx_respawn
  .DB >sfx_life_up
sfx_shoot:
  .DB $80
  .DB $20, $81
  .DB $1E, $71
  .DB $1C, $61
  .DB $1A, $51
  .DB $18, $41
  .DB $16, $31
  .DB $14, $21
  .DB $12, $11
  .DB $10, $00

sfx_eshoot:
  .DB $80
  .DB $1C, $61
  .DB $1A, $51
  .DB $18, $41
  .DB $16, $31
  .DB $14, $21
  .DB $12, $11
  .DB $10, $00

sfx_death:
  .DB $40
  .DB $20, $A2
  .DB $18, $A2
  .DB $10, $A4
  .DB $08, $A4
  .DB $06, $A4
  .DB $04, $A4
  .DB $02, $A4
  .DB $02, $00

sfx_respawn:
  .DB $80
  .DB $18, $A2
  .DB $20, $A2
  .DB $28, $A4
  .DB $1C, $A2
  .DB $24, $A2
  .DB $2C, $A4
  .DB $20, $A2
  .DB $28, $A2
  .DB $30, $A8
  .DB $30, $00

sfx_life_up:
  .DB $80
  .DB $18, $88
  .DB $18, $02
  .DB $2C, $8F
  .DB $2C, $00
.ENDS
