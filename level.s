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

; ARGS: Delay Ticks
.MACRO L_DELAY
  .DATA   $00,  0,  0,  \1
.ENDM

.MACRO L_END
  .DATA   $FF,  0,  0,  0
.ENDM

; ARGS: Enemy ID, Y-Start, Y-Step, Count, Delay Ticks
.MACRO E_DECEND
  .REPT \4 INDEX I
    .DATA   \1,  128,  \2+I*\3,  \5
  .ENDR
.ENDM

; ARGS: Enemy ID, Y-Start, Y-Step, Count, Delay Ticks
.MACRO E_ACCEND
  .REPT \4 INDEX I
    .DATA   \1,  128,  \2-I*\3,  \5
  .ENDR
.ENDM

; ARGS: Enemy ID, X-Start, X-Step, Y, Count, Delay Ticks
.MACRO E_HORIZ
  .REPT \5 INDEX I
    .DATA   \1, \2+I*\3,  \4, \6
  .ENDR
.ENDM

; ARGS: Enemy ID 0, Enemy ID 1, X-Start, X-Step, Count, Delay Ticks
.MACRO E_HORIZ_ALT
  .REPT \5 INDEX I
    .IF I#2
      .DATA \1, \3+I*\4, 8, \6
    .ELSE
      .DATA \2, \3+I*\4, 128, \6
    .ENDIF
  .ENDR
.ENDM

; ARGS: Enemy ID, Y-Start, Y-Step, Count, Delay Ticks
.MACRO E_TO_MIDDLE
  .DATA   \1,  128,  \2,   \5
  .REPT \4 INDEX I
    .DATA   \1,  129,  \2-(I+1)*\3,  1
    .DATA   \1,  128,  \2+(I+1)*\3,  \5
  .ENDR
.ENDM

; ARGS: Enemy ID, Y-Start, Y-Step, Count, Delay Ticks
.MACRO E_FROM_MIDDLE
  .REPT \4 INDEX I
    .DATA   \1,  129,  \2-(2-I)*\3,  1
    .DATA   \1,  128,  \2+(2-I)*\3,  \5
  .ENDR
  .DATA   \1,  128,  \2,   \5
.ENDM

; ARGS: Enemy ID, Y-Min, Y-Max, Count, Delay Ticks
.MACRO E_RANDOM_V
  .REPT \4
    .DATA   \1,  128,  random(floor(\2/4), floor(\3/4))*4, \5
  .ENDR
.ENDM

; ARGS: Enemy ID, X-Min, X-Max, Y, Count, Delay Ticks
.MACRO E_RANDOM_H
  .REPT \5
    .DATA   \1, random(floor(\2/4), floor(\3/4))*4, \4, \6
  .ENDR
.ENDM

.SECTION "LevelData" BANK 0 SLOT "BankROM"
level_data_lo:
  .DB <level1_data
level_data_hi:
  .DB >level1_data
level1_data:
  .SEED 1000
  .TABLE  byte, byte, byte, word
  L_DELAY 300
  E_RANDOM_V $01, 16, 94, 16, 64
  L_DELAY 120
  E_DECEND $01, 20, 16, 5, 32
  L_DELAY 60
  E_ACCEND $01, 94, 16, 5, 32
  L_DELAY 90
  E_RANDOM_V $01, 16, 94, 24, 32
  L_DELAY 120
  E_TO_MIDDLE $01, 60, 8, 5, 16
  L_DELAY 120
  .DATA $05, 128, 60, 180
  L_DELAY 60
  E_TO_MIDDLE $05, 60, 24, 1, 64
  L_DELAY 60
  E_RANDOM_V $01, 16, 94, 8, 32
  .DATA $05, 128, 28, 32
  E_RANDOM_V $01, 16, 94, 8, 32
  .DATA $05, 128, 60, 32
  E_RANDOM_V $01, 16, 94, 8, 32
  .DATA $05, 128, 92, 32
  E_RANDOM_V $01, 16, 94, 8, 32
  L_DELAY 120
  E_DECEND $08, 28, 16, 4, 64
  L_DELAY 60
  E_ACCEND $08, 94, 16, 4, 64
  L_DELAY 90
  .REPT 8
    E_RANDOM_V $01, 16, 94, 4, 32
    E_RANDOM_V $08, 16, 94, 1, 32
  .ENDR
  E_RANDOM_V $01, 16, 94, 4, 32
  L_DELAY 120
  E_HORIZ $0C, 4, 16, 8, 8, 16
  E_HORIZ $0F, 116, -16, 128, 8, 16
  L_DELAY 60
  .REPT 8
    E_RANDOM_V $01, 16, 94, 8, 24
    E_RANDOM_H $0C, 4, 116, 8, 1, 24
    E_RANDOM_V $01, 16, 94, 8, 24
    E_RANDOM_H $0F, 4, 116, 128, 1, 24
  .ENDR
  E_RANDOM_V $01, 16, 94, 8, 24
  L_DELAY 120
  .DATA $05, 128, 60, 180
  .DATA $05, 128, 60, 32
  .DATA $08, 131, 44, 2
  .DATA $08, 128, 76, 90
  .REPT 4
    E_RANDOM_V $08, 16, 94, 8, 32
    E_RANDOM_V $05, 16, 94, 1, 32
  .ENDR
  .REPT 6
    E_RANDOM_V $08, 16, 94, 4, 32
    E_RANDOM_V $05, 16, 94, 1, 32
  .ENDR
  .REPT 8
    E_RANDOM_V $08, 16, 94, 4, 32
    E_RANDOM_V $05, 16, 94, 1, 32
    E_RANDOM_H $0C, 4, 116, 8, 1, 32
    E_RANDOM_V $08, 16, 94, 4, 32
    E_RANDOM_V $05, 16, 94, 1, 32
    E_RANDOM_H $0F, 4, 116, 128, 1, 32
  .ENDR
  L_DELAY 90
  .DATA $12, 60, 8, 180
  .REPT 4
    E_RANDOM_V $01, 16, 94, 8, 32
    E_RANDOM_H $12, 4, 116, 8, 1, 32
  .ENDR
  .REPT 4
    E_RANDOM_V $08, 16, 94, 8, 32
    E_RANDOM_H $12, 4, 116, 8, 1, 32
  .ENDR
  .REPT 6
    E_RANDOM_V $08, 16, 94, 12, 16
    E_RANDOM_H $12, 4, 116, 8, 1, 16
  .ENDR
  .REPT 8
    .REPT 2
      E_RANDOM_V $08, 16, 94, 4, 32
      E_RANDOM_V $05, 16, 94, 1, 32
    .ENDR
    E_RANDOM_H $12, 4, 116, 8, 1, 32
    .REPT 2
      E_RANDOM_V $08, 16, 94, 4, 32
      E_RANDOM_V $05, 16, 94, 1, 32
    .ENDR
    E_RANDOM_H $13, 4, 116, 128, 1, 32
  .ENDR
  L_DELAY 60
  .DATA $12, 28, 5, 1
  .DATA $12, 92, 6, 1
  .DATA $13, 28, 129, 1
  .DATA $13, 92, 128, 32
  E_TO_MIDDLE $08, 60, 12, 5, 4
  L_DELAY 500
  L_END
.ENDS
