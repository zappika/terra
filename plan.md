# TERRA: the little compass we can actually build

## The idea

On an iPhone, search for an address, look at a walking route, and tap **Send to TERRA**. Put the phone away. TERRA uses its own GPS and compass to guide the walk with a simple arrow, distance, and quiet vibrations. Later, the app can also invent a walk from a prompt such as “a calm 30-minute loop with trees.”

The [original TERRA project](https://github.com/modem-works/terra) is our visual and hardware inspiration. Its code and assembly guide are useful references, but it is an experimental 2024 prototype. We will build in small pieces and verify each one outdoors.

The native iPhone app has its own [v1 build spec](app-v1-spec.md). Its first interface uses standard iOS controls.

The device's round screen can be rehearsed before the electronics arrive with a [small route simulator](device-sim-spec.md) driven by the same route JSON the iPhone app exports.

## The chapters

### 1. Build TERRA without its case

Get the ESP32, round display, GPS, compass, haptic driver, and vibration motor working together on the desk, powered over USB. Start on a breadboard with plug-in cables where possible, then solder the connections that need to survive being carried. First make the screen light up, then turn an arrow by rotating the compass, then show a fresh GPS position and feel a vibration. This is the real device; it simply has no body yet. The reward is holding a working bundle of electronics that responds to the world.

### 2. The first outdoor arrow

Load one destination into the device for testing. Outdoors, TERRA waits for a fresh GPS fix, points toward that destination, shows distance, and makes GPS uncertainty clear. Walk a short familiar route with the phone available as backup. The reward is following *our* hardware to a real place. A single destination is only a navigation experiment; mapped walking paths come next.

### 3. A route on the phone

Build a small SwiftUI app: search an address, show walking directions from the current location, and display distance and estimated time. Use MapKit for the first version. The reward is seeing the route TERRA will eventually carry.

### 4. The handoff and the first complete walk

The iPhone connects to TERRA over Bluetooth Low Energy. First send a tiny test message; then send a simplified walking route with turn points. TERRA confirms **Route received** and saves it so the phone can disconnect. On the walk, it guides along the route, vibrates near turns, and shows when we drift off course. It does not need internet during the walk. The reward is searching an address on the phone, putting it away, and arriving with TERRA.

### 5. A body for it

Measure the working electronics and make a rough fit print with Pierre on his Bambu Lab A1 filament printer. Start with a simple PLA fit test; once the dimensions and button placement work, try a translucent PETG shell so the electronics glow through it. Expect a frosted, layered look rather than glass clarity. The [original case files](https://github.com/modem-works/terra/tree/main/STL%20Files) were designed for resin and SLS printing, so we will use them as a shape reference and adapt the design for filament printing. The reward is a pocketable object rather than a bundle of wires.

### 6. Wandering mode

Once address navigation works, add “surprise me”: choose a duration and mood, get a loop back to the start, preview it, and send it to TERRA. A current model can help choose the *kind* of walk or interesting stops. A walking route service must connect those stops on mapped paths and check the actual distance. The model does not invent navigation coordinates by itself.

## Shopping

**The electronics prototype is the real device without a case. Get these parts together once we have checked local stock and chosen compatible versions:**

- [ESP32 Feather V2](https://www.adafruit.com/product/5400), preferably with headers if available locally.
- [Waveshare 1.28-inch round GC9A01 display](https://www.waveshare.com/1.28inch-LCD-Module.htm), matching the original project's screen.
- GPS: the original BN-880 or a compact UART/I²C module such as the [PA1010D](https://www.adafruit.com/product/4415).
- Compass: the original CMPS12 or a more available magnetometer/IMU. A [LIS3MDL](https://www.adafruit.com/product/4479) is a good learning part, though a final pocket device may benefit from tilt compensation.
- [DRV2605L haptic driver](https://www.adafruit.com/product/2305) **and a vibration motor**; the driver alone cannot vibrate.
- A small solderless breadboard, jumper wires, a USB-C data cable, and the right STEMMA QT/Qwiic cables or adapters. Check what comes with the parts before ordering extras.
- A temperature-controlled soldering iron, solder, and a stand; borrow the iron from Pierre if possible. Breadboard connections help us learn, but the device will eventually need secure joints.

**Choose after the electronics work:**

- Battery and power button only after we have measured current draw and settled the case layout. Match battery connector polarity to the board.
- Translucent PETG for the final shell, after a small sample print confirms the look; no need to buy a full spool for the first fit test if Pierre has PLA.

Part numbers can change with stock. We choose by function, voltage, interface, size, and library support; then update the wiring and code to match what we can actually obtain. We will check EU suppliers before placing an order.

## What counts as version one

Search an address on iPhone, preview a walkable route, send it to TERRA, disconnect the phone, and finish a short outdoor walk using TERRA's arrow and haptics. It should make GPS uncertainty and off-route situations clear. New route calculation after a wrong turn, a polished case, and AI wandering can follow once that walk works reliably.

## This weekend

Walk to an address and note three moments when an arrow, distance, or vibration would have helped. Pierre has a Bambu Lab A1 filament printer; ask whether he has PLA or PETG on hand and whether we can borrow a soldering iron. Check local stock for the complete electronics list. The iPhone development setup is already ready.
