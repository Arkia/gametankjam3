.DEFINE PLAYER_SHOT_MAX   16
.DEFINE PLAYER_SHOT_SPEED $0080
.RAMSECTION "ObjectArrays" BANK 0 SLOT "WRAM"
  pshot_x_lo    dsb PLAYER_SHOT_MAX
  pshot_x_hi    dsb PLAYER_SHOT_MAX
  pshot_y       dsb PLAYER_SHOT_MAX
.ENDS

.RAMSECTION "ObjectCounts" BANK 0 SLOT "ZeroPage"
  pshot_count   db
.ENDS

.SECTION "ObjectRoutines" BANK 1 SLOT "FixedROM"
init_objects:
  stz pshot_count
  rts

update_pshots:
  ldx #0                      ; Start at index 0
@loop
  cpx pshot_count             ; Compare to number of shots
  bcc +                       ; If index is greater than shot count
  rts                         ; Otherwise, return
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
  dec pshot_count             ; Decrement shot count
  ldy pshot_count             ; Load shot count as index
  lda pshot_x_lo.w,y          ; Swap current shot with last shot
  sta pshot_x_lo.w,x
  lda pshot_x_hi.w,y
  sta pshot_x_hi.w,x
  lda pshot_y.w,y
  sta pshot_y.w,x
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

.ENDS
