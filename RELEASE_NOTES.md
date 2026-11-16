MacSense 0.3.0 — public release

A native macOS system monitor by [behruzinho](https://github.com/behruzinho).

### Download and install

**[Download MacSense-arm64.dmg](https://github.com/behruzinho/MacSense/releases/download/v0.3.0/MacSense-arm64.dmg)** · [ZIP](https://github.com/behruzinho/MacSense/releases/download/v0.3.0/MacSense-0.3.0-arm64.zip) · [SHA-256 checksums](https://github.com/behruzinho/MacSense/releases/download/v0.3.0/MacSense-0.3.0-arm64-SHA256SUMS.txt)

**Intel:** [MacSense-x86_64.dmg](https://github.com/behruzinho/MacSense/releases/download/v0.3.0/MacSense-x86_64.dmg) · [ZIP](https://github.com/behruzinho/MacSense/releases/download/v0.3.0/MacSense-0.3.0-x86_64.zip) · [SHA-256 checksums](https://github.com/behruzinho/MacSense/releases/download/v0.3.0/MacSense-0.3.0-x86_64-SHA256SUMS.txt)

**macOS 14+.** Choose **MacSense-arm64.dmg** for Apple Silicon or **MacSense-x86_64.dmg** for Intel. Open the DMG, drag **MacSense.app** into **Applications**, then launch it from Applications.

An Intel (x86_64) build passed 23 automated tests and a diagnostic launch through Rosetta on Apple Silicon. Physical Intel Mac validation is still pending.

The main Apple Silicon DMG keeps the filename **MacSense-arm64.dmg**. Versioned DMGs, ZIPs containing the stapled apps, and checksums are attached for both architectures.

### What changed

- **English on first launch.** New installations start in English. Existing language selections are preserved, and all five app languages remain available in Settings → Language and appearance.
- **Settings title localization fixed.** The native Settings window title now changes with the app language immediately and stays correct when the window is reopened.
- **Separate Intel download.** A signed and notarized x86_64 build is available as **MacSense-x86_64.dmg**.
- **Stable installer filename.** The main download is **MacSense-arm64.dmg**, with SHA-256 checksums for all downloadable packages.

### Что нового

- Английский язык по умолчанию при первом запуске; сохранённый выбор языка учитывается.
- Заголовок окна настроек переключается вместе с языком интерфейса без перезапуска и остаётся правильным после повторного открытия.
- Добавлена подписанная и проверенная Apple Intel-сборка **MacSense-x86_64.dmg**.
- Основной установщик для Apple Silicon называется **MacSense-arm64.dmg**. Также доступны ZIP, DMG с номером версии и контрольные суммы SHA-256.

### Signing and verification

**Signed and notarized by Apple.** Developer ID Application: Behruz Numonov (J7PWR289L2), hardened runtime and secure timestamps. Apple accepted the apps and DMGs for both arm64 and x86_64; tickets are stapled and validated. Gatekeeper accepts both architectures as `Notarized Developer ID`. Each ZIP includes the stapled app.

Validation: 23 automated tests on Apple Silicon and the same 23 tests for x86_64 through Rosetta, all five languages, release build, signatures, Apple tickets, Gatekeeper, DMG integrity, SHA-256 checksums, and matching version/architecture/executable in the app, ZIP and DMG. The default language and live Settings title changes were checked in the UI.

Telemetry stays on your Mac. No automatic cleanup runs; files move to Trash only after selection and confirmation.

[Source (v0.3.0)](https://github.com/behruzinho/MacSense/tree/v0.3.0) · [README](https://github.com/behruzinho/MacSense/blob/main/README.md) · [MIT license](https://github.com/behruzinho/MacSense/blob/v0.3.0/LICENSE)
