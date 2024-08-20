mov ah, 0xA0                ; set AX to start of screen buffer segment
mov ds, ax                  ; make DS point to screen buffer
mov es, ax                  ; same for ES
mov al, 0x60                ; send 0x60 to the 8042 controller
out 0x64, al                ; command 0x60 write byte to controller configuration at byte 0
out 0x60, al                ; write byte 0x60, disables internal clock
mov dx, 0x3C0               ; set port to output to, port 0x3C0 writes to the attribute address register
out dx, al                  ; "lock" color palette by setting the palette address source bit to 1 (the 0x40 is being ignored)
mov dl, 0xC4                ; port 0x3C4 writes to the sequencer registers
mov ax, 0xf02               ; set the value of sequencer register 2 (the map mask register) to 3
out dx, ax                  ; enable DMA for the VGA segment
mov dl, 0xCE                ; port 0x3CE writes to the graphics registers
mov ax, 0x1005              ; set the value of graphics register 5 (graphics mode register) to 0x10
out dx, ax                  ; store characters as color-value pairs, not with two matrices
mov dl, 0xB4                ; port 0x3B4 writes to the CRTC registers
mov ax, 0x2701              ; set the value of CRTC register 1 (horizontal display end) to 0x27
out dx, ax                  ; set the char count in each row to 0x27+1 i.e. 40
mov ax, 0x207               ; set the value of CTRC register 7 (the overflow register) to 2
out dx, ax                  ; make vertical display end even bigger by setting bit 8 of the vertical display end to 1
mov ax, 0xF09               ; set the value of CTRC register 9 (the minimum scan line register) to 0xF
out dx, ax                  ; set character height to 0xF+1 i.e. 16px
mov ax, 0x8F12              ; set the value of CTRC register 0x12 (vertical display end register) to 0x8F
out dx, ax                  ; set vertical display end to 0x18F (with 'mov ax, 0x207', 'out dx, ax' from before), screen_height=0x18F+1=16*25=character_height*line_count
mov ch, 0x3B                ; override initial CX so that in initial screen clearing the entire buffer will be cleared
mov si, 0x30C5              ; arbitrary pointer to memory location where the initial position of the snake head is stored
start:                      ; reset game
    mov ax, 0x720           ; fill the screen with word 0x720 (white on black space)
    add ch, 0x5             ; add 0x500 to initial CX (0xFFFF) to write 0x4FF words (a little more then the screen)
    xor di, di              ; start writing at the start of the screen
    rep stosw               ; clear the screen
    dec cx                  ; set CX to 0xFFFF again
    mov di, [bx]            ; reset head position, BX always points to a valid screen position containing 0x720 after setting video mode
    lea sp, [bp+si]         ; set stack pointer (tail) to current head pointer
.food:                      ; create new food item
    in ax, 0x40             ; read 16 bit timer counter into AX for randomization
    and bx, ax              ; mask with BX to make divisible by 4 and less than or equal to screen size
    xor [bx], cl            ; place food item and check if position was empty by applying XOR with CL (assumed to be 0xFF)
.input:                     ; handle keyboard input
    mov bx, 0x7D0           ; initialize BX to screen size (40x25x2 bytes)
    jp .food                ; if position was occupied by snake or wall in food generation => try again, if we came from main loop PF=0
    in al, 0x60             ; read scancode from keyboard controller - bit 7 is set in case key was released
    imul ax, BYTE 0xA       ; we want to map scancodes for arrow up (0x48/0xC8), left (0x4B/0xCB), right (0x4D/0xCD), down (0x50/0xD0) to movement offsets
    aam 0x14                ; IMUL (AH is irrelevant here), AAM and AAD with some magic constants maps up => -80, left => -2, right => 2, down => 80
    aad 0x44                ; using arithmetic instructions is more compact than checks and conditional jumps
    cbw                     ; but causes weird snake movements though with other keys
    add di, ax              ; add offset to head position
    cmp di, bx              ; check if head crossed vertical edge by comparing against screen size in BX
    lodsw                   ; load 0x2007 into AX from off-screen screen buffer and advance head pointer
    adc [di], ah            ; ADC head position with 0x20 to set snake character
    jnp start               ; if it already had snake or wall in it or if it crossed a vertical edge, PF=0 from ADC => game over
    mov [bp+si], di         ; store head position, use BP+SI to default to SS
    jz .food                ; if food was consumed, ZF=1 from ADC => generate new food
.wall:                      ; draw an invisible wall on the left side
    mov [bx], cl            ; store wall character
    sub bx, BYTE 0x50       ; go one line backwards
    jns .wall               ; jump to draw the next wall
    pop bx                  ; no food was consumed so pop tail position into BX
    mov [bx], ah            ; clear old tail position on screen
    jnp .input              ; loop to keyboard input, PF=0 from SUB
times (0x10000+$$-$) db 0x0 ; fill the rest with zeros as the BIOS needs to be 0x10000 bytes
