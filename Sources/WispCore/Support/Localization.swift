import Foundation

/// Keeps dynamic values separate from translatable text (paths and app names stay intact).
public struct LocalizedText: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public let key: String
    public let values: [String]

    public init(stringLiteral value: String) {
        key = value
        values = []
    }

    public init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key
        values = stringInterpolation.values
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var values: [String] = []

        public init(literalCapacity: Int, interpolationCount: Int) {
            key.reserveCapacity(literalCapacity)
            values.reserveCapacity(interpolationCount)
        }

        public mutating func appendLiteral(_ literal: String) { key += literal }

        public mutating func appendInterpolation<T>(_ value: T) {
            key += "{\(values.count)}"
            values.append(String(describing: value))
        }
    }
}

public enum L10n {
    private static let tokenExpression = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)

    public static var pluralSuffix: String { language == "zh-Hans" ? "" : "s" }

    private static let resources: Bundle = {
        if let url = Bundle.main.url(forResource: "Wisp_WispCore", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()

    public static let language: String = {
        let preferences = ProcessInfo.processInfo.environment["WISP_LANGUAGE"].map { [$0] } ?? Locale.preferredLanguages
        return Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: preferences).first ?? "en"
    }()

    private static let bundles: [String: Bundle] = Dictionary(uniqueKeysWithValues: ["en", "zh-Hans"].compactMap { language in
        guard let name = resources.localizations.first(where: { $0.caseInsensitiveCompare(language) == .orderedSame }),
              let bundle = Bundle(url: resources.bundleURL.appendingPathComponent(name + ".lproj")) else { return nil }
        return (language, bundle)
    })

    public static func string(_ key: String, language: String? = nil) -> String {
        let selected = language ?? self.language
        guard let bundle = bundles[selected] else { return key }
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    public static func render(_ text: LocalizedText, language: String? = nil) -> String {
        let translated = string(text.key, language: language)
        guard !text.values.isEmpty else { return translated }
        let source = translated as NSString
        var result = ""
        var offset = 0
        for match in tokenExpression.matches(in: translated, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: offset, length: match.range.location - offset))
            let index = Int(source.substring(with: match.range(at: 1)))!
            result += text.values.indices.contains(index) ? text.values[index] : source.substring(with: match.range)
            offset = NSMaxRange(match.range)
        }
        result += source.substring(from: offset)
        return result
    }
}

public func L(_ text: LocalizedText) -> String { L10n.render(text) }
