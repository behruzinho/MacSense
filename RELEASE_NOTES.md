MacSense 0.2.0 — review build (not published)

By [behruzinho](https://github.com/behruzinho). macOS 14+, Apple Silicon arm64.

- Existing dashboard styling with expanded Mac details and hidden serial numbers.
- Physical disks/APFS, live I/O, cancellable scratch-file benchmark.
- Grouped and batch application removal; additional cleanup categories with progress/cancellation.
- Configurable monitoring panels and menu bar metric.
- launchd state and reviewed user-agent controls; launch MacSense at login.
- Battery and Metal details; Russian, English, Simplified Chinese, Spanish and German.

Detailed NVMe SMART uses an optional, separately installed smartctl with device-read permission. System services, simulator deletion, custom TRIM drivers and manual fan control are not included. Unavailable readings remain unavailable.

Files move to Trash only after selection and confirmation. No automatic cleanup runs. Serial numbers are excluded from reports.

Distribution status: Developer ID signing is supported. Apple notarization and manual review are required before this candidate is published. Do not describe this build as notarized until accepted tickets have been stapled and verified.

Manual review: [Russian checklist](docs/TESTING.ru.md). License: MIT.
