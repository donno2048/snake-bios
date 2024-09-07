# snake-bios

A snake game made entirely in the BIOS.

Based on my [other snake game](https://github.com/donno2048/snake).

It's 114 bytes including all the code used to initialize the hardware (the rest of the BIOS is filled with zeros).

## Compile

```sh
nasm bios.asm -o snake.raw
```

## Run

```sh
qemu-system-i386 -display curses -bios snake.raw -plugin contrib/plugins/libips.so,ips=2000
```

The game will take some time to initialize the hardware, then you just need to use the numpad arrows to control the snake movement.

If you don't have a numpad you can compile with

```sh
nasm bios.asm -o snake.raw -D NONUMPAD
```

And then use the keypad.

Here it is as a QR Code (made with `qrencode -r <(sed 's/\x00*$//' snake.raw) -8 -o qr.png`)

![](./qr.png)
