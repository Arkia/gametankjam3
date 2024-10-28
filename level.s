.RAMSECTION "LevelVars" BANK 0 SLOT "ZeroPage"
  level_state     db
  level_ptr       dw
  level_timer     dw
.ENDS

.SECTION "LevelRoutines" BANK 1 SLOT "FixedROM"
; Initialize level number X
init_level:
  stz level_state                       ; Clear level done flag
  lda level_data_lo.w,x                 ; Load data pointer low byte
  sta level_ptr                         ; Set current level data pointer
  lda level_data_hi.w,x                 ; Load data pointer high byte
  sta level_ptr+1                       ; Set current level data pointer
  lda #1                                ; Set next spawn time to 1 frame
  sta level_timer
  stz level_timer+1

update_level:
  lda level_state                       ; Is level over?
  beq +
  rts
+
  lda level_timer                       ; Get level timer low byte
  bne +                                 ; If zero
  dec level_timer+1                     ; Decrement timer high byte
+
  dec level_timer                       ; Decrement low byte
  lda level_timer                       ; Get level timer low byte
  ora level_timer+1                     ; Combine with level timer high byte
  beq +                                 ; If timer is zero, spawn next enemy
  rts                                   ; Otherwise return
+
  ldy #0                                ; Set index to zero
  lda (level_ptr),y                     ; Read ID
  bpl +                                 ; If ID.b7 is set
  inc level_state                       ; Flag level done
  rts                                   ; End of level
+
  iny                                   ; Increment index
  phy                                   ; Save Y
  jsr spawn_object                      ; Spawn enemy
  ply                                   ; Restore Y
  cpx #0                                ; Test returned enemy index
  bpl @spawned_enemy                    ; If negative, no slots were free
  iny                                   ; Move index to timer entry
  iny
  bra @read_timer                       ; Read timer entry
@spawned_enemy
  stz enemy_frame.w,x
  lda (level_ptr),y                     ; Get X position
  iny                                   ; Increment index
  sta enemy_x_hi.w,x                    ; Set enemy X
  lda (level_ptr),y                     ; Get Y position
  iny                                   ; Increment index
  sta enemy_y_hi.w,x                    ; Set enemy Y
@read_timer
  lda (level_ptr),y                     ; Get timer low byte
  iny                                   ; Increment index
  sta level_timer                       ; Set level timer low
  lda (level_ptr),y                     ; Get timer high byte
  iny                                   ; Increment index
  sta level_timer+1                     ; Set level timer high
  clc                                   ; Setup addition
  tya                                   ; Move index into A
  adc level_ptr                         ; Advance level data pointer
  sta level_ptr                         ; Update level pointer low
  bcc +
  inc level_ptr+1                       ; Carry into level pointer high
+
  rts                                   ; Return
.ENDS

.SECTION "LevelData" BANK 0 SLOT "BankROM"
level_data_lo:
  .DB <level1_data
level_data_hi:
  .DB >level1_data
level1_data:
  .TABLE  byte, byte, byte, word
  .DATA   $05,  128,   64,  360
  .DATA   $00,  128,   64,   60
  .DATA   $01,  128,   64,   60
  .DATA   $02,  128,   64,   60
  .DATA   $FF,    0,    0,    0
.ENDS
