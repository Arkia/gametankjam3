.RAMSECTION "DecompressVars" BANK 0 SLOT 0
  dc_input  dw
  dc_output dw
  dc_ptr    dw
  dc_size   dw
.ENDS

.SECTION "ImageLoadingRoutines" BANK 1 SLOT 4
decompress:
  lda (dc_input)        ; Load size word low
  sta dc_size           ; Store into size
  inc dc_input          ; Advance input pointer
  bne +
  inc dc_input+1
+
  lda (dc_input)        ; Load size word high
  sta dc_size+1         ; Store into size
  inc dc_input          ; Advance input pointer
  bne +
  inc dc_input+1
+
  ora dc_size           ; Test if size is 0
  bne +
  rts                   ; If so, return
+
@next_command:
  lda (dc_input)        ; Get next command
  bpl @sequence         ; If positive, decode byte sequence
@run:                   ; If negative, decode buffer copy
  clc                   ; Setup addition
  lda dc_output         ; Load output pointer low
  adc (dc_input)        ; Add buffer offset
  sta dc_ptr            ; Store into buffer pointer
  lda dc_output+1       ; Load output pointer high
  bcs +
  dea                   ; Borrow from high btye
+
  sta dc_ptr+1          ; Store into buffer pointer
  inc dc_input          ; Advance input pointer
  bne +
  inc dc_input+1
+
  lda (dc_input)        ; Get length byte
  inc dc_input          ; Advance input pointer
  bne +
  inc dc_input+1
+
  tax                   ; Store length into X
  ldy #0                ; Set Y to 0
-
  lda (dc_ptr),y        ; Load next buffer byte
  sta (dc_output),y     ; Store into output
  lda dc_size           ; Get size low
  bne +                 ; If not zero, skip high byte
  dec dc_size+1         ; Decrement high byte
+
  dea                   ; Decrement low byte
  sta dc_size           ; Set size low
  ora dc_size+1         ; Test if size is 0
  bne +
  rts                   ; If size is 0, return
+
  iny                   ; Advance Y
  dex                   ; Decrement count
  bne -                 ; Loop
  tya                   ; Load bytes written into A
  clc                   ; Setup addition
  adc dc_output         ; Add to output pointer
  sta dc_output
  bcc +
  inc dc_output+1
+
  bra @next_command     ; Next command
@sequence:
  inc dc_input          ; Advance input pointer
  bne +
  inc dc_input+1
+
  tax                   ; Store sequence size into X
  inx                   ; Add 1
  ldy #0                ; Load 0 into Y
-
  lda (dc_input),y      ; Load next byte
  sta (dc_output),y     ; Write to output
  lda dc_size           ; Get size low
  bne +                 ; If not zero, skip high byte
  dec dc_size+1         ; Decrement high byte
+
  dea                   ; Decrement low byte
  sta dc_size           ; Set size low
  ora dc_size+1         ; Test if size is 0
  bne +
  rts                   ; If size is 0, return
+
  iny                   ; Increment offset
  dex                   ; Decrement count
  bne -                 ; Loop
  tya                   ; Load bytes written into A
  clc                   ; Setup addition
  adc dc_output         ; Add to output pointer
  sta dc_output
  bcc +
  inc dc_output+1
+
  tya                   ; Load bytes written into A
  clc                   ; Setup addition
  adc dc_input          ; Add to input pointer
  sta dc_input
  bcc +
  inc dc_input+1
+
  bra @next_command     ; Next command
.ENDS