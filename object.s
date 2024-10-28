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

.DEFINE ENEMY_SHOT_MAX    32

.DEFINE EFFECT_MAX 16

.DEFINE ENEMY_MAX 16

.RAMSECTION "ObjectArrays" BANK 0 SLOT "WRAM"
  pshot_x_lo    dsb PLAYER_SHOT_MAX
  pshot_x_hi    dsb PLAYER_SHOT_MAX
  pshot_y       dsb PLAYER_SHOT_MAX

  eshot_x_lo    dsb ENEMY_SHOT_MAX
  eshot_x_hi    dsb ENEMY_SHOT_MAX
  eshot_y_lo    dsb ENEMY_SHOT_MAX
  eshot_y_hi    dsb ENEMY_SHOT_MAX
  eshot_vx_lo   dsb ENEMY_SHOT_MAX
  eshot_vx_hi   dsb ENEMY_SHOT_MAX
  eshot_vy_lo   dsb ENEMY_SHOT_MAX
  eshot_vy_hi   dsb ENEMY_SHOT_MAX

  effect_x      dsb EFFECT_MAX
  effect_y      dsb EFFECT_MAX
  effect_atimer dsb EFFECT_MAX
  effect_anim   dsb EFFECT_MAX
  effect_frame  dsb EFFECT_MAX
  effect_sprite dsb EFFECT_MAX

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
  enemy_sprite  dsb ENEMY_MAX
  enemy_frame   dsb ENEMY_MAX
  enemy_anim    dsb ENEMY_MAX
  enemy_atimer  dsb ENEMY_MAX
  enemy_misc0   dsb ENEMY_MAX
  enemy_misc1   dsb ENEMY_MAX
.ENDS

.RAMSECTION "ObjectCounts" BANK 0 SLOT "ZeroPage"
  pshot_count   db
  eshot_count   db
  effect_count  db
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
  stz eshot_count
  stz enemy_count
  stz effect_count
  rts

init_effect_anim:
  ldy effect_anim.w,x         ; Get animation ID
  lda anim_speed.w,y          ; Read animation speed
  sta effect_atimer.w,x       ; Set timer
  stz effect_frame.w,x        ; Start at frame 0
  lda anim_frame0.w,y         ; Get first sprite
  sta effect_sprite.w,x       ; Set sprite
  rts

remove_effect:
  dec effect_count            ; Update effect count
  ldy effect_count            ; Index last effect in Y
  lda effect_x.w,y
  sta effect_x.w,x
  lda effect_y.w,y
  sta effect_y.w,x
  lda effect_anim.w,y
  sta effect_anim.w,x
  lda effect_atimer.w,y
  sta effect_atimer.w,x
  lda effect_frame.w,y
  sta effect_frame.w,x
  lda effect_sprite.w,y
  sta effect_sprite.w,x
  rts

update_effects:
  ldx #0                      ; Start at index 0
-
  cpx effect_count            ; End of effect list?
  bne +
  rts
+
  dec effect_atimer.w,x       ; Upate animation timer
  bne @next_effect
  lda effect_frame.w,x        ; Get current frame
  ldy effect_anim.w,x         ; Get animation ID
  ina                         ; Next frame
  cmp anim_len,y              ; End of animation?
  bne +
  jsr remove_effect           ; Delete this effect
  bra -                       ; Loop
+
  sta effect_frame.w,x        ; Update frame
  clc                         ; Setup addition
  adc anim_frame0.w,y         ; Calculate sprite index
  sta effect_sprite.w,x       ; Update sprite
  lda anim_speed.w,y          ; Get animation speed
  sta effect_atimer.w,x       ; Reset animation timer
@next_effect
  inx                         ; Next effect
  bra -                       ; Loop

draw_effects:
  ldx effect_count            ; Get effect count
  bne +
  rts                         ; Return if no effects
+
  dex                         ; Move to last effect index
-
  lda effect_x.w,x            ; Get X position
  sta DMA_VX                  ; Set blit VX
  lda effect_y.w,x            ; Get Y position
  sta DMA_VY                  ; Set blit VY
  ldy effect_sprite.w,x       ; Get sprite index
  lda e_sprite_gx.w,y         ; Get sprite GX
  sta DMA_GX                  ; Set blit GX
  lda e_sprite_gy.w,y         ; Get sprite GY
  sta DMA_GY                  ; Set blit GY
  lda e_sprite_w.w,y          ; Get sprite width
  sta DMA_WIDTH               ; Set blit width
  lda e_sprite_h.w,y          ; Get sprite height
  sta DMA_HEIGHT              ; Set blit height
  lda #1
  sta DMA_START
  wai
  dex
  bpl -
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
  lda #1
  sta enemy_atimer.w,x
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
  dec enemy_atimer.w,x        ; Decrement animation timer
  bne ++                      ; If timer is zero
  ldy enemy_anim.w,x          ; Get animation ID
  lda anim_speed.w,y          ; Get animation delay
  sta enemy_atimer.w,x        ; Reset timer
  lda enemy_frame.w,x         ; Get current frame
  ina                         ; Increment
  cmp anim_len.w,y            ; End of animation?
  bne +
  lda #0                      ; Reset to frame 0
+
  sta enemy_frame.w,x         ; Set frame
  clc                         ; Setup addition
  adc anim_frame0.w,y         ; Calculate sprite ID
  sta enemy_sprite.w,x         ; Set sprite
++
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
  clc                         ; Setup addition
  lda enemy_x_hi.w,x          ; Get enemy X
  adc #4                      ; Move to center
  sta a_x                     ; Set A.X
  clc                         ; Setup addition
  lda enemy_y_hi.w,x          ; Get enemy Y
  adc #4                      ; Move to center
  sta a_y                     ; Set A.Y
  lda #6                      ; Combined sizes of enemy and pshot
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
  ina
  ina
  sta b_x                     ; Set B.X
  lda pshot_y.w,y             ; Get player shot Y
  ina
  ina
  sta b_y                     ; Set B.Y
  jsr test_collision          ; Check collision
  bcs @next_shot              ; Skip if no collision
@collision
  phx                         ; Save X
  tya                         ; Move pshot index to A
  tax                         ; Move to X
  jsr remove_pshot            ; Delete shot collided with
  ldy #2                      ; Death SFX
  ldx #2                      ; Channel 2
  jsr play_sound              ; Play sound
  plx                         ; Restore X
  ldy effect_count            ; Get next effect index
  cpy #EFFECT_MAX             ; Effect list full?
  beq @no_effect              ; If so, don't spawn explosion
  inc effect_count            ; Add new effect
  sec                         ; Setup subtraction
  lda enemy_x_hi.w,x          ; Get X position
  sbc #4                      ; Subtract 4
  sta effect_x.w,y            ; Set effect X
  sec                         ; Setup subtraction
  lda enemy_y_hi.w,x          ; Get Y position
  sbc #4                      ; Subtract 4
  sta effect_y.w,y            ; Set effect Y
  lda #7                      ; Explosion animation
  sta effect_anim.w,y         ; Set effect animation
  phx
  tya
  tax
  jsr init_effect_anim
  plx
@no_effect
  ldy enemy_id.w,x            ; Get enemy ID
  lda e_score_value.w,y       ; Get points
  sed                         ; Set decimal
  clc                         ; Setup addition
  adc bcd_score+1             ; Add to score hundreds
  sta bcd_score+1             ; Update score hundreds
  bcc +
  lda bcd_score               ; Get score ten thousands
  adc #0                      ; Add 1
  sta bcd_score               ; Update score ten thousands
  lda bcd_lives               ; Get lives
  cmp $99                     ; Max lives?
  beq +
  clc                         ; Setup addition
  adc #1                      ; Add 1 life
  sta bcd_lives               ; Update lives
  phx                         ; Save enemy index
  ldy #4                      ; Gain life sfx
  ldx #4                      ; Channel 4
  jsr play_sound
  plx                         ; Restore X
+
  cld                         ; Clear decimal
  clc                         ; Flag collision
  rts                         ; Return
@next_shot
  iny                         ; Next shot index
  bra -                       ; Loop
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

e_fire:
  ldy eshot_count                 ; Get next enemy shot
  cpy #ENEMY_SHOT_MAX             ; Shot list empty?
  beq @end                        ; If yes, skip this state
  inc eshot_count                 ; Increment shot counter
  clc                             ; Setup addition
  lda enemy_x_hi.w,x              ; Get X position
  adc enemy_misc0.w,x             ; Add shot offset
  sta eshot_x_hi.w,y              ; Set shot X
  lda #0
  sta eshot_x_lo.w,y              ; Clear shot subpixel X
  clc                             ; Setup addition
  lda enemy_y_hi.w,x              ; Get Y position
  adc enemy_misc1.w,x             ; Add shot offset
  sta eshot_y_hi.w,y              ; Set shot Y
  lda #0
  sta eshot_y_lo.w,y              ; Clear shot subpixel Y
  lda enemy_vx_lo.w,x             ; Get subpixel VX
  sta eshot_vx_lo.w,y             ; Set shot subpixel VX
  lda enemy_vx_hi.w,x             ; Get VX
  sta eshot_vx_hi.w,y             ; Set shot VX
  lda enemy_vy_lo.w,x             ; Get subpixel VY
  sta eshot_vy_lo.w,y             ; Set shot subpixel VY
  lda enemy_vy_hi.w,x             ; Get VY
  sta eshot_vy_hi.w,y             ; Set shot VY
  phx                             ; Save enemy index
  ldx #1                          ; Sound channel 1
  ldy #1                          ; Enemy Shoot sfx
  jsr play_sound                  ; Play sound
  plx                             ; Restore enemy index
@end
  jsr enemy_next_state            ; Next state
  ldy enemy_state.w,x             ; Get state ID
  jmp call_enemy_state            ; Call state update

e_anim:
  jsr enemy_next_state
  ldy enemy_state.w,x
  jmp call_enemy_state

e_delete:
  clc
  rts

enemy_func_lo:
  .DB <(e_wait-1)
  .DB <(e_hover-1)
  .DB <(e_move-1)
  .DB <(e_sine-1)
  .DB <(e_fire-1)
  .DB <(e_wait-1)
  .DB <(e_anim-1)
  .DB <(e_wait-1)
  .DB <(e_wait-1)
  .DB <(e_delete-1)

enemy_func_hi:
  .DB >(e_wait-1)
  .DB >(e_hover-1)
  .DB >(e_move-1)
  .DB >(e_sine-1)
  .DB >(e_fire-1)
  .DB >(e_wait-1)
  .DB >(e_anim-1)
  .DB >(e_wait-1)
  .DB >(e_wait-1)
  .DB >(e_delete-1)

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

remove_eshot:
  dec eshot_count
  ldy eshot_count
  lda eshot_x_lo.w,y
  sta eshot_x_lo.w,x
  lda eshot_x_hi.w,y
  sta eshot_x_hi.w,x
  lda eshot_y_lo.w,y
  sta eshot_y_lo.w,x
  lda eshot_y_hi.w,y
  sta eshot_y_hi.w,x
  lda eshot_vx_lo.w,y
  sta eshot_vx_lo.w,x
  lda eshot_vx_hi.w,y
  sta eshot_vx_hi.w,x
  lda eshot_vy_lo.w,y
  sta eshot_vy_lo.w,x
  lda eshot_vy_hi.w,y
  sta eshot_vy_hi.w,x

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

update_eshots:
  ldx #0                      ; Start at index 0
@loop
  cpx eshot_count             ; End of list?
  bcc +
  rts
+
  bne +
  rts
+
  clc                         ; Setup addition
  lda eshot_x_lo.w,x          ; Get subpixel X
  adc eshot_vx_lo.w,x         ; Add subpixel VX
  sta eshot_x_lo.w,x          ; Update subpixel X
  lda eshot_x_hi.w,x          ; Get X
  adc eshot_vx_hi.w,x         ; Add VX
  sta eshot_x_hi.w,x          ; Update X
  clc                         ; Setup addition
  lda eshot_y_lo.w,x          ; Get subpixel Y
  adc eshot_vy_lo.w,x         ; Add subpixel VY
  sta eshot_y_lo.w,x          ; Update subpixel Y
  lda eshot_y_hi.w,x          ; Get Y
  adc eshot_vy_hi.w,x         ; Add VY
  sta eshot_y_hi.w,x          ; Update Y
  lda eshot_x_hi.w,x          ; Get X position
  cmp #128                    ; Test right edge
  bcc @test_y
  cmp #-4                     ; Test left edge
  bcc @delete
@test_y
  lda eshot_y_hi.w,x          ; Get Y position
  cmp #128                    ; Test bottom edge
  bcc @next_shot
  cmp #-4                     ; Test top edge
  bcs @next_shot
@delete
  jsr remove_eshot            ; Delete this shot
  bra @loop                   ; Loop
@next_shot
  inx                         ; Next index
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

draw_eshots:
  ldx eshot_count             ; Get number of Enemy Shots
  dex                         ; Move to last index
  bpl +
  rts
+
  lda #4                      ; Shot sprite size
  sta DMA_WIDTH               ; Set blit width
  sta DMA_HEIGHT              ; Set blit height
  lda #64                     ; Shot sprite GX
  sta DMA_GX                  ; Set blit GX
  lda #51                     ; Shot sprite GY
  sta DMA_GY                  ; Set blit GY
-
  lda eshot_x_hi.w,x          ; Get shot X
  sta DMA_VX                  ; Set blit X
  lda eshot_y_hi.w,x          ; Get shot Y
  sta DMA_VY                  ; Set blit Y
  lda #1
  sta DMA_START
  wai
  dex
  bpl -
  rts

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

.SECTION "ObjectData" BANK 0 SLOT "BankROM"
e_straight_l:
  .DB E_ANIM, 1, 0
  .DB E_MOVE, 255, $F0, $00
  .DB E_DELETE, 0

e_straight_lu:
  .DB E_ANIM, 1, 0
  .DB E_MOVE, 255, $F0, $FC
  .DB E_DELETE, 0

e_straight_ld:
  .DB E_ANIM, 1, 0
  .DB E_MOVE, 255, $F0, $04
  .DB E_DELETE, 0

e_star_3_seq:
  .DB E_ANIM, 1, 1
  .DB E_MOVE, 48, $F0, $00
  .DB E_WAIT, 60
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_WAIT, 30
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_WAIT, 30
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_WAIT, 30
  .DB E_MOVE, 128, $F0, $00
  .DB E_DELETE, 0

e_star_3_way:
  .DB E_ANIM, 1, 1
  .DB E_MOVE, 48, $F0, $00
  .DB E_WAIT, 60
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_FIRE, 1, 2, 2, $EE, $EE
  .DB E_FIRE, 1, 2, 2, $EE, $12
  .DB E_WAIT, 30,
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_FIRE, 1, 2, 2, $EE, $EE
  .DB E_FIRE, 1, 2, 2, $EE, $12
  .DB E_WAIT, 30,
  .DB E_MOVE, 128, $F0, $00
  .DB E_DELETE, 0

e_star_5_way:
  .DB E_ANIM, 1, 1
  .DB E_MOVE, 48, $F0, $00
  .DB E_WAIT, 60
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_FIRE, 1, 2, 2, $EB, $F8
  .DB E_FIRE, 1, 2, 2, $EE, $EE
  .DB E_FIRE, 1, 2, 2, $EB, $08
  .DB E_FIRE, 1, 2, 2, $EE, $12
  .DB E_WAIT, 30,
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_FIRE, 1, 2, 2, $EB, $F8
  .DB E_FIRE, 1, 2, 2, $EE, $EE
  .DB E_FIRE, 1, 2, 2, $EB, $08
  .DB E_FIRE, 1, 2, 2, $EE, $12
  .DB E_WAIT, 30,
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_FIRE, 1, 2, 2, $EB, $F8
  .DB E_FIRE, 1, 2, 2, $EE, $EE
  .DB E_FIRE, 1, 2, 2, $EB, $08
  .DB E_FIRE, 1, 2, 2, $EE, $12
  .DB E_WAIT, 30,
  .DB E_MOVE, 128, $F0, $00
  .DB E_DELETE, 0

e_sine_slow:
  .DB E_ANIM, 1, 2
  .DB E_SINE, 255, $F4
  .DB E_DELETE, 0

e_sine_fast:
  .DB E_ANIM, 1, 2
  .DB E_SINE, 255, $E8
  .DB E_DELETE, 0

e_sine_slow_fire_1:
  .DB E_ANIM, 1, 2
  .DB E_SINE, 48, $F4
  .DB E_FIRE, 1, -4, 2, $E0, $00
  .DB E_SINE, 48, $F4
  .DB E_FIRE, 1, -4, 2, $E0, $00
  .DB E_SINE, 48, $F4
  .DB E_FIRE, 1, -4, 2, $E0, $00
  .DB E_SINE, 80, $F4
  .DB E_DELETE, 0

e_sine_slow_fire_3:
  .DB E_ANIM, 1, 2
  .DB E_SINE, 48, $F4
  .DB E_FIRE, 1, 2, 2, $E0, $00
  .DB E_FIRE, 1, 2, 2, $EC, $EC
  .DB E_FIRE, 1, 2, 2, $EC, $12
  .DB E_SINE, 48, $F4
  .DB E_FIRE, 1, 2, 2, $E0, $00
  .DB E_FIRE, 1, 2, 2, $EC, $EC
  .DB E_FIRE, 1, 2, 2, $EC, $14
  .DB E_SINE, 48, $F4
  .DB E_FIRE, 1, 2, 2, $E0, $00
  .DB E_FIRE, 1, 2, 2, $EC, $EC
  .DB E_FIRE, 1, 2, 2, $EC, $12
  .DB E_SINE, 80, $F4
  .DB E_DELETE, 0

e_spike_down_slow:
  .DB E_ANIM, 1, 3
  .DB E_MOVE, 255, $00, $08
  .DB E_MOVE, 32, $00, $08
  .DB E_DELETE, 0

e_spike_down:
  .DB E_ANIM, 1, 3
  .DB E_MOVE, 128, $00, $10
  .DB E_DELETE, 0

e_spike_down_fast:
  .DB E_ANIM, 1, 3
  .DB E_MOVE, 96, $00, $18
  .DB E_DELETE, 0

e_spike_up_slow:
  .DB E_ANIM, 1, 4
  .DB E_MOVE, 255, $00, $F8
  .DB E_MOVE, 32, $00, $F8
  .DB E_DELETE, 0

e_spike_up:
  .DB E_ANIM, 1, 4
  .DB E_MOVE, 128, $00, $F0
  .DB E_DELETE, 0

e_spike_up_fast:
  .DB E_ANIM, 1, 4
  .DB E_MOVE, 96, $00, $E8
  .DB E_DELETE, 0

e_bomb_left:
  .DB E_ANIM, 1, 5
  .DB E_MOVE, 40, $F0, $00
  .DB E_ANIM, 1, 6
  .DB E_WAIT, 90
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_FIRE, 1, 2, 2, $00, $E8
  .DB E_FIRE, 1, 2, 2, $18, $00
  .DB E_FIRE, 1, 2, 2, $00, $18
  .DB E_FIRE, 1, 2, 2, $EE, $EE
  .DB E_FIRE, 1, 2, 2, $EE, $12
  .DB E_FIRE, 1, 2, 2, $12, $12
  .DB E_FIRE, 1, 2, 2, $12, $EE
  .DB E_DELETE, 0

e_bomb_down:
  .DB E_ANIM, 1, 5
  .DB E_MOVE, 40, $00, $10
  .DB E_ANIM, 1, 6
  .DB E_WAIT, 90
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_FIRE, 1, 2, 2, $00, $E8
  .DB E_FIRE, 1, 2, 2, $18, $00
  .DB E_FIRE, 1, 2, 2, $00, $18
  .DB E_FIRE, 1, 2, 2, $EE, $EE
  .DB E_FIRE, 1, 2, 2, $EE, $12
  .DB E_FIRE, 1, 2, 2, $12, $12
  .DB E_FIRE, 1, 2, 2, $12, $EE
  .DB E_DELETE, 0

e_bomb_up:
  .DB E_ANIM, 1, 5
  .DB E_MOVE, 40, $00, $F0
  .DB E_ANIM, 1, 6
  .DB E_WAIT, 90
  .DB E_FIRE, 1, 2, 2, $E8, $00
  .DB E_FIRE, 1, 2, 2, $00, $E8
  .DB E_FIRE, 1, 2, 2, $18, $00
  .DB E_FIRE, 1, 2, 2, $00, $18
  .DB E_FIRE, 1, 2, 2, $EE, $EE
  .DB E_FIRE, 1, 2, 2, $EE, $12
  .DB E_FIRE, 1, 2, 2, $12, $12
  .DB E_FIRE, 1, 2, 2, $12, $EE
  .DB E_DELETE, 0

e_null:
  .DB E_DELETE, 0

enemy_script_lo:
  .DB <e_null
  .DB <e_straight_l
  .DB <e_straight_lu
  .DB <e_straight_ld
  .DB <e_star_3_seq
  .DB <e_star_3_way
  .DB <e_star_5_way
  .DB <e_sine_slow
  .DB <e_sine_fast
  .DB <e_sine_slow_fire_1
  .DB <e_sine_slow_fire_3
  .DB <e_spike_down_slow
  .DB <e_spike_down
  .DB <e_spike_down_fast
  .DB <e_spike_up_slow
  .DB <e_spike_up
  .DB <e_spike_up_fast
  .DB <e_bomb_left
  .DB <e_bomb_down
  .DB <e_bomb_up

enemy_script_hi:
  .DB >e_null
  .DB >e_straight_l
  .DB >e_straight_lu
  .DB >e_straight_ld
  .DB >e_star_3_seq
  .DB >e_star_3_way
  .DB >e_star_5_way
  .DB >e_sine_slow
  .DB >e_sine_fast
  .DB >e_sine_slow_fire_1
  .DB >e_sine_slow_fire_3
  .DB >e_spike_down_slow
  .DB >e_spike_down
  .DB >e_spike_down_fast
  .DB >e_spike_up_slow
  .DB >e_spike_up
  .DB >e_spike_up_fast
  .DB >e_bomb_left
  .DB >e_bomb_down
  .DB >e_bomb_up

e_score_value:
  .DB $50
  .DB $50
  .DB $50
  .DB $02
  .DB $02
  .DB $02
  .DB $05
  .DB $05
  .DB $05
  .DB $05
  .DB $00
  .DB $00
  .DB $00
  .DB $00
  .DB $00
  .DB $00
  .DB $03
  .DB $03
  .DB $03

e_sprite_gx:
  .REPT 10 INDEX I
    .DB I*9
  .ENDR
  .REPT 4 INDEX I
    .DB I*16
  .ENDR
  .REPT 5 INDEX I
    .DB 64+I*8
  .ENDR
  .REPT 5 INDEX I
    .DB I*16
  .ENDR
  .REPT 4 INDEX I
    .DB I*16
  .ENDR
  .REPT 4 INDEX I
    .DB I*16
  .ENDR


e_sprite_gy:
  .REPT 10
    .DB 40
  .ENDR
  .REPT 9
    .DB 32
  .ENDR
  .REPT 5
    .DB 56
  .ENDR
  .REPT 4
    .DB 72
  .ENDR
  .REPT 4
    .DB 88
  .ENDR

e_sprite_w:
  .REPT 10
    .DB 9
  .ENDR
  .REPT 9
    .DB 8
  .ENDR
  .REPT 13
    .DB 16
  .ENDR

e_sprite_h:
  .REPT 10
    .DB 8
  .ENDR
  .REPT 9
    .DB 8
  .ENDR
  .REPT 13
    .DB 16
  .ENDR

anim_len:
  .DB 1   ; Dummy Enemy
  .DB 4   ; Star
  .DB 1   ; Sine
  .DB 1   ; Spike Down
  .DB 1   ; Spike Up
  .DB 1   ; Bomb Idle
  .DB 2   ; Bomb Blink
  .DB 13  ; Explosion

anim_speed:
  .DB $FF ; Dummy Enemy
  .DB 8   ; Star
  .DB $FF ; Sine
  .DB $FF ; Spike Down
  .DB $FF ; Spike Up
  .DB $FF ; Bomb Idle
  .DB 16  ; Bomb Blink
  .DB 1   ; Explosion

anim_frame0:
  .DB 0   ; Dummy Enemy
  .DB 10  ; Star
  .DB 14  ; Sine
  .DB 15  ; Spike Down
  .DB 16  ; Spike Up
  .DB 17  ; Bomb Idle
  .DB 17  ; Bomb Blink
  .DB 19  ; Explosion
.ENDS

