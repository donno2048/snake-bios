mov ah, 0xa0
mov ds, ax
mov es, ax

mov al, 0x60
out 0x64, al
out 0x60, al

mov dx, 0x3c0
out dx, al

mov dl, 0xc4
mov ax, 0x302
out dx, ax

mov dl, 0xce
mov ax, 0x1005
out dx, ax

mov dl, 0xb4
mov ax, 0x2701
out dx, ax

mov ax, 0x207
out dx, ax

mov ax, 0xf09
out dx, ax

mov ax, 0x8012
out dx, ax

mov ch, 0x3b
mov si, 0x30c5
start:
    mov ax, 0x720
    add ch, 0x5
    xor di, di
    rep stosw
    dec cx
    mov di, [bx]
    lea sp, [bp+si]
.food:
    in ax, 0x40
    and bx, ax
    xor [bx], cl
.input:
    mov bx, 0x7d0
    jp .food
    in al, 0x60
    imul ax, BYTE 0xa
    aam 0x14
    aad 0x44
    cbw
    add di, ax
    cmp di, bx
    lodsw
    adc [di], ah
    jnp start
    mov [bp+si], di
    jz .food
.wall:
    mov [bx], cl
    sub bx, BYTE 0x50
    jns .wall
    pop bx
    mov [bx], ah
    jnp .input
times (0x10000+$$-$) db 0x0
