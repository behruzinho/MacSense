import XCTest
@testable import MacSenseCore

final class LocalizationTests: XCTestCase {
    func testEveryLanguageContainsAllTranslationsAndMatchingArguments() {
        let base = L10n.translations(language: "ru")
        XCTAssertGreaterThan(base.count, 300)
        for language in ["en", "zh-Hans", "es", "de"] {
            let translations = L10n.translations(language: language)
            XCTAssertEqual(Set(translations.keys), Set(base.keys), "Missing keys in \(language)")
            for (key, value) in translations {
                XCTAssertFalse(value.isEmpty, "Empty translation: \(language), \(key)")
                XCTAssertEqual(key.components(separatedBy: "%@").count, value.components(separatedBy: "%@").count, "Arguments differ: \(language), \(key)")
            }
        }
    }
    func testLanguageResolutionAndFallback() {
        XCTAssertEqual(L10n.resolve("zh-TW"), "zh-Hans")
        XCTAssertEqual(L10n.resolve("en-GB"), "en")
        XCTAssertEqual(L10n.resolve("de-DE"), "de")
        XCTAssertEqual(L10n.resolve("fr-FR"), "en")
        XCTAssertEqual(L10n.translate("Батарея", language: "en"), "Battery")
        XCTAssertEqual(L10n.translate("Батарея", language: "zh-Hans"), "电池")
        XCTAssertEqual(L10n.translate("Батарея", language: "es"), "Batería")
        XCTAssertEqual(L10n.translate("Батарея", language: "de"), "Batterie")
        XCTAssertEqual(L10n.translate("MacSense", language: "de"), "MacSense")
    }
    func testInterpolationSeparatesValuesFromKeys() {
        let version = "1.2.3"
        let message: LocalizedMessage = "Версия \(version)"
        XCTAssertEqual(message.key, "Версия %@")
        XCTAssertEqual(message.arguments, [version])
        let template = L10n.translate(message.key, language: "en")
        XCTAssertEqual(String(format: template, arguments: message.arguments), "Version 1.2.3")
    }
}
