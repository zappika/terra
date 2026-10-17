# TERRA: the little compass we can actually build

## The idea

On an iPhone, search for an address, look at a walking route, and tap **Send to TERRA**. Put the phone away. TERRA uses its own GPS and compass to guide the walk with a simple arrow, distance, and quiet vibrations. Later, the app can also invent a walk from a prompt such as “a calm 30-minute loop with trees.”

The [original TERRA project](https://github.com/modem-works/terra) is our visual and hardware inspiration. Its code and assembly guide are useful references, but it is an experimental 2024 prototype. We will build in small pieces and verify each one outdoors.

## The chapters

### 1. A route on the phone

Build a small SwiftUI app: search an address, show walking directions from the current location, and display distance and estimated time. Use MapKit for the first version. The reward is seeing *our* TERRA route on a map, even before hardware arrives.

### 2. An arrow on the desk

Power an ESP32 Feather V2 over USB and light the round display. Make an arrow turn using test data. Add a compass and rotate the device to see the arrow hold its direction. This is where we learn wiring, the display, I²C sensors, and compass calibration.

### 3. The first handoff

The iPhone connects to TERRA over Bluetooth Low Energy. First send a tiny test message; then send a route. TERRA confirms **Route received** and saves it so the phone can disconnect. We will send a simplified route with turn points, not a huge raw map file. The reward is putting the phone away after the handoff.

### 4. The first real walk

Add GPS and haptics. Outdoors, TERRA waits for a fresh GPS fix, points toward the next part of the walking route, warns before a turn, and shows when we drift off course. It does not need internet during the walk. Our first field test is one familiar, short route with the phone available as backup. The reward is arriving at the searched address using TERRA.

### 5. A body for it

Measure the working electronics and make a rough fit print with Pierre. Adjust the case for his printer, then add a suitable battery, button, and charging access. The [original case files](https://github.com/modem-works/terra/tree/main/STL%20Files) were designed for resin and SLS printing, so a filament printer may call for a revised design. The reward is a pocketable object rather than a bundle of wires.

### 6. Wandering mode

Once address navigation works, add “surprise me”: choose a duration and mood, get a loop back to the start, preview it, and send it to TERRA. A current model can help choose the *kind* of walk or interesting stops. A walking route service must connect those stops on mapped paths and check the actual distance. The model does not invent navigation coordinates by itself.

## Shopping, in two small rounds

**Buy for the desk prototype now:**

- [ESP32 Feather V2](https://www.adafruit.com/product/5400), preferably with headers if available locally.
- [Waveshare 1.28-inch round GC9A01 display](https://www.waveshare.com/1.28inch-LCD-Module.htm), matching the original project's screen.
- A small solderless breadboard, jumper wires, a USB-C data cable, and a few STEMMA QT/Qwiic cables. Check which headers and cables come with the parts before ordering extras.

**Choose next, after checking local stock and how we want the device to fit:**

- GPS: the original BN-880 or a compact UART/I²C module such as the [PA1010D](https://www.adafruit.com/product/4415).
- Compass: the original CMPS12 or a more available magnetometer/IMU. A [LIS3MDL](https://www.adafruit.com/product/4479) is a good learning part, though a final pocket device may benefit from tilt compensation.
- [DRV2605L haptic driver](https://www.adafruit.com/product/2305) **and a vibration motor**; the driver alone cannot vibrate.
- Battery and power button only after we have measured current draw and settled the case layout. Match battery connector polarity to the board.

Part numbers can change with stock. We choose by function, voltage, interface, size, and library support; then update the wiring and code to match what we can actually obtain. We will check EU suppliers before placing an order.

## What counts as version one

Search an address on iPhone, preview a walkable route, send it to TERRA, disconnect the phone, and finish a short outdoor walk using TERRA's arrow and haptics. It should make GPS uncertainty and off-route situations clear. New route calculation after a wrong turn, a polished case, and AI wandering can follow once that walk works reliably.

## This weekend

Walk to an address and note three moments when an arrow, distance, or vibration would have helped. Ask Pierre what printer he has. Check local stock for the first shopping round. The iPhone development setup is already ready.
