.DEFINE E_WAIT        $00
.DEFINE E_HOVER       $01
.DEFINE E_MOVE        $02
.DEFINE E_SINE        $03
.DEFINE E_FIRE        $04
.DEFINE E_AIM_FIRE    $05
.DEFINE E_ANIM        $06
.DEFINE E_TRIGGER     $07
.DEFINE E_SPAWN       $08
.DEFINE E_DELETE      $09

.DEFINE PLAYER_SHOT_MAX   16
.DEFINE PLAYER_SHOT_SPEED $0200

.DEFINE ENEMY_MAX 16

.RAMSECTION "ObjectArrays" BANK 0 SLOT "WRAM"
  pshot_x_lo    dsb PLAYER_SHOT_MAX
  pshot_x_hi    dsb PLAYER_SHOT_MAX
  pshot_y       dsb PLAYER_SHOT_MAX

  enemy_id      dsb ENEMY_MAX
  enemy_pc      dsb ENEMY_MAX
  enemy_x_lo    dsb ENEMY_MAX
  enemy_x_hi    dsb ENEMY_MAX
  enemy_y_lo    dsb ENEMY_MAX
  enemy_y_hi    dsb ENEMY_MAX
  enemy_vx_lo   dsb ENEMY_MAX
  enemy_vx_hi   dsb ENEMY_MAX
  enemy_vy_lo   dsb ENEMY_MAX
  enemy_vy_hi   dsb ENEMY_MAX
  enemy_state   dsb ENEMY_MAX
  enemy_timer   dsb ENEMY_MAX
  enemy_frame   dsb ENEMY_MAX
  enemy_anim    dsb ENEMY_MAX
  enemy_atimer  dsb ENEMY_MAX
  enemy_misc0   dsb ENEMY_MAX
  enemy_misc1   dsb ENEMY_MAX
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

; Create an object of type A and return index in X
spawn_object:
  ldx enemy_count             ; Get next enemy
  cpx #ENEMY_MAX              ; Check if slot is free
  bne +
  ldx #$FF                    ; Set X to -1
  rts                         ; If not, don't spawn an enemy
+
  inc enemy_count             ; Increment enemy counter
  sta enemy_id.w,x            ; Set enemy ID
  stz enemy_pc.w,x            ; Reset script PC
  stz enemy_x_lo.w,x          ; Clear subpixel X
  stz enemy_y_lo.w,x          ; Clear subpixel Y
  jmp enemy_next_state        ; Set initial state from script

spawn_test_enemy:
  ldx enemy_count             ; Get next enemy index
  cpx #ENEMY_MAX              ; Check if slot free
  bne +
  rts                         ; If not, do nothing
+
  inc enemy_count
  stz enemy_id.w,x
  stz enemy_pc.w,x
  stz enemy_x_lo.w,x
  stz enemy_y_lo.w,x
  stz enemy_frame.w,x
  stz enemy_state.w,x
  lda #128+16
  sta enemy_x_hi.w,x
  lda #16
  sta enemy_y_hi.w,x
  jmp enemy_next_state

enemy_next_state:
  ldy enemy_id.w,x            ; Get enemy ID
  lda enemy_script_lo.w,y     ; Get script base pointer
  sta temp                    ; Store into temp
  lda enemy_script_hi.w,y
  sta temp+1
  ldy enemy_pc.w,x            ; Load script PC
  lda (temp),y                ; Get state ID
  iny                         ; Advance PC
  sta enemy_state.w,x         ; Set next state
  lda (temp),y                ; Get state timer
  iny                         ; Advance PC
  sta enemy_timer.w,x         ; Set timer
  lda enemy_state.w,x         ; Get state ID
  phx                         ; Save X
  tax                         ; Transfer jump index to X
  lda e_param_jump_hi.w,x
  pha
  lda e_param_jump_lo.w,x
  pha
  rts
@hover
  plx
  lda enemy_y_hi.w,x
  sta enemy_misc0.w,x
  stz enemy_misc1.w,x
  bra @end
@move
  plx
  jsr enemy_param_vx
  jsr enemy_param_vy
  bra @end
@sine
  plx
  jsr enemy_param_vx
  lda enemy_y_hi.w,x
  sta enemy_misc0.w,x
  stz enemy_misc1.w,x
  bra @end
@fire
  plx
  jsr enemy_param_misc
  jsr enemy_param_vx
  jsr enemy_param_vy
  bra @end
@aimed
  plx
  jsr enemy_param_misc
  bra @end
@anim
  plx
  lda (temp),y
  iny
  sta enemy_anim.w,x
  stz enemy_frame.w,x
  stz enemy_atimer.w,x
  bra @end
@spawn
  plx
  lda (temp),y
  iny
  sta enemy_vx_lo.w,x
  lda (temp),y
  iny
  sta enemy_vy_lo.w,x
  bra @end
@wait
@delete
@trigger
  plx
@end
  tya
  sta enemy_pc.w,x            ; Update PC
  rts                         ; Return

e_param_jump_lo:
  .DB <(enemy_next_state@wait-1)
  .DB <(enemy_next_state@hover-1)
  .DB <(enemy_next_state@move-1)
  .DB <(enemy_next_state@sine-1)
  .DB <(enemy_next_state@fire-1)
  .DB <(enemy_next_state@aimed-1)
  .DB <(enemy_next_state@anim-1)
  .DB <(enemy_next_state@trigger-1)
  .DB <(enemy_next_state@spawn-1)
  .DB <(enemy_next_state@delete-1)

e_param_jump_hi:
  .DB >(enemy_next_state@wait-1)
  .DB >(enemy_next_state@hover-1)
  .DB >(enemy_next_state@move-1)
  .DB >(enemy_next_state@sine-1)
  .DB >(enemy_next_state@fire-1)
  .DB >(enemy_next_state@aimed-1)
  .DB >(enemy_next_state@anim-1)
  .DB >(enemy_next_state@trigger-1)
  .DB >(enemy_next_state@spawn-1)
  .DB >(enemy_next_state@delete-1)

enemy_param_misc:
  lda (temp),y
  iny
  sta enemy_misc0.w,x
  lda (temp),y
  iny
  sta enemy_misc1.w,x
  rts

enemy_param_vx:
  lda (temp),y                ; Parameter - VX
  iny                         ; Advance PC
  sta enemy_vx_lo.w,x         ; Store into subpixel VX
  stz enemy_vx_hi.w,x         ; Set VX to 0.PARAM
  cmp #0                      ; Test PARAM
  bpl +                       ; If PARAM was negative
  lda #$FF                    ; Sign extend VX
  sta enemy_vx_hi.w,x
+
  .REPT 4
    asl enemy_vx_lo.w,x       ; Shift left 4 times
    rol enemy_vx_hi.w,x
  .ENDR
  rts

enemy_param_vy:
  lda (temp),y                ; Parameter - VY
  iny                         ; Advance PC
  sta enemy_vy_lo.w,x         ; Store into subpixel VY
  stz enemy_vy_hi.w,x         ; Set VY to 0.PARAM
  cmp #0                      ; Test PARAM
  bpl +                       ; If PARAM was negative
  lda #$FF                    ; Sign extend VY
  sta enemy_vy_hi.w,x
+
  .REPT 4
    asl enemy_vy_lo.w,x       ; Shift left 4 times
    rol enemy_vy_hi.w,x
  .ENDR
  rts

remove_enemy:
  dec enemy_count             ; Decrement number of enemies
  ldy enemy_count             ; Index of last enemy in array
  lda enemy_state.w,y         ; Copy into this enemy slot
  sta enemy_state.w,x
  lda enemy_id.w,y
  sta enemy_id.w,x
  lda enemy_pc.w,y
  sta enemy_pc.w,x
  lda enemy_x_lo.w,y
  sta enemy_x_lo.w,x
  lda enemy_x_hi.w,y
  sta enemy_x_hi.w,x
  lda enemy_y_lo.w,y
  sta enemy_y_lo.w,x
  lda enemy_y_hi.w,y
  sta enemy_y_hi.w,x
  lda enemy_vx_lo.w,y
  sta enemy_vx_lo.w,x
  lda enemy_vx_hi.w,y
  sta enemy_vx_hi.w,x
  lda enemy_vy_lo.w,y
  sta enemy_vy_lo.w,x
  lda enemy_vy_hi.w,y
  sta enemy_vy_hi.w,x
  lda enemy_timer.w,y
  sta enemy_timer.w,x
  lda enemy_frame.w,y
  sta enemy_frame.w,x
  lda enemy_anim.w,y
  sta enemy_anim.w,x
  lda enemy_atimer.w,y
  sta enemy_atimer.w,x
  lda enemy_misc0.w,y
  sta enemy_misc0.w,x
  lda enemy_misc1.w,y
  sta enemy_misc1.w,x
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
  dec enemy_timer.w,x         ; Decrement state timer
  bne +                       ; If timer is zero
  jsr enemy_next_state        ; Next state
+
  ldy enemy_state.w,x         ; Get enemy state id
  jsr call_enemy_state        ; Call state function
  bcs +                       ; Destroy enemy if carry is clear
  jsr remove_enemy
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

e_wait:
  jmp enemy_pshot_collision

e_move_x:
  clc
  lda enemy_x_lo.w,x
  adc enemy_vx_lo.w,x
  sta enemy_x_lo.w,x
  lda enemy_x_hi.w,x
  adc enemy_vx_hi.w,x
  sta enemy_x_hi.w,x
  rts

e_move_y:
  clc
  lda enemy_y_lo.w,x
  adc enemy_vy_lo.w,x
  sta enemy_y_lo.w,x
  lda enemy_y_hi.w,x
  adc enemy_vy_hi.w,x
  sta enemy_y_hi.w,x
  rts

e_move:
  jsr e_move_x
  jsr e_move_y
  jmp enemy_pshot_collision

e_sine_y:
  ldy enemy_misc1.w,x
  iny
  cpy #48
  bne +
  ldy #0
+
  tya
  sta enemy_misc1.w,x
  clc
  lda e_sin_table.w,y
  adc enemy_misc0.w,x
  sta enemy_y_hi.w,x
  rts

e_sin_table:
  .DBSIN 0, 48, 360/48, 7.9, 0

e_hover:
  jsr e_sine_y
  jmp enemy_pshot_collision

e_sine:
  jsr e_move_x
  jsr e_sine_y
  jmp enemy_pshot_collision

e_delete:
  clc
  rts

enemy_func_lo:
  .DB <(e_wait-1)
  .DB <(e_hover-1)
  .DB <(e_move-1)
  .DB <(e_sine-1)
  .DB <(e_wait-1)
  .DB <(e_wait-1)
  .DB <(e_wait-1)
  .DB <(e_wait-1)
  .DB <(e_wait-1)
  .DB <(e_delete-1)

enemy_func_hi:
  .DB >(e_wait-1)
  .DB >(e_hover-1)
  .DB >(e_move-1)
  .DB >(e_sine-1)
  .DB >(e_wait-1)
  .DB >(e_wait-1)
  .DB >(e_wait-1)
  .DB >(e_wait-1)
  .DB >(e_wait-1)
  .DB >(e_delete-1)

e_dummy_script:
  .DB E_MOVE, 16+32, $F0, $00
  .DB E_HOVER, 48+48
  .DB E_SINE, 128, $F0
  .DB E_DELETE, 0

enemy_script_lo:
  .DB <e_dummy_script

enemy_script_hi:
  .DB >e_dummy_script

draw_enemies:
  ldx enemy_count             ; Get number of enemies
  dex                         ; Index of last enemy
  bpl +                       ; Check if no enemies
  rts                         ; If so, return
+
@loop
  ldy enemy_frame.w,x         ; Get sprite id
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

