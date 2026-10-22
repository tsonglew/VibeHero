import Foundation
import XCTest
@testable import VibeHero

final class LocalizationTests: XCTestCase {
    func testEveryUIKeyHasAnExplicitNonemptyTranslationInEveryLanguage() {
        for language in AppLanguage.allCases {
            for key in L10nKey.allCases {
                let value = L10n.translation(for: key, language: language)
                XCTAssertNotNil(value, "Missing \(language.rawValue): \(key.rawValue)")
                XCTAssertFalse(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
                               "Empty \(language.rawValue): \(key.rawValue)")
            }
        }
    }

    func testTranslatedFormatArgumentsMatchEnglishIncludingPositionalArguments() throws {
        let pattern = try NSRegularExpression(pattern: #"%(?:(\d+)\$)?[-+0#]*\d*(?:\.\d+)?([@dif])"#)
        func arguments(in text: String) -> Set<String> {
            let text = text.replacingOccurrences(of: "%%", with: "") as NSString
            var nextIndex = 1
            var arguments: Set<String> = []
            for match in pattern.matches(in: text as String, range: NSRange(location: 0, length: text.length)) {
                let index: Int
                if match.range(at: 1).location != NSNotFound {
                    index = Int(text.substring(with: match.range(at: 1)))!
                } else {
                    index = nextIndex
                    nextIndex += 1
                }
                arguments.insert("\(index):\(text.substring(with: match.range(at: 2)))")
            }
            return arguments
        }
        for key in L10nKey.allCases {
            let expected = arguments(in: L10n.translation(for: key, language: .english) ?? "")
            for language in AppLanguage.allCases {
                let actual = arguments(in: L10n.translation(for: key, language: language) ?? "")
                XCTAssertEqual(actual, expected, "Format mismatch \(language.rawValue): \(key.rawValue)")
            }
        }
    }
}
