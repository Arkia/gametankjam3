.RAMSECTION "DrawEngine" BANK 0 SLOT 0
  draw_proc_addr  dw
  draw_proc_a     db
  draw_proc_x     db
  draw_proc_y     db
  draw_proc_p     db
  draw_status     db
  draw_data       dsb 8
.ENDS

.DEFINE L1_SCROLL_DELAY 2

.RAMSECTION "Scrolling" BANK 0 SLOT 0
  bg_scroll_x     db
  bg_scroll_timer db
.ENDS

.SECTION "DrawingRoutines" BANK 1 SLOT 4

init_level1_bg:
  lda #8
  sta bg_scroll_x
  lda #L1_SCROLL_DELAY
  sta bg_scroll_timer
  rts

draw_game:
  jsr wait_blitter
  jsr draw_enemies
  jsr draw_pshots
  jsr draw_player
  jsr wait_blitter
  lda #$FF
  jsr draw_border
  jsr wait_blitter
  rts

draw_level1_bg:
  dec bg_scroll_timer         ; Decrement scroll timer
  bne +                       ; If timer is 0
  lda #L1_SCROLL_DELAY        ; Reset scroll timer
  sta bg_scroll_timer         ; Set scroll timer
  dec bg_scroll_x             ; Decrement scroll X
  bne +                       ; If scroll to 0
  lda #8                      ; Reset to 8
  sta bg_scroll_x             ; Set scroll X
+
  lda #112                    ; Background GX
  sta DMA_GX                  ; Set GX
  stz DMA_GY                  ; Set GY to 0
  stz DMA_VY                  ; Set VY to 0
  clc                         ; Setup addition
  lda bg_scroll_x             ; Get scroll X
  adc #-8                     ; Offset
  sta DMA_VX                  ; Set VX
  sta draw_data               ; Save VX
  stz draw_data+1             ; Save VY
  lda #16                     ; 16 pixel tall rows
  sta DMA_HEIGHT              ; Set height
  ldx #3                      ; 3 rows
-
  lda #120                    ; 120 pixels wide
  sta DMA_WIDTH               ; Set width
  lda #1                      ; Blit start command
  sta DMA_START               ; Do blit
  inc draw_status             ; Flag blitter active
  jsr wait_blitter            ; Wait for blitter
  lda #16                     ; 8 pixels wide
  sta DMA_WIDTH               ; Set width
  clc                         ; Setup addition
  lda draw_data               ; Load VX
  adc #120                    ; Move 120 pixels right
  sta DMA_VX                  ; Set VX
  lda #1                      ; Blit start command
  sta DMA_START               ; Do blit
  wai                         ; Wait for blit
  lda draw_data               ; Load old VX
  sta DMA_VX                  ; Set VX
  clc                         ; Setup addition
  lda draw_data+1             ; Load VY
  adc #16                     ; Add 16 pixels
  sta draw_data+1             ; Save position
  sta DMA_VY                  ; Set VY
  sta DMA_GY                  ; Set GY
  dex                         ; Decrement row count
  bne -                       ; Loop

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
