window.onload = function() {
    var startX, startY;

    const emulator = new V86({
        wasm_path: "./v86.wasm",
        screen_container: document.getElementById("screen_container"),
        bios: {
            url: "bios.raw",
        },
        disable_mouse: true,
    });

    emulator.add_listener("emulator-ready", () => setInterval(emulator.v86.cpu.cycle_internal, 100));

    document.addEventListener("touchstart", function(e) {
        startX = e.changedTouches[0].pageX;
        startY = e.changedTouches[0].pageY;
    }, false);

    document.addEventListener("touchend", function(e) {
        let key;
        const distX = e.changedTouches[0].pageX - startX;
        const distY = e.changedTouches[0].pageY - startY;

        if (distX >= 100) key = 0x4D;
        else if (distX <= -100) key = 0x4B;
        else if (distY >= 100) key = 0x50;
        else if (distY <= -100) key = 0x48;

        if (key) emulator.keyboard_send_scancodes([key]);
    }, false);
}

