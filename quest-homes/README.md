# Quest Homes

A clean-room Meta Quest utility for browsing public community Home APKs and applying Haven2025-compatible NoRoot Homes directly on the headset.

## What v0.1 does

- Runs as a normal 2D Android app on Quest.
- Pairs with the headset's own Wireless ADB connection.
- Keeps the ADB identity on-device, so a phone or PC is not used as a server.
- Loads public NoRoot Home assets from the Quest Home Switcher community release feed.
- Supports search, download, local APK import, backup of the current Haven2025 package, apply, and restore.
- Refuses catalog APKs whose manifest package is not `com.meta.shell.env.footprint.haven2025`.
- Falls back safely: a failed download or invalid APK does not uninstall the current Home.

## First setup

1. Enable Meta Developer Mode for the headset.
2. Open Android Developer options / Wireless debugging on Quest.
3. Tap "Pair device with pairing code".
4. In Quest Homes enter the pairing port, six-digit code, and the normal Wireless debugging connection port.
5. Pair, then Connect/Test.
6. Before the first switch, use "Backup official Home".

After pairing, the app stores its ADB key locally on the Quest. The phone is not part of the runtime path.

## Important

Quest Homes is unofficial. Home/package behavior may change with Horizon OS. Community Home content remains the property of its creators. The community release URLs are used as public download sources; this project does not claim ownership of those APKs.

## License

GPL-3.0-or-later. This is a clean-room implementation and does not copy Quest Home Switcher source code.
