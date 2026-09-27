# OpenTaskbar

![macOS](https://img.shields.io/badge/macOS-13%20%7C%2014%20%7C%2015-000000.svg?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-FA7343.svg?logo=swift&logoColor=white)
![AppKit](https://img.shields.io/badge/UI-AppKit-1f6feb.svg)
![Version](https://img.shields.io/badge/Version-1.0.0-success.svg)
![License](https://img.shields.io/badge/License-MIT-orange.svg)

A native Windows 10-style taskbar for macOS. OpenTaskbar renders a bottom-docked bar with a Start button, running-app buttons, a system tray, and a clock — all drawn in Swift/AppKit. Every dimension, spacing, and animation timing is measured from the real Windows 10 shell. No Electron, no web view, no helper processes. Everything runs locally as a single app, and all data stays in plain files under your user profile.

![OpenTaskbar showing a Windows 10-style taskbar at the bottom of a macOS desktop](screens/open-taskbar-demo.png)

## Summary

OpenTaskbar puts a pixel-accurate Windows 10 taskbar on your Mac, with:

- 🪟 **Windows 10 taskbar, natively**: Start button, app buttons, tray, and clock rendered in Swift/AppKit
- 📐 **Pixel-accurate**: every dimension, spacing, and animation timing is measured from Windows 10 and documented
- 🖥️ **Native Swift package**: a single `OpenTaskbar.app` with no dependencies beyond the system frameworks
- 🧪 **Snapshot-tested**: UI renders are verified against reference snapshots at 1× and 2×
- 🔒 **Local only**: no network, no accounts, no telemetry — settings are a plist and a folder in your user profile

## Download

Grab the latest release from the [Releases](https://github.com/lso2/OpenTaskbar/releases) page.

1. Download `OpenTaskbar.app.zip`
2. Unzip and drag `OpenTaskbar.app` into your **Applications** folder
3. Open it from Launchpad or Spotlight
4. Grant the requested permissions (Accessibility, Screen Recording) in **System Settings → Privacy & Security**

## Requirements

- **macOS 13+** (Ventura or later)

## Settings and data

All state lives in plain files under your user profile:

| What | Where |
|---|---|
| Bar settings (layout, height, theme, …) | `~/Library/Preferences/com.plexpixel.OpenTaskbar.plist`, key `barSettings` |
| Launcher image | `~/Library/Application Support/OpenTaskbar/` |
| Captured status-item glyphs | `~/Library/Application Support/OpenTaskbar/` |

### Privacy

- **No cloud sync**: everything stays on your computer
- **No accounts**: no login or registration
- **No telemetry**: the app makes no external network requests
- **Readable formats**: a plist and ordinary image files you can inspect or back up

## Logs

Stream debug logs from the running app:

```sh
/usr/bin/log stream --predicate 'subsystem == "com.plexpixel.OpenTaskbar"' --level debug
```

## Documentation

- **Plan & measurements**: [`docs/OpenTaskbar-Plan.md`](../docs/OpenTaskbar-Plan.md) — the full plan, the Windows 10 measurement methodology, and every measurement result
- **Per-file notes**: [`docs/notes/app/`](../docs/notes/app/) — a short design note for each source file

## Building from source

For contributors or those who prefer to build locally:

```sh
git clone https://github.com/lso2/OpenTaskbar.git
cd OpenTaskbar/app
```

Create a development signing identity (once):

```sh
../tools/make-dev-identity.sh
```

Build and run:

```sh
./make-app.sh
open build/OpenTaskbar.app
```

`make-app.sh` signs with a Developer ID identity when the keychain has one, then with the local "OpenTaskbar Development" identity, then ad hoc. Only a stable identity keeps the privacy grants (Accessibility, Screen Recording) across rebuilds.

### Tests

```sh
swift test
```

With snapshot rendering (keeps the 2× renders on disk for visual inspection):

```sh
OPENTASKBAR_SNAPSHOTS=$PWD/.build/snapshots swift test
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes (keep to the existing Swift 5.9 target)
4. Build and test on macOS 13+
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Author

PlexPixel ([plexpixel.com](https://plexpixel.com))

## License

MIT, see the [LICENSE](LICENSE) file for details.

---

**⭐ If OpenTaskbar made your Mac feel more like home, please star the repository!**

## ☕ Buy me a coffee

If OpenTaskbar saves you time every day, consider supporting its development.

[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black)](https://plexpixel.com/donate)

**Why support?**

- ☕ Fuel continued development
- 🚀 New features and modes
- 🐛 Faster fixes and updates
- 📚 Better documentation

---

*Made with ❤️ for people who miss the Windows 10 taskbar on MacOS.*   