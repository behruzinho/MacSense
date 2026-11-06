# Changelog

## 0.2.0 — 2026-11-06

- Preserved the existing dashboard design; added startup disk, chip, memory, OS/build and masked serial to the Mac banner.
- Physical disks and APFS hierarchy, read/write history, bounded cancellable disk benchmark.
- Optional detailed NVMe SMART via separately installed smartctl; no fabricated SSD health readings.
- Battery metadata and Metal capabilities with correct unified-memory labels.
- Grouped app-related files, exact-ID containers/scripts, total sizes and batch selection.
- Categorized cleanup for developer data and downloads, progress/cancellation and read-only system/simulator categories.
- Configurable monitor panels, ordering, single-column layout and selectable menu bar metric.
- Actual launchd state, confirmed user-agent permissions and MacSense launch at login.
- Five-language localization and parser, file-policy, cancellation and configuration tests.

- Refined Mac banner spacing and enlarged hardware badges.
- Designed Retina DMG installer with app-to-Applications layout and bilingual instructions.
- Removed the unconfigured support-page caption from Settings and About.

Distribution: Developer ID signed and notarized by Apple, Apple Silicon (arm64), macOS 14+. On 2026-11-06 the downloads were refreshed with stapled Apple tickets and updated SHA-256 checksums; the executable and version are unchanged.

## 0.1.0 — 2026-11-05

First public preview.

- Native dashboard for CPU, memory, GPU, battery, network, storage, and cooling.
- Per-core CPU readings, process list, memory pressure, and swap.
- Battery capacity, health, cycles, temperature, and power readings.
- Read-only SMC fan speeds and temperature sensors.
- Application and user cache scanning with reviewed moves to Trash.
- Startup configuration viewer and macOS Settings shortcuts.
- Russian, English, Simplified Chinese, Spanish, and German.
- Menu bar monitor, appearance settings, refresh controls, and text reports.
- Author link and a coffee support button, inactive until a real payment page is configured.

### Distribution

Initial download: Apple Silicon (arm64), macOS 14+. Developer ID signing and Apple notarization scripts are included; see the release notes for the download’s verification status.
Intel builds can be made from source; no Intel binary is included in this release.
