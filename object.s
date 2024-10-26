.DEFINE PLAYER_SHOT_MAX   16
.DEFINE PLAYER_SHOT_SPEED $0200

.DEFINE ENEMY_MAX 16

.RAMSECTION "ObjectArrays" BANK 0 SLOT "WRAM"
  pshot_x_lo    dsb PLAYER_SHOT_MAX
  pshot_x_hi    dsb PLAYER_SHOT_MAX
  pshot_y       dsb PLAYER_SHOT_MAX

  enemy_x_lo    dsb ENEMY_MAX
  enemy_x_hi    dsb ENEMY_MAX
  enemy_y_lo    dsb ENEMY_MAX
  enemy_y_hi    dsb ENEMY_MAX
  enemy_state   dsb ENEMY_MAX
  enemy_timer   dsb ENEMY_MAX
  enemy_sprite  dsb ENEMY_MAX
.ENDS

.RAMSECTION "ObjectCounts" BANK 0 SLOT "ZeroPage"
  pshot_count   db
  enemy_count   db
.ENDS

.RAMSECTION "CollisionVars" BANK 0 SLOT "ZeroPage"
  a_x           db
  a_y           db
  b_x           db
  b_y           db
  size_x        db
  size_y        db
.ENDS

.SECTION "ObjectRoutines" BANK 1 SLOT "FixedROM"

init_objects:
  stz pshot_count
  stz enemy_count
  rts

spawn_test_enemy:
  ldx enemy_count             ; Get next enemy index
  cpx #ENEMY_MAX              ; Check if slot free
  bne +
  rts                         ; If not, do nothing
+
  inc enemy_count
  stz enemy_x_lo.w,x
  stz enemy_y_lo.w,x
  stz enemy_sprite.w,x
  stz enemy_state.w,x
  lda #112
  sta enemy_x_hi.w,x
  lda #16
  sta enemy_y_hi.w,x
  rts

update_enemies:
  ldx #0                      ; Start at index 0
@loop
  cpx enemy_count             ; Compare to number of enemies
  bcc +                       ; If index is greater than enemy count
  rts                         ; Return
+
  bne +                       ; If index is equal to enemy count
  rts                         ; Return
+
  ldy enemy_state.w,x         ; Get enemy state id
  jsr call_enemy_state        ; Call state function
  bcs +                       ; Destroy enemy if carry is clear
  dec enemy_count             ; Decrement number of enemies
  ldy enemy_count             ; Index of last enemy in array
  lda enemy_state.w,y         ; Copy into this enemy slot
  sta enemy_state.w,x
  lda enemy_x_lo.w,y
  sta enemy_x_lo.w,x
  lda enemy_x_hi.w,y
  sta enemy_x_hi.w,x
  lda enemy_y_lo.w,y
  sta enemy_y_lo.w,x
  lda enemy_y_hi.w,y
  sta enemy_y_hi.w,x
  lda enemy_timer.w,y
  sta enemy_timer.w,x
  lda enemy_sprite.w,y
  sta enemy_sprite.w,x
  bra @loop                   ; Loop
+
  inx                         ; Next enemy
  bra @loop                   ; Loop

call_enemy_state:
  lda enemy_func_hi.w,y       ; Get enemy routine high
  pha                         ; Push onto stack
  lda enemy_func_lo.w,y       ; Get enemy routine low
  pha                         ; Push onto stack
  rts                         ; Jump to routine

enemy_pshot_collision:
  lda enemy_x_hi.w,x          ; Get enemy X
  ina                         ; Offset
  ina
  sta b_x                     ; Set B.X
  lda enemy_y_hi.w,x          ; Get enemy Y
  ina                         ; Offset
  ina
  sta b_y                     ; Set B.Y
  lda #4+2                    ; Combined sizes of enemy and pshot
  sta size_x                  ; Set aabb widths
  sta size_y                  ; Set aabb heights
  ldy #0                      ; Set Y to first Player Shot
-
  cpy pshot_count             ; Test with player shot count
  bcc +                       ; If pshot index is greater than count
  bra @no_collision           ; End of list
+
  bne +                       ; If pshot index is equal to count
  bra @no_collision           ; End of list
+
  lda pshot_x_hi.w,y          ; Get player shot X
  sta a_x                     ; Set A.X
  lda pshot_y.w,y             ; Get player shot Y
  sta a_y                     ; Set A.Y
  jsr test_collision          ; Check collision
  bcs +                       ; Skip if no collision
  phx                         ; Save X
  tya                         ; Move pshot index to A
  tax                         ; Move to X
  jsr remove_pshot            ; Delete shot collided with
  plx                         ; Restore X
  clc                         ; Flag collision
  rts                         ; Return
+
@no_collision
  sec                         ; Flag no collision
  rts                         ; Return

e_dummy_state:
  inc enemy_y_hi.w,x
  jmp enemy_pshot_collision

enemy_func_lo:
  .DB <(e_dummy_state-1)

enemy_func_hi:
  .DB >(e_dummy_state-1)

draw_enemies:
  ldx enemy_count             ; Get number of enemies
  dex                         ; Index of last enemy
  bpl +                       ; Check if no enemies
  rts                         ; If so, return
+
@loop
  ldy enemy_sprite.w,x        ; Get sprite id
  lda e_sprite_gx.w,y         ; Get sprite GX
  sta DMA_GX                  ; Set blit GX
  lda e_sprite_gy.w,y         ; Get sprite GY
  sta DMA_GY                  ; Set blit GY
  lda e_sprite_w.w,y          ; Get sprite width
  sta DMA_WIDTH               ; Set blit width
  lda e_sprite_h.w,y          ; Get sprite height
  sta DMA_HEIGHT              ; Set blit height
  lda enemy_x_hi.w,x          ; Get enemy X position
  sta DMA_VX                  ; Set blit X
  lda enemy_y_hi.w,x          ; Get enemy Y position
  sta DMA_VY                  ; Set blit Y
  lda #1                      ; Blit start command
  sta DMA_START               ; Do blit
  wai                         ; Wait for blitter
  dex                         ; Next enemy
  bpl @loop                   ; Loop
  rts

e_sprite_gx:
  .DB 0

e_sprite_gy:
  .DB 40

e_sprite_w:
  .DB 9

e_sprite_h:
  .DB 9

remove_pshot:
  dec pshot_count             ; Decrement shot count
  ldy pshot_count             ; Load shot count as index
  lda pshot_x_lo.w,y          ; Swap current shot with last shot
  sta pshot_x_lo.w,x
  lda pshot_x_hi.w,y
  sta pshot_x_hi.w,x
  lda pshot_y.w,y
  sta pshot_y.w,x
  rts

update_pshots:
  ldx #0                      ; Start at index 0
@loop
  cpx pshot_count             ; Compare to number of shots
  bcc +                       ; If index is greater than shot count
  rts                         ; Return
+
  bne +                       ; If index is equal to shot count
  rts                         ; Return
+
  clc                         ; Setup addition
  lda #<PLAYER_SHOT_SPEED     ; Get shot subpixel speed
  adc pshot_x_lo.w,x          ; Add to subpixel X
  sta pshot_x_lo.w,x          ; Update subpixel X
  lda #>PLAYER_SHOT_SPEED     ; Set shot speed
  adc pshot_x_hi.w,x          ; Add to X
  sta pshot_x_hi.w,x          ; Update X
  bpl +                       ; Test if off screen
  jsr remove_pshot            ; Delete shot
  bra @loop                   ; Loop
+
  inx                         ; Next shot
  bra @loop                   ; Loop

draw_pshots:
  ldx pshot_count             ; Get number of Player Shots
  dex                         ; Move to last index
  bpl +                       ; If count is zero
  rts                         ; Return early
+
  lda #6                      ; Shot sprite width
  sta DMA_WIDTH               ; Set blit width
  lda #3                      ; Shot sprite height
  sta DMA_HEIGHT              ; Set blit height
  lda #64                     ; Shot sprite GX
  sta DMA_GX                  ; Set blit GX
  lda #48                     ; Shot sprite GY
  sta DMA_GY
-
  lda pshot_x_hi.w,x          ; Get shot X position
  sta DMA_VX                  ; Set blit X
  lda pshot_y.w,x             ; Get shot Y position
  sta DMA_VY                  ; Set blit Y
  lda #1                      ; Blit start command
  sta DMA_START               ; Do blit
  wai                         ; Wait for blitter
  dex                         ; Next shot index
  bpl -                       ; Loop
  rts                         ; Return

; Sets C if no collision between objects where
; a_x, a_y is the center of object A and
; b_x, b_y is an offset center of object B
; size_x, size_y are the combined half sizes of the aabb's
test_collision:
  sec                         ; Setup subtraction
  lda a_x                     ; Load A.X
  sbc b_x                     ; Subtract B.X
  bpl +                       ; Take absolute value if negative
  eor #$FF                    ; Invert
  ina                         ; Add 1 for two's compliment
+
  cmp size_x                  ; Test against combined aabb half widths
  bcc +                       ; If dx is greater than size x
  rts                         ; No collision
+
  sec                         ; Setup subtraction
  lda a_y                     ; Load A.Y
  sbc b_y                     ; Subtract B.Y
  bpl +                       ; Take absolute value if negative
  eor #$FF                    ; Invert
  ina                         ; Add 1 for two's compliment
+
  cmp size_y                  ; Test against combined aabb half heights
  rts                         ; Return result

.ENDS
