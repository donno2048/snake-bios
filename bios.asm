%ifndef QEMU
%ifndef V86
%error must select either QEMU or V86, or both
%endif
%endif

%ifdef FONT
%define V86
%endif

push 0xA000                 ; push start of screen buffer for game, also start of font buffer if we need a font
pop es                      ; set ES right away for font loading, also will later be used to access screen buffer 
push es                     ; push ES with screen buffer
pop ds                      ; set DS to screen buffer too
mov dx, 0x3C0               ; port 0x3C0 writes to the attribute address register
%ifdef V86
mov al, 0xF4                ; enable keyboard command
out 0x60, al                ; sends the command to the i8042 controller
mov al, 0x7                 ; use 0x7 both to choose text color and the DAC corresponding to it
out dx, al                  ; choose 0x7 ("white on black") text color
out dx, al                  ; set it to DAC index 7, in this case, black (this inverts colors, but it's OK)
%endif
%ifdef QEMU
mov al, 0x60                ; send 0x60 to the 8042 controller, and use later to set pallete address source bit
out 0x64, al                ; command 0x60 write byte to controller configuration at byte 0
out 0x60, al                ; write byte 0x60, disables internal clock
out dx, al                  ; "lock" color palette by setting the palette address source bit to 1 (the 0x40 is being ignored), necessary to initiate video
mov dl, 0xC4                ; port 0x3C4 writes to the sequencer registers
mov ax, 0x702               ; set the value of sequencer register 2 (the map mask register) to 7
out dx, ax                  ; don't mask any region of VGA memory
%ifdef FONT
mov ax, 0x404               ; set the value of sequencer register 4 (the character map select register) to 4
out dx, ax                  ; disable spliting input into VGA regions so that we could write the font, later restore
%endif
mov dl, 0xCE                ; port 0x3CE writes to the graphics registers
mov ax, 0x1005              ; set the value of graphics register 5 (graphics mode register) to 0x10
out dx, ax                  ; store characters as color-value pairs, not with two matrices
mov ax, 0xFF08              ; set the value of graphics register 8 (byte mask) to 0xFF
out dx, ax                  ; don't mask the bytes when writing
%endif
%ifdef V86
mov dl, 0xC9                ; port 0x3C9 writes to the DAC data register
mov al, 0x1F                ; store a 0x1F byte in the first DAC entry - not needed because we can use old AL but this looks better
times 3 out dx, al          ; set rgb value of background to grey (rgb #1f1f1f)
%endif
mov dl, 0xB4                ; port 0x3B4 writes to the CRTC registers
mov ax, 0x2701              ; set the value of CRTC register 1 (horizontal display end) to 0x27
out dx, ax                  ; set the char count in each row to 0x27+1 i.e. 40
xchg si, ax                 ; arbitrary pointer to memory location where the initial position of the snake head is stored
mov ax, 0xA07               ; set the value of CTRC register 7 (the overflow register) to 0xA
out dx, ax                  ; setting bit 1 (0x2) sets the 8th bit of vertical display end, setting bit 3 (0x8) sets bit 8 of register index 0x15 (which we set for V86)
mov ax, 0x9012              ; set the value of CTRC register 0x12 (the vertical display end register) to 0x190, the set 8 bit comes from the overflow register (index 0x07)
out dx, ax                  ; set screen height to 0x10 (character height) times 25 lines
%ifdef V86
mov al, 0x2                 ; write 0x90 into register index 0x02 (start horizontal blancking register)
out dx, ax                  ; disable blanking as 0x90 must be above the character clocks of a scan line as it's above the character clocks for the display
mov al, 0x15                ; write 0x190 into register index 0x15 (start vertical blanking register), the set 8 bit comes from the overflow register (index 0x07)
out dx, ax                  ; set vertical blanking register to vertical display end
%endif
mov ax, 0xF09               ; set the value of CTRC register 9 (the minimum scan line register) to 0xF
out dx, ax                  ; set character height to 0xF+1 i.e. 16px
%ifdef FONT
push si                     ; save arbitrary SI
mov ax, 0x1413              ; set the value of CTRC register 0x13 (the offset register) to 0x14
out dx, ax                  ; for some reason this is not necessary without a font, set address offset between lines (chars in line = width/2 = 20) to 0x14
mov si, font                ; make SI point to the font to enable copying
xor di, di                  ; make DI point to start of font segment
mov cx, 0x100               ; copy all 0x100 characters
copy_font:
push cx                     ; save CX
mov cx, 0x10                ; we write only 0x10 byte values each time to move to the next 0x20 byte character section
cs rep movsb                ; move from font location to VGA section
add di, 0x10                ; move to next character section
pop cx                      ; pop CX
loop copy_font              ; copy all characters
mov dl, 0xC4                ; port 0x3C4 writes to the sequencer registers
mov ax, 0x302               ; set the value of sequencer register 2 (the map mask register) to 3
out dx, ax                  ; make font region masked
mov al, 0x4                 ; set the value of sequencer register 4 (the character map select register) to 4
out dx, ax                  ; restore it to make the color-character writing method possible again
pop si                      ; restore SI
%endif

mov ch, 0x3B                ; override initial CX so that in initial screen clearing the entire buffer will be cleared
start:                      ; reset game
    mov ax, 0x720           ; fill the screen with word 0x720 (white on black space)
    add ch, 0x5             ; add 0x500 to initial CX (0xFFFF) to write 0x4FF words (a little more then the screen)
    xor di, di              ; start writing at the start of the screen
    rep stosw               ; clear the screen
    dec cx                  ; set CX to 0xFFFF again
    mov di, [bx]            ; reset head position, BX always points to a valid screen position containing 0x720 after setting video mode
    lea sp, [bp+si]         ; set stack pointer (tail) to current head pointer
.food:                      ; create new food item
%ifdef V86
    push di                 ; save old DI before overwriting for randomization
.rand:                      ; lots of code to randomize food positions is better than initializing the PIT chip
    xchg di, bx             ; alternate BX between head position (not to iterate over the same food locations) and the end of the screen
    dec bh                  ; decreasing BH for randomization ensures BX is still divisble by 2 and if the snake isn't filling all the possible options, below 0x7D0
    xor [bx], cl            ; place food item and check if position was empty by applying XOR with CL (assumed to be 0xFF)
    jp .rand                ; if position was occupied by snake or wall in food generation => try again, if we came from main loop PF=0
    pop di                  ; restore actual head position
%else
    in ax, 0x40             ; read 16 bit timer counter into AX for randomization
    and bx, ax              ; mask with BX to make divisible by 4 and less than or equal to screen size
    xor [bx], cl            ; place food item and check if position was empty by applying XOR with CL (assumed to be 0xFF)
%endif
.input:                     ; handle keyboard input
    mov bx, 0x7D0           ; initialize BX to screen size (40x25x2 bytes)
    jp .food                ; if position was occupied by snake or wall in food generation => try again, if we came from main loop PF=0
.move:                      ; dummy label for jumping back to input evaluation
    in al, 0x60             ; read scancode from keyboard controller - bit 7 is set in case key was released
%ifdef NONUMPAD
    cmp al, 0xE0            ; if AL is the byte appended when using the keypad
    je .move                ; ignore it
%endif
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
%ifdef SLOW
mov cx, 0x5000              ; set outer slow-down loop counter
.slow:
    push cx                 ; push CX to do 2 loops
    loop $                  ; the inner empty loop
    pop cx                  ; pop CX to use it in outer loop for more slow down
    loop .slow              ; do outer loop
    dec cx                  ; set CL=0xFF back
%endif
.wall:                      ; draw an invisible wall on the left side
    mov [bx], cl            ; store wall character
    sub bx, BYTE 0x50       ; go one line backwards
    jns .wall               ; jump to draw the next wall
    pop bx                  ; no food was consumed so pop tail position into BX
    mov [bx], ah            ; clear old tail position on screen
    jnp .input              ; loop to keyboard input, PF=0 from SUB

%ifdef FONT
font: incbin "CP437.F16"    ; include the font
%endif

%ifdef V86
times ($$-$+0xFFFC) db 0x00 ; fill with zeros
nop                         ; this is only required because of a V86 bug (https://github.com/copy/v86/issues/1253)
jmp $$                      ; so I'll ignore this section for now but will remove it when the bug is fixed
%else
times (0x10000+$$-$) db 0x0 ; fill the rest with zeros as the BIOS needs to be 0x10000 bytes
%endif
