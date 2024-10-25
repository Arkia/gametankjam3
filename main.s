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

.DEFINE PAD_UP    %00001000
.DEFINE PAD_DOWN  %00000100
.DEFINE PAD_LEFT  %00000010
.DEFINE PAD_RIGHT %00000001
.DEFINE PAD_B     %00010000
.DEFINE PAD_C     %00100000
.DEFINE PAD_A     %01000000
.DEFINE PAD_START %10000000

.RAMSECTION "Controller" BANK 0 SLOT 0
  p1_state    db
  p2_state    db
  p1_press    db
  p2_press    db
  p1_release  db
  p2_release  db
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
  jsr init_player
  
  lda #%01000101  ; Enable blitter and interrupts
  sta DMA_FLAGS   ; Set blitter flags
  sta dma_flags   ; Update mirror
  cli
  
main_loop:
  jsr update_input            ; Read controllers
  jsr update_player           ; Move player
  jsr draw_game_scene         ; Draw scene
  jsr wait_frame              ; Wait for VBLANK
  jsr display_flip            ; Flip display
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
.INCLUDE "player.s"
.INCLUDE "drawing.s"
  
.SECTION "VectorTable" BANK 1 SLOT 4 ORGA $FFFA FORCE
  .DW nmi
  .DW reset
  .DW irq
.ENDS
