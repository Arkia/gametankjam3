.RAMSECTION "DrawEngine" BANK 0 SLOT 0
  draw_proc_addr  dw
  draw_proc_a     db
  draw_proc_x     db
  draw_proc_y     db
  draw_proc_p     db
  draw_status     db
.ENDS

.SECTION "DrawingRoutines" BANK 1 SLOT 4

draw_game:
  jsr wait_blitter
  jsr draw_player
  jsr wait_blitter
  lda #$FF
  jsr draw_border
  jsr wait_blitter
  rts

draw_level1_bg:
  lda #112                    ; Background GX
  sta DMA_GX                  ; Set GX
  stz DMA_GY                  ; Set GY to 0
  stz DMA_VX                  ; Set VX to 0
  stz DMA_VY                  ; Set VY to 0
  lda #120                    ; 120 pixels wide
  sta DMA_WIDTH               ; Set width
  lda #16                     ; 16 pixel tall rows
  sta DMA_HEIGHT              ; Set height
  ldx #3                      ; 3 rows
-
  lda #1                      ; Blit start command
  sta DMA_START               ; Do blit
  jsr draw_suspend            ; Wait for blit
  lda #8                      ; 8 pixels wide
  sta DMA_WIDTH               ; Set width
  lda #120                    ; Move over 120 pixels
  sta DMA_VX                  ; Set VX
  lda #1                      ; Blit start command
  sta DMA_START               ; Do blit
  wai                         ; Wait for blit

  rts

draw_init:
  stz draw_status             ; Clear blit active
  stz draw_proc_addr          ; Clear current draw address
  stz draw_proc_addr+1
  rts                         ; Return

; Suspends the current drawing routine until the blitter triggers IRQ
draw_suspend:
  sta draw_proc_a             ; Save A register
  stx draw_proc_x             ; Save X register
  sty draw_proc_y             ; Save Y register
  php                         ; Push PSW
  pla                         ; Get PSW into A
  sta draw_proc_p             ; Save PSW
  pla                         ; Get first address byte
  sta draw_proc_addr          ; Store in draw pointer
  pla                         ; Get second address byte
  sta draw_proc_addr+1        ; Store in draw pointer
  rts                         ; Return from draw routine

; Resumes a drawing routine previously suspended
draw_resume:
  lda draw_proc_addr+1        ; Get second address byte
  ora draw_proc_addr          ; Combine with first address byte
  bne +                       ; If null address, return
  rts
+
  lda draw_proc_addr+1        ; Get second address byte
  pha                         ; Push onto stack
  lda draw_proc_addr          ; Get first address byte
  pha                         ; Push onto stack
  stz draw_proc_addr          ; Clear pending routine address
  stz draw_proc_addr+1
  lda draw_proc_p             ; Get PSW
  pha                         ; Push onto stack
  lda draw_proc_a             ; Restore A register
  ldx draw_proc_x             ; Restore X register
  ldy draw_proc_y             ; Restore Y register
  plp                         ; Restore PSW
  rts                         ; Resume draw routine

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
  sta draw_status             ; Flag blitter active
  jsr draw_suspend            ; Wait for blitter
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
-
  wai                         ; Wait for blitter
  lda draw_proc_addr          ; Check for pending draws
  ora draw_proc_addr+1
  bne -
+
  rts
.ENDS
