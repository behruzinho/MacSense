MacSense 0.2.0 — second public release

A native macOS system monitor by [behruzinho](https://github.com/behruzinho).

### Что нового

- Расширенная карточка Mac: чип, память, загрузочный диск, macOS/сборка и скрытый серийный номер. Улучшены отступы и размеры тегов.
- Физические диски и дерево APFS, графики чтения/записи и отменяемый тест скорости.
- Группы связанных файлов приложений и пакетный выбор. Новые категории очистки, прогресс и отмена сканирования.
- Настройка панелей мониторинга, их порядка и показателя строки меню.
- Фактическое состояние launchd, управление разрешением запуска пользовательских агентов с подтверждением и автозапуск самого MacSense.
- Дополнительные сведения о батарее и Metal. Пять языков: русский, английский, китайский, испанский и немецкий.
- Новое окно DMG: Retina-фон, крупные значки и понятная установка перетаскиванием. Убрана подпись о неподключённой странице поддержки.

### Download and install

**macOS 14+ · Apple Silicon (arm64).** Open the DMG, drag MacSense into Applications, then launch it from Applications. A ZIP containing the same app and SHA-256 checksums are also attached. No tested Intel binary is included.

**Signing:** Developer ID Application: Behruz Numonov (J7PWR289L2), hardened runtime and secure timestamp. **This release is not notarized by Apple**; macOS may ask you to review it before launch. Keep Gatekeeper enabled and follow [Apple’s guidance](https://support.apple.com/102445).

### What changed

Expanded Mac details while preserving the existing dashboard design; physical storage/APFS inspection, live I/O and a cancellable speed test; grouped application removal and categorized cleanup; configurable monitoring panels and menu bar metric; launchd state and user-agent permissions; battery and Metal details; a redesigned drag-to-install DMG.

Detailed NVMe SMART uses an optional, separately installed `smartctl` with device-read permission. Unavailable sensor and SMART values remain unavailable. System-service controls, custom TRIM drivers and manual fan control are not included.

Telemetry stays on your Mac. Files move to Trash only after selection and confirmation; no automatic cleanup runs. Serial numbers are excluded from reports.

Validation: 22 automated checks, localization coverage, release build, Developer ID signatures, DMG/ZIP integrity and SHA-256 verification. Finder installer layout checked on macOS. User files were not deleted and startup services were not changed during validation.

[Source and README](https://github.com/behruzinho/MacSense/tree/v0.2.0) · [Russian checklist](https://github.com/behruzinho/MacSense/blob/v0.2.0/docs/TESTING.ru.md) · [MIT license](https://github.com/behruzinho/MacSense/blob/v0.2.0/LICENSE)
