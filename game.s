.RAMSECTION "GameVars" BANK 0 SLOT "ZeroPage"
  bcd_lives         db
  bcd_score         dsb 3
  bcd_state         db
  bcd_write         dw
.ENDS

.RAMSECTION "StatusStrings" BANK 0 SLOT "WRAM"
  str_lives         dsb 4
  str_score         dsb 6
.ENDS

.SECTION "GameRoutines" BANK 1 SLOT "FixedROM"
init_pre_level:
  lda #5
  sta bcd_lives
  stz bcd_score
  stz bcd_score+1
  stz bcd_score+2
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
  jsr init_player
  jsr init_objects
  jmp init_level1_bg

update_pre_level:
  lda p1_press                ; Get buttons
  and #PAD_START              ; Test start button
  beq +
  lda #STATE_GAME             ; Switch to game state
  sta next_state              ; Queue state change
+
  jsr update_player           ; Move player
  jsr wait_blitter            ; Wait for clear screen to finish
  jsr draw_level1_bg          ; Draw level background
  jsr update_pshots           ; Move player projectiles
  jsr update_status_bar       ; Print lives/score strings
  jsr draw_game               ; Draw objects
  lda #30
  sta draw_data+3
  lda #52
  sta draw_data+4
  lda #<str_pre_level
  sta draw_data
  lda #>str_pre_level
  sta draw_data+1
  lda #_sizeof_str_pre_level
  sta draw_data+2
  jmp draw_string

str_pre_level:
  .ASC "PRESS START!"

init_win:
  lda #%01000000
  sta player_state          ; Set player to no input

update_win:
  lda player_x+1
  cmp #128
  beq +
  inc player_x+1
+
  lda p1_press
  and #PAD_ANY
  beq +
  lda #STATE_PRE_LEVEL
  sta next_state
+
  jsr update_player           ; Move player
  jsr wait_blitter            ; Wait for clear screen to finish
  jsr draw_level1_bg          ; Draw level background
  jsr update_enemies          ; Move enemies
  jsr update_effects
  jsr update_pshots           ; Move player projectiles
  jsr update_eshots           ; Move enemy projectiles
  jsr update_status_bar       ; Print lives/score strings
  jsr draw_game               ; Draw objects
  lda #42
  sta draw_data+3
  lda #52
  sta draw_data+4
  lda #<str_win1
  sta draw_data
  lda #>str_win1
  sta draw_data+1
  lda #_sizeof_str_win1
  sta draw_data+2
  jsr draw_string
  lda #23
  sta draw_data+3
  lda #68
  sta draw_data+4
  lda #<str_win2
  sta draw_data
  lda #>str_win2
  sta draw_data+1
  lda #_sizeof_str_win2
  sta draw_data+2
  jsr draw_string
  lda #23
  sta draw_data+3
  lda #76
  sta draw_data+4
  lda #<str_win3
  sta draw_data
  lda #>str_win3
  sta draw_data+1
  lda #_sizeof_str_win3
  sta draw_data+2
  jmp draw_string

str_win1:
  .ASC "YOU WIN!"
str_win2:
  .ASC "PRESS A BUTTON"
str_win3:
  .ASC "TO RESTART"

init_lose:
  rts

update_lose:
  lda p1_press
  and #PAD_ANY
  beq +
  lda #STATE_PRE_LEVEL
  sta next_state
+
  jsr update_player           ; Move player
  jsr wait_blitter            ; Wait for clear screen to finish
  jsr draw_level1_bg          ; Draw level background
  jsr update_enemies          ; Move enemies
  jsr update_effects
  jsr update_pshots           ; Move player projectiles
  jsr update_eshots           ; Move enemy projectiles
  jsr update_status_bar       ; Print lives/score strings
  jsr draw_game               ; Draw objects
  lda #32
  sta draw_data+3
  lda #52
  sta draw_data+4
  lda #<str_lose
  sta draw_data
  lda #>str_lose
  sta draw_data+1
  lda #_sizeof_str_lose
  sta draw_data+2
  jsr draw_string
  lda #23
  sta draw_data+3
  lda #68
  sta draw_data+4
  lda #<str_win2
  sta draw_data
  lda #>str_win2
  sta draw_data+1
  lda #_sizeof_str_win2
  sta draw_data+2
  jsr draw_string
  lda #23
  sta draw_data+3
  lda #76
  sta draw_data+4
  lda #<str_win3
  sta draw_data
  lda #>str_win3
  sta draw_data+1
  lda #_sizeof_str_win3
  sta draw_data+2
  jmp draw_string

str_lose:
  .ASC "GAME OVER!"

init_game:
  ldx #0
  jmp init_level

update_game:
  jsr update_player           ; Move player
  jsr update_level            ; Spawn enemies
  lda level_state             ; Check level done
  beq +                       ; If level finished
  lda #STATE_WIN              ; Level win state
  sta next_state              ; Queue state change
+
  jsr wait_blitter            ; Wait for clear screen to finish
  jsr draw_level1_bg          ; Draw level background
  jsr update_enemies          ; Move enemies
  jsr update_effects
  jsr update_pshots           ; Move player projectiles
  jsr update_eshots           ; Move enemy projectiles
  jsr update_status_bar       ; Print lives/score strings
  jmp draw_game               ; Draw objects

update_status_bar:
  lda #<(str_lives+2)
  sta bcd_write
  lda #>(str_lives+2)
  sta bcd_write+1
  lda #%01000000
  sta bcd_state
  lda bcd_lives
  jsr bcd_to_string
  ldx #0
  lda #<str_score
  sta bcd_write
  lda #>str_score
  sta bcd_write+1
  stz bcd_state
-
  lda bcd_score,x
  jsr bcd_to_string
  inx
  cpx #2
  bne +
  lda #%01000000
  tsb bcd_state
+
  cpx #3
  bne -

; A is BCD integer
; bcd_write points to string to write to
; bcd_state controlls aspects of conversion
;  - Bit 7 = Clear to replace 0's with spaces
;  - Bit 6 = Set if this is the final digits of a number
bcd_to_string:
  pha                       ; Save A
  .REPT 4
    lsr                     ; Shift high nibble to low nibble
  .ENDR
  bne +                     ; Handle 0 differently
  bit bcd_state             ; Zero fill?
  bmi +                     ; If bit set, write 0
  lda #ASC(' ')             ; Else write space
  bra @write_char0          ; Goto character write
+
  pha                       ; Save A
  lda #%10000000            ; Set bit 7
  tsb bcd_state             ; Set 0 fill bit
  pla                       ; Restore A
  ina                       ; Offset to correct character range
@write_char0
  sta (bcd_write)           ; Write digit
  inc bcd_write             ; Advance pointer
  lda bcd_write             ; Get pointer low
  bne +
  inc bcd_write+1           ; Carry into high byte
+
  pla                       ; Restore argument
  and #$0F                  ; Extract low nibble
  bne +                     ; Handle 0 differently
  bit bcd_state             ; Zero fill?
  bmi +                     ; If bit set, write 0
  bvs +                     ; If final digit, write 0
  lda #ASC(' ')             ; Else write space
  bra @write_char1          ; Goto character write
+
  pha                       ; Save A
  lda #%10000000            ; Set bit 7
  tsb bcd_state             ; Set 0 fill bit
  pla                       ; Restore A
  ina                       ; Offset to correct character range
@write_char1
  sta (bcd_write)           ; Write digit
  inc bcd_write             ; Advance pointer
  lda bcd_write             ; Get pointer low
  bne +
  inc bcd_write+1           ; Carry into high byte
+
  rts                       ; Return

.ENDS
