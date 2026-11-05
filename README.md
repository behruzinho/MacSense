<p align="center">
  <img src="Resources/AppIcon.iconset/icon_128x128.png" width="96" alt="MacSense icon">
</p>

<h1 align="center">MacSense</h1>
<p align="center">A native macOS system monitor. Your Mac, at a glance.</p>
<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black.svg" alt="macOS 14 or newer">
  <img src="https://img.shields.io/badge/Swift-5.10%2B-orange.svg" alt="Swift 5.10 or newer">
</p>
<p align="center">
  <a href="README.ru.md">Русский</a> · <a href="https://github.com/behruzinho/MacSense/releases">Downloads</a> · <a href="https://github.com/behruzinho/MacSense/issues">Report an issue</a>
</p>

MacSense brings CPU, memory, GPU, battery, storage, network, temperatures, and fan speeds into one native SwiftUI dashboard. Metrics come from your Mac through Mach, IOKit, AppleSMC, and system tools. There are no third-party runtime dependencies or analytics.

Created by **[behruzinho](https://github.com/behruzinho)**.

## Download and install

Download **MacSense-0.1.0-arm64.dmg** from [Releases](https://github.com/behruzinho/MacSense/releases). Open the disk image and drag **MacSense.app** to **Applications**. A ZIP containing the same app and SHA-256 checksums are also provided.

**Requirements:** macOS 14 or newer. The initial binary is for **Apple Silicon (arm64)**. Intel users can build from source; this release does not include a tested Intel binary.

**First public preview:** the app is ad-hoc signed and **not notarized by Apple**. macOS may block its first launch. Review [Apple’s guidance for opening an app you trust](https://support.apple.com/102445); keep Gatekeeper enabled. Developer ID signing and notarization are planned for a future release.

## Features

| Area | Available information |
| --- | --- |
| Dashboard | Live overview with compact charts and hardware details |
| CPU | Interval load, per-core usage, user/system split, active processes |
| Memory | Physical usage, wired and compressed memory, file cache, pressure, swap |
| Battery | Charge, health estimate, cycles, capacity, temperature, voltage, current, power |
| Cooling | Read-only SMC fan RPM and temperature sensors |
| Graphics | GPU identity, core count, available utilization and temperature |
| Storage | Mounted volume usage, available NVMe model, S.M.A.R.T. and TRIM status |
| Network | Receive/send rates and 64-bit interface counters |
| Applications | Installed apps, sizes, and related files matched by exact bundle ID |
| Cleanup | User caches and logs, with file selection and a confirmation before moving to Trash |
| Startup | LaunchAgents/LaunchDaemons configuration viewer and macOS login-item settings |
| Extras | Menu bar CPU monitor, themes, refresh intervals, pause, text report export |

## Languages

Switch languages in **Settings → Language and appearance**, without restarting:

- Русский — Russian
- English
- 简体中文 — Simplified Chinese
- Español — Spanish
- Deutsch — German

Labels, messages, confirmation dialogs, reports, dates, and units follow the selected language. System-generated macOS menus and window titles may follow the system language.

## Privacy and file operations

Telemetry is processed locally. MacSense does not upload hardware details, process lists, or file inventories. Profile and support links open in your browser when clicked.

The cleanup scanner reads only `~/Library/Caches` and `~/Library/Logs`. The uninstaller scans top-level `.app` bundles in `/Applications` and `~/Applications`; related files are matched by exact bundle identifier. Shared developer folders and unknown leftovers are excluded. No automatic cleanup runs. Selected files are moved to Trash only after confirmation.

Directory-size scans have a time limit; **≥** indicates a partial size. Some protected folders may not be accessible.

## Current limits

- Sensor, GPU, NVMe, S.M.A.R.T., and TRIM data depend on the Mac model and macOS version. Unavailable readings are shown explicitly.
- Unknown temperature sensors retain their original SMC key; exact locations vary between models. CPU temperature is the average of the matched CPU sensor group.
- macOS controls fan speeds. Manual fan control and changing TRIM settings are not included.
- The startup screen shows discovered configuration files, not the live enabled state of every service.
- The process list contains up to 80 processes sorted by CPU activity; memory is RSS. It is not a complete Activity Monitor replacement.
- Disk benchmarking, privileged helpers, automatic updates, and Apple notarization are not included in this preview.

## Build from source

Install Xcode or the Xcode Command Line Tools with **Swift 5.10+**:

```sh
git clone https://github.com/behruzinho/MacSense.git
cd MacSense
./script/build_and_run.sh
```

The script builds, stages, signs, and opens `dist/MacSense.app`.

```sh
swift test                              # telemetry, file boundaries, localization checks
./script/build_and_run.sh --build        # build the .app without launching
./script/build_and_run.sh --verify       # build, launch, check the process
./script/build_and_run.sh --debug        # launch with LLDB
./script/build_and_run.sh --logs         # launch and stream logs
./script/package_release.sh             # optimized .app, DMG, ZIP, checksums
```

Read-only diagnostics:

```sh
./dist/MacSense.app/Contents/MacOS/MacSense --diagnostics
```

To cross-build, set `MACSENSE_ARCH=arm64` or `MACSENSE_ARCH=x86_64`. Build success does not replace testing on the target hardware.

Optional release configuration:

```sh
MACSENSE_SUPPORT_URL='https://your-verified-support-page.example' ./script/package_release.sh
```

A real HTTPS support URL enables the coffee button. It is written to `MacSenseSupportURL` in the generated Info.plist. The app contains no payment credentials or embedded checkout. Until a page is configured, the button remains disabled.

If a Developer ID certificate is available, `MACSENSE_SIGN_IDENTITY` selects it and enables hardened runtime signing. Notarization and stapling must be completed separately before claiming an Apple-notarized release.

## Project layout

```text
Sources/TelemetryBridge/      C bridge to Mach, IOKit, AppleSMC, network counters
Sources/MacSenseCore/         Models, telemetry, file scanning, localization resources
Sources/MacSense/             SwiftUI app, state store, views, presentation helpers
Tests/MacSenseCoreTests/      Calculation, file policy, and localization checks
Resources/                   App icon and source icon images
script/                      Build, run, icon generation, and release packaging
```

## Contributing

Bug reports and pull requests are welcome. For sensor issues, include your Mac model, macOS version, and the affected sensor key. Remove personal information before sharing diagnostic output. Run `swift test` and build the app before submitting a change.

## Support and credits

Thanks to **[behruzinho](https://github.com/behruzinho)** for the idea and creation of MacSense. A “Buy me a coffee” button is included in the About window and Settings; the payment page has not been connected yet.

The interface is inspired by desktop system monitors such as [Sensei](https://cindori.com/sensei). MacSense is an independent project with its own implementation and assets.

## License

[MIT](LICENSE) © 2026 [behruzinho](https://github.com/behruzinho).
