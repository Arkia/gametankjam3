.INCLUDE "gametank_cpu.i"
.INCLUDE "acp/acp.i"

.ROMBANKSIZE $4000
.ROMBANKS 2

.RAMSECTION "Mirrors" BANK 0 SLOT 0
  bank_flags  db
  dma_flags   db
.ENDS

.RAMSECTION "Scratch" BANK 0 SLOT 0
  temp  dsb 4
.ENDS

.RAMSECTION "Controller" BANK 0 SLOT 0
  p1_state    db
  p2_state    db
  p1_press    db
  p2_press    db
  p1_release  db
  p2_release  db
.ENDS

.DEFINE DRAW_FRAME_DONE   $80
.DEFINE DRAW_BUFFER_DOWN  $40

.RAMSECTION "DrawEngine" BANK 0 SLOT 0
  draw_status db
.ENDS

.RAMSECTION "InterruptVars" BANK 0 SLOT 0
  frame_count     db
.ENDS

.SECTION "MainProg" BANK 1 SLOT 4
reset:
  ; Init Code
  cld
  sei
  stz DMA_FLAGS
  stz dma_flags
  lda #%00111000  ; Clip draws and draw to frame 1
  sta BANK_FLAGS  ; Reset bank settings
  sta bank_flags  ; Update mirror
  
  stz draw_status
  
  lda #$7F        ; Disable ACP
  sta AUDIO_RATE
  
  ldx #0
-
  lda acp_prog.w,x
  sta ACP_PROG_START,x
  inx
  cpx #acp_size
  bne -
  
  ldx #5
-
  lda acp_vectors.w,x
  sta $3FFA,x
  dex
  bpl -
  
  ldx #VOICE_COUNT-1
-
  stz VOICE_VOLUME,x
  dex
  bpl -
  
  stz AUDIO_RESET
  lda #$FF
  sta AUDIO_RATE
  sta VIA_DDRB
  
  jsr enable_blitter
  ldx #$0
  jsr set_sprite_quadrant
  jsr enable_sprite_ram
  lda #<test_image
  sta dc_input
  lda #>test_image
  sta dc_input+1
  stz dc_output
  lda #$40
  sta dc_output+1
  jsr decompress
  jsr enable_blitter
  
  lda #%01000101  ; Enable blitter and interrupts
  sta DMA_FLAGS   ; Set blitter flags
  sta dma_flags   ; Update mirror
  cli
  
  lda #~%11011011
  jsr clear_screen
  lda #8
  sta DMA_VX
  sta DMA_VY
  sta DMA_WIDTH
  sta DMA_HEIGHT
  stz DMA_GX
  lda #48
  sta DMA_GY
  lda #1
  sta DMA_START
  wai
  lda #$FF
  jsr draw_border
  jsr display_flip
  
main_loop:
  jsr update_input            ; Read controllers
  jsr wait_frame              ; Wait for VBLANK
  bra main_loop
  
enable_sprite_ram:
  lda dma_flags
  and #%11011110
  sta DMA_FLAGS
  sta dma_flags
  rts
  
enable_blitter:
  lda dma_flags
  ora #%00000001
  sta DMA_FLAGS
  sta dma_flags
  rts
  
set_sprite_quadrant:
  lda #$FF
  sta DMA_VX
  sta DMA_VY
  lda quadrant_gx_table.w,x
  sta DMA_GX
  lda quadrant_gy_table.w,x
  sta DMA_GY
  lda #1
  sta DMA_WIDTH
  sta DMA_HEIGHT
  sta DMA_START
  rts
  
quadrant_gx_table:
  .DB 0, 128, 0, 128
quadrant_gy_table:
  .DB 0, 0, 128, 128
  
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
  bbr0 draw_status,+          ; Return if blitter is done
  wai                         ; Wait for blitter
+
  rts
  
wait_frame:
  lda frame_count             ; Load current frame counter
-
  wai                         ; Wait for interrupt
  cmp frame_count             ; Compare to frame counter
  beq -                       ; If counter hasn't changed, keep waiting
  rts                         ; Return
  
update_input:
  lda GAMEPAD2                ; Reset latch on controller 1
  ldx #0                      ; Index controller 1
-   
  lda p1_state,x              ; Get current controller state
  sta temp                    ; Save in scratch
  lda GAMEPAD1,x              ; Read first byte
  eor #$FF                    ; Invert
  asl                         ; Shift left
  asl                         ; Shift left
  and #%11000000              ; Grab top 2 bits (Start and A button)
  sta temp+1                  ; Save
  lda GAMEPAD1,x              ; Read second byte
  eor #$FF                    ; Invert
  and #%00111111              ; Mask out top 2 bits
  ora temp+1                  ; Combine with previous buttons
  sta p1_state,x              ; Set controller state
  eor #$FF                    ; Not current buttons
  and temp                    ; And previous buttons
  sta p1_release,x            ; Set controller released buttons
  lda temp                    ; Load previous buttons
  eor #$FF                    ; Not previous buttons
  and p1_state,x              ; And current buttons
  sta p1_press,x              ; Set controller pressed buttons
  inx                         ; Next controller
  cpx #2                      ; Last controller?
  bne -                       ; Loop
  rts                         ; Return
  
irq:
  stz draw_status             ; Blitter finished
  stz DMA_START               ; Clear interrupt
  rti
  
nmi:
  inc frame_count           ; Increment frame counter
  rti
  
.ENDS

.SECTION "ImageData" BANK 0 SLOT 3
test_image:
  .INCBIN "data/page0.bin"
.ENDS

.SECTION "ACPImport" BANK 0 SLOT 3
  acp_prog:
    .INCBIN "acp/acp.dat" READ -6 FREADSIZE acp_size
  acp_vectors:
    .INCBIN "acp/acp.dat" SKIP acp_size
.ENDS

.INCLUDE "decompress.s"
  
.SECTION "VectorTable" BANK 1 SLOT 4 ORGA $FFFA FORCE
  .DW nmi
  .DW reset
  .DW irq
.ENDS
