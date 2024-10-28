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

load_font:
  jsr enable_blitter                  ; Turn on blitter
  ldx #1                              ; Quadrant 1 (128,0)
  jsr set_sprite_quadrant             ; Make active quadrant
  jsr enable_sprite_ram               ; Map sprite RAM
  lda #<font_image                    ; Load font pointer low
  sta dc_input                        ; Set decompression input pointer low
  lda #>font_image                    ; Load font pointer hight
  sta dc_input+1                      ; Set decompression input pointer high
  stz dc_output                       ; Set output pointer low
  lda #$40                            ; Start of VRAM
  sta dc_output+1                     ; Set output pointer high
  jsr decompress                      ; Load image data
  jsr enable_blitter                  ; Turn blitter back on
  rts

; Draws the string pointed to by draw_data, draw_data+1
; String length stored in draw_data+2
; Draw position in draw_data+3, draw_data+4
; Max string size is 255 chars
; draw_data+3 will be X position of end of string
draw_string:
  lda draw_data+4                     ; Load draw Y
  sta DMA_VY                          ; Set blit Y
  lda #7                              ; All font glyphs are 7 pixels tall
  sta DMA_HEIGHT                      ; Set blit height
  ldy #0                              ; Set array index to 0
-
  cpy draw_data+2                     ; End of string?
  bne +
  rts
+
  lda draw_data+3                     ; Load draw X
  sta DMA_VX                          ; Set blit X
  lda (draw_data),y                   ; Get next character
  bne +                               ; Test for space (0)
  clc                                 ; Setup addition
  lda draw_data+3                     ; Get draw X
  adc #6                              ; Move one space
  sta draw_data+3                     ; Update draw X
  iny                                 ; Next character
  bra -                               ; Loop
+
  dea                                 ; Offset character ID
  tax                                 ; Transfer into X
  lda font_gx.w,x                     ; Load glyph GX
  sta DMA_GX                          ; Set blit GX
  lda font_gy.w,x                     ; Load glyph GY
  sta DMA_GY                          ; Set blit GY
  lda font_w.w,x                      ; Load glyph width
  sta DMA_WIDTH                       ; Set blit width
  clc                                 ; Setup addition
  adc draw_data+3                     ; Add width to draw X
  ina                                 ; Add 1 pixel spacing
  sta draw_data+3                     ; Update draw X
  lda #1                              ; Blit start command
  sta DMA_START                       ; Blit glyph
  wai                                 ; Wait for blitter
  iny                                 ; Next character
  bra -                               ; Loop

draw_status_bar:
  jsr wait_blitter
  lda dma_flags               ; Get current blitter flags
  ora #%10001000              ; Set opaque and color fill mode
  sta DMA_FLAGS               ; Set blitter flags
  stz DMA_VX                  ; Set blit X
  stz DMA_VY                  ; Set blit Y
  lda #127                    ; 127 pixels wide
  sta DMA_WIDTH
  lda #16                     ; 16 pixels tall
  sta DMA_HEIGHT
  lda #$FF                    ; Full black
  sta DMA_COLOR
  lda #1
  sta DMA_START
  wai
  lda dma_flags               ; Get previous blitter flags
  sta DMA_FLAGS               ; Restore blitter flags
  lda #2                      ; Print X
  sta draw_data+3
  lda #8                      ; Print Y
  sta draw_data+4
  lda #<str_lives             ; String pointer low
  sta draw_data
  lda #>str_lives             ; String pointer high
  sta draw_data+1
  lda #4                      ; String length
  sta draw_data+2
  jsr draw_string             ; Print to screen
  lda #91
  sta draw_data+3
  lda #<str_score
  sta draw_data
  lda #>str_score
  sta draw_data+1
  lda #6
  sta draw_data+2
  jmp draw_string

draw_game:
  jsr wait_blitter
  jsr draw_enemies
  jsr draw_eshots
  jsr draw_pshots
  jsr draw_player
  jsr wait_blitter
  jsr draw_status_bar
  lda #$FF
  jsr draw_border
  jsr wait_blitter
  rts

draw_level1_bg:
  lda dma_flags               ; Get blitter flags
  and #%11101111              ; Clear GCARRY
  sta DMA_FLAGS
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
  lda #16
  sta DMA_VY                  ; Set VY to 16
  sta draw_data+1             ; Save VY
  clc                         ; Setup addition
  lda bg_scroll_x             ; Get scroll X
  adc #-8                     ; Offset
  sta DMA_VX                  ; Set VX
  sta draw_data               ; Save VX
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
  lda #16                     ; 16 pixels wide
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
  sta DMA_GY                  ; Set GY
  adc #16                     ; Add 16 pixels
  sta draw_data+1             ; Save position
  sta DMA_VY                  ; Set VY
  dex                         ; Decrement row count
  bne -                       ; Loop
  lda dma_flags               ; Get old blitter flags
  sta DMA_FLAGS               ; Restore
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

.SECTION "FontData" BANK 0 SLOT "BankROM"
font_image:
  .INCBIN "data/font_page.bin"

font_gx:
  .REPT 25 INDEX I
    .DB 128+5*I
  .ENDR
  .REPT 12 INDEX I
    .DB 128+5*I
  .ENDR
  .DB 128+60
  .DB 128+62
  .DB 128+64
  .DB 128+65
  .DB 128+66
  .DB 128+69
font_gy:
  .REPT 25
    .DB 0
  .ENDR
  .REPT 18
    .DB 7
  .ENDR
font_w:
  .REPT 37
    .DB 5
  .ENDR
  .DB 2
  .DB 2
  .DB 1
  .DB 1
  .DB 3
  .DB 6
.ENDS
