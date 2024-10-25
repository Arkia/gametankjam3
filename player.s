.DEFINE PLAYER_SPEED  $0040

.RAMSECTION "Player" BANK 0 SLOT 0
  player_x  dw
  player_y  dw
  player_vx dw
  player_vy dw
.ENDS

.SECTION "PlayerRoutines" BANK 1 SLOT 4
init_player:
  ldx #7              ; 8 bytes
-
  stz player_x,x      ; Clear byte
  dex                 ; Decrement X
  bpl -               ; Loop
  lda #60             ; Place player at center of screen
  sta player_x+1      ; Set player X
  sta player_y+1      ; Set player Y
  rts                 ; Return

update_player:
  lda p1_state        ; Load player 1 gamepad
  and #PAD_UP         ; Test dpad up
  beq +               ; Skip if button not held
  sec                 ; Setup subtraction
  lda player_y        ; Get player Y subpixel
  sbc #<PLAYER_SPEED  ; Subtract subpixel speed
  sta player_y        ; Set player Y subpixel
  lda player_y+1      ; Get player Y
  sbc #>PLAYER_SPEED  ; Subtract speed
  sta player_y+1      ; Set player Y
+
  lda p1_state        ; Load player 1 gamepad
  and #PAD_DOWN       ; Test dpad down
  beq +               ; Skip if button not held
  clc                 ; Setup addition
  lda player_y        ; Get player Y subpixel
  adc #<PLAYER_SPEED  ; Add subpixel speed
  sta player_y        ; Set player Y subpixel
  lda player_y+1      ; Get player Y
  adc #>PLAYER_SPEED  ; Add speed
  sta player_y+1      ; Set player Y
+
  lda p1_state        ; Load player 1 gamepad
  and #PAD_LEFT       ; Test dpad left
  beq +               ; Skip if button not held
  sec                 ; Setup subtraction
  lda player_x        ; Get player X subpixel
  sbc #<PLAYER_SPEED  ; Subtract subpixel speed
  sta player_x        ; Set player X subpixel
  lda player_x+1      ; Get player X
  sbc #>PLAYER_SPEED  ; Subtract speed
  sta player_x+1      ; Set player X
+
  lda p1_state        ; Load player 1 gamepad
  and #PAD_RIGHT      ; Test dpad right
  beq +               ; Skip if button not held
  clc                 ; Setup addition
  lda player_x        ; Get player X subpixel
  adc #<PLAYER_SPEED  ; Add subpixel speed
  sta player_x        ; Set player X subpixel
  lda player_x+1      ; Get player X
  adc #>PLAYER_SPEED  ; Add speed
  sta player_x+1      ; Set player X
+
  rts                 ; Return

draw_player:
  lda player_x+1      ; Get player X
  sta DMA_VX          ; Set blit X
  lda player_y+1      ; Get player Y
  sta DMA_VY          ; Set blit Y
  lda #0              ; Get frame X
  sta DMA_GX          ; Set blit source X
  lda #48             ; Frame Y
  sta DMA_GY          ; Set blit source Y
  lda #8              ; Sprite size
  sta DMA_WIDTH       ; Set blit width
  sta DMA_HEIGHT      ; Set blit height
  lda #1              ; Blit start command
  sta DMA_START       ; Draw sprite
  sta draw_status     ; Flag blitter active
  rts                 ; Return
.ENDS

