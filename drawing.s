.RAMSECTION "DrawEngine" BANK 0 SLOT 0
  draw_status db
.ENDS

.SECTION "DrawingRoutines" BANK 1 SLOT 4
draw_game_scene:
  jsr wait_blitter
  lda #~%11011011
  jsr clear_screen
  jsr draw_player
  jsr wait_blitter
  lda #$FF
  jsr draw_border
  rts

display_flip:
  lda bank_flags              ; Get current bank state from mirror
  eor #%00001000              ; Flip framebuffer target
  sta BANK_FLAGS              ; Set bank state
  sta bank_flags              ; Set mirror
  lda dma_flags               ; Get current blitter state
  eor #%00000010              ; Flip displayed framebuffer
  sta DMA_FLAGS               ; Set blitter state
  sta dma_flags               ; Set mirror
  rts

clear_screen:
  sta DMA_COLOR               ; Set draw color
  lda dma_flags               ; Get current blitter flags
  ora #%10001000              ; Set opaque and color fill mode
  sta DMA_FLAGS               ; Set blitter flags
  lda #64                     ; Rectangle size
  sta DMA_WIDTH
  sta DMA_HEIGHT
  ldx #3                      ; 4 times
-
  lda clear_pos_x.w,x         ; Get X position of quadrant
  sta DMA_VX                  ; Set blit X
  lda clear_pos_y.w,x         ; Get Y position of quadrant
  sta DMA_VY                  ; Set blit Y
  lda #1                      ; Blit start command
  sta DMA_START               ; Do blit
  wai                         ; Wait for blitter
  dex                         ; Decrement X
  bpl -                       ; Loop
  lda dma_flags               ; Get previous blitter flags
  sta DMA_FLAGS               ; Restore blitter flags
  rts

clear_pos_x:
  .DB 0, 64, 0, 64
clear_pos_y:
  .DB 0, 0, 64, 64

draw_border:
  sta DMA_COLOR               ; Set draw color
  lda dma_flags               ; Get current blitter state
  ora #%10001000              ; Set opaque and color fill
  sta DMA_FLAGS               ; Update blitter state
  ldx #3                      ; 4 times
-
  lda border_vx.w,x
  sta DMA_VX
  lda border_vy.w,x
  sta DMA_VY
  lda border_w.w,x
  sta DMA_WIDTH
  lda border_h.w,x
  sta DMA_HEIGHT
  lda #1
  sta DMA_START
  wai
  dex
  bpl -
  lda dma_flags
  sta DMA_FLAGS
  rts

border_vx:
  .DB 0, 127, 1, 0
border_vy:
  .DB 0, 0, 127, 1
border_w:
  .DB 127, 1, 127, 1
border_h:
  .DB 1, 127, 1, 127

wait_blitter:
  lda draw_status             ; Get blitter status
  beq +                       ; Return if not blitting
  wai                         ; Wait for blitter
+
  rts
.ENDS
