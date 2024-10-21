.INCLUDE "gametank_cpu.i"
.INCLUDE "acp/acp.i"

.ROMBANKSIZE $4000
.ROMBANKS 2

.RAMSECTION "Mirrors" BANK 0 SLOT 0
  bank_flags  db
  dma_flags   db
.ENDS

.DEFINE DRAW_FRAME_DONE   $80
.DEFINE DRAW_BUFFER_DOWN  $40

.RAMSECTION "DrawEngine" BANK 0 SLOT 0
  draw_status     db
  draw_mode       db
  draw_x          db
  draw_y          db
  draw_color      db
  draw_data       dw
  draw_read       dw
  draw_write      dw
.ENDS

.RAMSECTION "DrawBuffer" BANK 0 SLOT 2 ALIGN 256
  draw_buffer     dsb 512
.ENDS

.SECTION "MainProg" BANK 1 SLOT 4
reset:
  ; Init Code
  cld
  sei
  stz DMA_FLAGS
  lda #%00111000  ; Clip draws and draw to frame 1
  sta BANK_FLAGS  ; Reset bank settings
  sta bank_flags  ; Update mirror
  
  stz $0F
  lda #$80
  sta draw_mode
  stz draw_status
  stz draw_read
  stz draw_write
  lda #>draw_buffer
  sta draw_read+1
  eor #1
  sta draw_write+1
  
  ;lda #%01000101  ; Enable blitter and interrupts
  ;sta DMA_FLAGS   ; Set blitter flags
  ;sta dma_flags   ; Update mirror
  ;cli
  
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
  ;jsr enable_blitter
  
  ldy #0
-
  lda test_draw.w,y
  sta (draw_write),y
  iny
  cpy #3
  bne -
  
  lda draw_status
  ora #%01000000
  sta draw_status
  
main_loop:
  bra main_loop
  
test_draw:
  .DB $00 $FB                 ; Clear screen
  .DB $07                     ; Halt
  
enable_sprite_ram:
  lda DMA_FLAGS
  and #%11011110
  sta DMA_FLAGS
  rts
  
enable_blitter:
  lda DMA_FLAGS
  ora #%00000001
  sta DMA_FLAGS
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
  
irq:
  inc $0F
  pha
  phx
  phy
  bit draw_mode               ; Test draw mode. Set N if halted. Set V if continuing a draw command
  bmi irq_end                 ; Exit IRQ if halted
  bvc irq_next_com            ; Skip to next command if not continuing
  lda draw_mode               ; Get current command
  and #$3F                    ; Mask out mode bits
  asl                         ; Multiply by 2
  tax                         ; Use as table index
  lda draw_update_table.w+1,x ; Read low byte of subroutine
  pha                         ; Push on stack
  lda draw_update_table.w,x   ; Read high byte of subroutine
  pha                         ; Push on stack
  rts                         ; Jump to command routine
irq_next_com:
  lda (draw_read)             ; Read next command
  inc draw_read               ; Advance command pointer
  asl                         ; Multiply by 2
  tax                         ; Use as table index
  lda draw_start_table.w+1,x  ; Read low byte of subroutine
  pha                         ; Push on stack
  lda draw_start_table.w,x    ; Read high byte of subroutine
  pha                         ; Push on stack
  rts                         ; Jump to command routine
irq_end:
  ply
  plx
  pla
  rti
  
nmi:
  pha
  phx
  phy
  bit draw_status           ; Test status of drawing engine. Set N if frame is ready. Set V if buffer is ready
  bpl nmi_no_flip           ; Skip frame flip if frame is not ready
  lda bank_flags            ; Load current bank flags
  eor #%00001000            ; Flip framebuffer target
  sta BANK_FLAGS            ; Update framebuffer target
  sta bank_flags            ; Update mirror
  lda dma_flags             ; Load current DMA flags
  eor #%00000010            ; Flip framebuffer output
  sta DMA_FLAGS             ; Update DMA flags
  sta dma_flags             ; Update mirror
  lda draw_status
  and #%01111111
  sta draw_status           ; Clear frame ready
nmi_no_flip:
  bvc nmi_no_buffer         ; Skip starting draw engine if buffer is not ready
  bit draw_mode             ; Check if draw engine is halted
  bpl nmi_no_buffer         ; If not don't start the new command buffer
  stz draw_write            ; Reset write index
  stz draw_read             ; Reset read index
  lda draw_write+1          ; Get write page
  eor #1                    ; Swap buffer
  sta draw_write+1          ; Update write page
  lda draw_read+1           ; Get read page
  eor #1                    ; Swap buffer
  sta draw_read+1           ; Update read page
  stz draw_mode             ; Start draw engine
  lda draw_status
  and #%10111111
  sta draw_status           ; Clear buffer ready
  brk
nmi_no_buffer:
  ; TODO: Sound/Music engine
  ply
  plx
  pla
  rti
  
draw_noop:
  ply
  plx
  pla
  rti
  
draw_clear_begin:
  lda #%01000000
  sta draw_mode
  lda dma_flags
  ora #%10001001
  sta DMA_FLAGS
  stz DMA_VX
  stz DMA_VY
  lda #64
  sta DMA_WIDTH
  sta DMA_HEIGHT
  lda (draw_read)
  inc draw_read
  sta DMA_COLOR
  lda #1
  sta DMA_START
  stz draw_data
  ply
  plx
  pla
  rti
  
draw_clear_cont:
  stz $0F
  ldx draw_data
  cpx #3
  bne +
  lda draw_mode
  and #%10111111
  sta draw_mode
  lda dma_flags
  sta DMA_FLAGS
  ply
  plx
  pla
  rti
+
  lda draw_clear_x.w,x
  sta DMA_VX
  lda draw_clear_y.w,x
  sta DMA_VY
  inx
  lda #1
  sta DMA_START
  stx draw_data
  ply
  plx
  pla
  rti
  
draw_clear_x:
  .DB 64 0 64
draw_clear_y:
  .DB 0 64 64
  
draw_box:
  stz $0F
  lda (draw_read)
  sta DMA_VX
  inc draw_read
  lda (draw_read)
  sta DMA_VY
  inc draw_read
  lda (draw_read)
  sta DMA_WIDTH
  inc draw_read
  lda (draw_read)
  sta DMA_HEIGHT
  inc draw_read
  lda (draw_read)
  sta DMA_COLOR
  inc draw_read
  lda #1
  sta DMA_START
  ply
  plx
  pla
  rti
  
draw_dma_flags:
  lda dma_flags
  and #%01000111
  ora (draw_read)
  inc draw_read
  sta DMA_FLAGS
  sta dma_flags
  ply
  plx
  pla
  rti
  
draw_end:
  lda draw_status
  ora #%10000000
  sta draw_status
  lda draw_mode
  ora #%10000000
  sta draw_mode
  ply
  plx
  pla
  rti
  
draw_start_table:
  .DW draw_clear_begin-1  ; 0 - Clear
  .DW draw_noop-1         ; 1 - String
  .DW draw_noop-1         ; 2 - Map
  .DW draw_box-1          ; 3 - Box
  .DW draw_noop-1         ; 4 - Sprite
  .DW draw_noop-1         ; 5 - Sprite Page
  .DW draw_dma_flags-1    ; 6 - DMA Flags
  .DW draw_end-1          ; 7 - End
  
draw_update_table:
  .DW draw_clear_cont-1   ; 0 - Clear
  .DW draw_noop-1         ; 1 - String
  .DW draw_noop-1         ; 2 - Map
  
.ENDS

.SECTION "ImageData" BANK 0 SLOT 3
test_image:
  .INCBIN "data/player.bin"
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