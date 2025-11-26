# snake-bios

A snake game made entirely in the BIOS.

Based on my [other snake game](https://github.com/donno2048/snake).

It's `110` bytes including all the code used to initialize the hardware (the rest of the BIOS is filled with zeros).

## Running

I can't show a demo using QEMU because I couldn't find any online tool to imitate QEMU.

That's why I'm using the [V86](https://github.com/copy/v86) x86 emulator.

However, when making this game I found a couple of differences between what QEMU and V86 require.

I didn't want to take the easy route so that's why the code is filled with those `%ifdef QEMU` and `%ifdef V86`.

This makes it possible to compile for QEMU compatibillity, V86 compatibillity or both.

### Online demo

The V86 version of the BIOS is `109` bytes (ignoring the last 4 bytes because we need them just because of a V86 bug as detailed in the comments).

You can try the game in the [online demo](https://donno2048.github.io/snake-bios/).

Use the arrow keys on PC or swipe on mobile.

The [`libv86`](./v86/libv86.js) and [`v86`](./v86/v86.wasm) are genrated like so:

```sh
cd v86
git clone --depth 1 https://github.com/donno2048/v86
cd v86
make all
cp build/libv86.js build/v86.wasm ..
cd ..
rm -rf v86
```

### Self-hosting

### Compiling

We're compiling for QEMU only so use `-D QEMU`.

```sh
nasm bios.asm -o snake.raw -D QEMU
```

### Run

```sh
qemu-system-i386 -display curses -bios snake.raw -plugin contrib/plugins/libips.so,ips=2000
```

For some reason the ips plugin doesn't come with QEMU so we have to build QEMU from source to use it:

```sh
git clone --branch stable-9.2 --depth 1 https://github.com/qemu/qemu
cd qemu
./configure --target-list=i386-softmmu --enable-curses --enable-plugins --disable-docs
make all
ls build/
```

You might need to install QEMU build dependencies:

```sh
apt install gcc libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja-build qemu libncurses5-dev libncursesw5-dev python3-venv python3-pip -y
pip3 install tomli
```

The game will take some time to initialize the hardware, then you just need to use the numpad arrows to control the snake movement.

If you don't have a numpad you can compile with

```sh
nasm bios.asm -o snake.raw -D NONUMPAD
```

And then use the keypad.

If you don't want to use the QEMU ips plugin, or just want to slow the game down you can use:

```sh
nasm bios.asm -o snake.raw -D SLOW
```

To run the game in QEMU with standard graphics we have to include a font, as QEMU doesn't have in built-in.

I'm using [CP437.F16](./CP437.F16), which was taken from https://github.com/viler-int10h/vga-text-mode-fonts

To compile using the font use:

```sh
nasm bios.asm -o snake.raw -D FONT
```

## QR Code

Here is the game as a QR Code (made with `qrencode -r <(sed 's/\x00*$//' snake.raw) -8 -o qr.png`)

![](./qr.png)
