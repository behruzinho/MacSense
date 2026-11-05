import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, ru, en, zhHans = "zh-Hans", es, de
    public var id: String { rawValue }
    public var nativeName: String {
        switch self {
        case .system: return L("Как в системе")
        case .ru: return "Русский"
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .es: return "Español"
        case .de: return "Deutsch"
        }
    }
}

/// Keeps interpolation arguments separate from translation keys, including nested expressions.
public struct LocalizedMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public let key: String
    public let arguments: [String]
    public init(stringLiteral value: String) { key = value; arguments = [] }
    public init(stringInterpolation: StringInterpolation) { key = stringInterpolation.key; arguments = stringInterpolation.arguments }
    public struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []
        public init(literalCapacity: Int, interpolationCount: Int) { key.reserveCapacity(literalCapacity); arguments.reserveCapacity(interpolationCount) }
        public mutating func appendLiteral(_ literal: String) { key += literal }
        public mutating func appendInterpolation<T>(_ value: T) { key += "%@"; arguments.append(String(describing: value)) }
    }
}
public func L(_ message: LocalizedMessage) -> String {
    let template = L10n.translate(message.key)
    guard !message.arguments.isEmpty else { return template }
    return String(format: template, locale: L10n.locale, arguments: message.arguments)
}
public enum L10n {
    public static var language: String {
        let saved = UserDefaults.standard.string(forKey: "language") ?? "ru"
        return resolve(saved)
    }
    public static var locale: Locale { Locale(identifier: language) }
    public static func resolve(_ value: String) -> String {
        let candidate = value == "system" ? Locale.preferredLanguages.first ?? "en" : value
        if candidate.hasPrefix("zh") { return "zh-Hans" }
        return ["ru", "en", "es", "de"].first { candidate.hasPrefix($0) } ?? "en"
    }
    private static let bundles: [String: Bundle] = {
        var result: [String: Bundle] = [:]
        for language in ["ru", "en", "zh-Hans", "es", "de"] {
            if let url = Bundle.module.url(forResource: language, withExtension: "lproj") ?? Bundle.module.url(forResource: language.lowercased(), withExtension: "lproj"), let bundle = Bundle(url: url) { result[language] = bundle }
        }
        return result
    }()
    public static func translate(_ key: String, language: String? = nil) -> String {
        let selected = language.map(resolve) ?? self.language
        return bundles[selected]?.localizedString(forKey: key, value: key, table: "Localizable") ?? key
    }
    public static func translations(language: String) -> [String: String] {
        guard let url = bundles[resolve(language)]?.url(forResource: "Localizable", withExtension: "strings"), let data = try? Data(contentsOf: url), let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else { return [:] }
        return values
    }
}
