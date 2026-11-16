MacSense 0.3.0 — public release

A native macOS system monitor by [behruzinho](https://github.com/behruzinho).

### Download and install

**[Download MacSense-arm64.dmg](https://github.com/behruzinho/MacSense/releases/download/v0.3.0/MacSense-arm64.dmg)** · [ZIP](https://github.com/behruzinho/MacSense/releases/download/v0.3.0/MacSense-0.3.0-arm64.zip) · [SHA-256 checksums](https://github.com/behruzinho/MacSense/releases/download/v0.3.0/MacSense-0.3.0-arm64-SHA256SUMS.txt)

**macOS 14+ · Apple Silicon (arm64).** Open **MacSense-arm64.dmg**, drag **MacSense.app** into **Applications**, then launch it from Applications.

An Intel (x86_64) build passed 23 automated tests and a diagnostic launch through Rosetta on Apple Silicon. It is awaiting notarization before being added to the downloads; physical Intel Mac validation is still pending.

The main Apple Silicon DMG keeps the filename **MacSense-arm64.dmg**. A versioned copy of the same DMG, a ZIP containing the stapled app, and checksums are also attached.

### What changed

- **English on first launch.** New installations start in English. Existing language selections are preserved, and all five app languages remain available in Settings → Language and appearance.
- **Settings title localization fixed.** The native Settings window title now changes with the app language immediately and stays correct when the window is reopened.
- **Stable installer filename.** The main download is **MacSense-arm64.dmg**, with SHA-256 checksums for all downloadable packages.

### Что нового

- Английский язык по умолчанию при первом запуске; сохранённый выбор языка учитывается.
- Заголовок окна настроек переключается вместе с языком интерфейса без перезапуска и остаётся правильным после повторного открытия.
- Основной установщик для Apple Silicon называется **MacSense-arm64.dmg**. Также доступны ZIP, DMG с номером версии и контрольные суммы SHA-256.

### Signing and verification

**Signed and notarized by Apple.** Developer ID Application: Behruz Numonov (J7PWR289L2), hardened runtime and secure timestamps. Apple accepted both the arm64 app and DMG; tickets are stapled and validated. Gatekeeper accepts the app and disk image as `Notarized Developer ID`. The ZIP includes the stapled app.

Validation: 23 automated tests on Apple Silicon, all five languages, release build, signatures, Apple tickets, Gatekeeper, DMG integrity, SHA-256 checksums, and matching version/architecture/executable in the app, ZIP and DMG. The default language and live Settings title changes were checked in the UI.

Telemetry stays on your Mac. No automatic cleanup runs; files move to Trash only after selection and confirmation.

[Source (v0.3.0)](https://github.com/behruzinho/MacSense/tree/v0.3.0) · [README](https://github.com/behruzinho/MacSense/blob/main/README.md) · [MIT license](https://github.com/behruzinho/MacSense/blob/v0.3.0/LICENSE)
