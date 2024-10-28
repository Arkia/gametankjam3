.DEFINE PLAYER_SPEED  $0100
.DEFINE PLAYER_ANIM_SPEED 4
.DEFINE PLAYER_FRAME_COUNT 8
.DEFINE PLAYER_SHOT_DELAY 16
.DEFINE PLAYER_IFRAMES 120
.DEFINE PLAYER_DEAD_TIME 120

.RAMSECTION "Player" BANK 0 SLOT 0
  player_x      dw
  player_y      dw
  player_vx     dw
  player_vy     dw
  player_frame  db
  player_atimer db
  player_stimer db
  player_state  db
  player_timer  db
  player_iframe db
.ENDS

.SECTION "PlayerRoutines" BANK 1 SLOT 4
init_player:
  ldx #11              ; 11 bytes
-
  stz player_x,x      ; Clear byte
  dex                 ; Decrement X
  bpl -               ; Loop
  lda #60             ; Place player at center of screen
  sta player_x+1      ; Set player X
  sta player_y+1      ; Set player Y
  lda #PLAYER_ANIM_SPEED
  sta player_atimer
  stz player_state
  stz player_iframe
  rts                 ; Return

update_player:
  bit player_state          ; Get player state
  bpl ++                    ; If dead, no update
  dec player_timer          ; Decrement state timer
  beq +
  rts
+
  lda bcd_lives             ; Get player lives
  bne +
  lda #STATE_LOSE
  sta next_state
  rts
+
  sed                       ; Set decimal mode
  dec bcd_lives             ; Lives - 1
  cld                       ; Clear decimal mode
  jsr init_player           ; Reset player object
  lda #PLAYER_IFRAMES
  sta player_iframe
  ldy #3                    ; Respawn sfx
  ldx #3                    ; Channel 3
  jsr play_sound
  rts
++
  lda player_iframe         ; Get iframes
  beq +                     ; If zero, no iframe update
  dec player_iframe         ; Decrement iframes
+
  dec player_atimer         ; Decrement animation timer
  bne @no_frame_inc         ; If not zero, don't increment frame
  lda #PLAYER_ANIM_SPEED    ; Load animation delay
  sta player_atimer         ; Reset animation timer
  lda player_frame          ; Get current frame
  ina                       ; Increment
  cmp #PLAYER_FRAME_COUNT   ; Check animation bound
  bne +                     ; If at end of animation
  lda #0                    ; Reset to frame 0
+
  sta player_frame          ; Set current frame
@no_frame_inc
  lda player_stimer         ; Get shot delay timer
  beq +                     ; If not zero
  dec player_stimer         ; Decrement shot delay timer
+
  lda player_iframe   ; Check for IFrames
  bne @do_input       ; If IFrames, skip collision checks
  ldx enemy_count     ; Load number of enemies
  beq @check_eshots   ; Skip if list is empty
  lda player_x+1      ; Get X position
  ina                 ; Add 2
  ina
  sta a_x             ; Set A.X
  lda player_y+1      ; Get Y position
  ina                 ; Add 1
  sta a_y             ; Set A.Y
  lda #5              ; Combined AABB sizes
  sta size_x
  sta size_y
  dex                 ; Index last enemy
-
  lda enemy_x_hi.w,x  ; Get enemy X
  sta b_x             ; Set B.X
  lda enemy_y_hi.w,x  ; Get enemy Y
  sta b_y             ; Set B.Y
  jsr test_collision  ; Check collision
  bcs +               ; If no collision, next enemy
  lda #%10000000
  sta player_state    ; Set player to dead
  lda #PLAYER_DEAD_TIME
  sta player_timer
  ldy #2              ; Death sfx
  ldx #2              ; Channel 2
  jsr play_sound
  rts                 ; No more updates
+
  dex                 ; Next enemy
  bpl -               ; Loop
@check_eshots
  ldx eshot_count     ; Load number of enemy shots
  beq @do_input       ; Skip if list is empty
  lda player_x+1      ; Get X position
  ina                 ; Add 4
  ina
  ina
  ina
  sta a_x             ; Set A.X
  lda player_y+1      ; Get Y position
  ina                 ; Add 3
  ina
  ina
  sta a_y             ; Set A.Y
  lda #3              ; Combined AABB size
  sta size_x
  sta size_y
  dex                 ; Last enemy index
-
  lda eshot_x_hi.w,x  ; Get shot X
  sta b_x             ; Set B.X
  lda eshot_y_hi.w,x  ; Get shot Y
  sta b_y             ; Set B.Y
  jsr test_collision  ; Check for collision
  bcs +               ; If no collision, next enemy
  inc player_state    ; Set player to dead
  lda #PLAYER_DEAD_TIME
  sta player_timer
  ldy #2              ; Death sfx
  ldx #2              ; Channel 2
  jsr play_sound
  rts                 ; No more updates
+
  dex                 ; Next enemy
  bpl -               ; Loop
@do_input
  bit player_state    ; Check player state
  bvc +               ; If no input state
  rts                 ; End update
+
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
  cmp #16             ; Check if crossed top edge
  bcs +
  lda #16             ; Top edge
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
  cmp #128-24         ; Check if crossed bottom edge
  bcc +
  lda #128-24         ; Bottom edge
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
  bpl +               ; If crossed left edge of screen
  stz player_x+1      ; Snap to left edge of screen
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
  cmp #128-9          ; Check if crossed right edge
  bcc +
  lda #128-9          ; Right edge
  sta player_x+1      ; Set player X
+
  lda p1_state        ; Get player 1 pressed buttons
  and #PAD_ABC        ; Test face buttons
  beq +               ; Skip if not pressed this frame
  lda player_stimer   ; Get shot delay timer
  bne +               ; If not zero, skip
  lda pshot_count     ; Get shot count
  cmp #PLAYER_SHOT_MAX ; Check for free shots
  beq +               ; If shot array full, don't fire
  inc pshot_count     ; Increment shot count
  tax                 ; Transfer shot index to X
  lda player_x+1      ; Get player X
  clc                 ; Setup addition
  adc #8              ; 8 pixels to the right
  sta pshot_x_hi.w,x  ; Set shot X
  stz pshot_x_lo.w,x  ; Clear shot subpixel X
  lda player_y+1      ; Get player Y
  clc                 ; Setup addition
  adc #3              ; 3 pixels down
  sta pshot_y.w,x     ; Set shot Y
  lda #PLAYER_SHOT_DELAY
  sta player_stimer
  ldy #0              ; Sound ID 0
  ldx #0              ; Channel 0
  jsr play_sound      ; Play SFX
+
  rts                 ; Return

draw_player:
  lda player_state    ; Get current player state
  bpl +               ; If dead, don't draw
  rts
+
  lda player_iframe   ; Get iframe timer
  and #%00000010      ; Flash on bit 1
  beq +
  rts
+
  lda player_x+1      ; Get player X
  sta DMA_VX          ; Set blit X
  lda player_y+1      ; Get player Y
  sta DMA_VY          ; Set blit Y
  ldx player_frame    ; Get current frame
  lda player_frame_gx.w,x
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

player_frame_gx:
  .DB 0, 8, 16, 24, 32, 40, 48, 56

.ENDS

