import AppKit
import Foundation
import Testing

@Suite("Localization resources")
struct LocalizationTests {
  @Test("English and Japanese provide the same non-empty keys and format placeholders")
  func completeKeySet() throws {
    let english = try localization("en")
    let japanese = try localization("ja")

    #expect(Set(english.keys) == Set(japanese.keys))
    #expect(english.count == 40)
    for key in english.keys {
      let englishValue = try #require(english[key])
      let japaneseValue = try #require(japanese[key])
      #expect(!englishValue.isEmpty)
      #expect(!japaneseValue.isEmpty)
      #expect(formatSpecifiers(in: englishValue) == formatSpecifiers(in: japaneseValue))
    }
  }

  @Test("English is the fallback copy and contains no Japanese text")
  func englishFallbackCopy() throws {
    let english = try localization("en")
    for value in english.values {
      #expect(!containsJapaneseText(value))
    }
  }

  @Test("Every localization key referenced by the app exists")
  func appReferencesExistingKeys() throws {
    let expectedKeys = Set(try localization("en").keys)
    let sourceDirectory = repositoryRoot.appendingPathComponent("Sources/LidAwakeApp")
    let sourceFiles = try FileManager.default.contentsOfDirectory(
      at: sourceDirectory,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "swift" }
    let pattern = try NSRegularExpression(pattern: #"L10n\.(?:text|format)\("([^"]+)""#)
    var referencedKeys = Set<String>()

    for file in sourceFiles {
      let source = try String(contentsOf: file, encoding: .utf8)
      let range = NSRange(source.startIndex..., in: source)
      for match in pattern.matches(in: source, range: range) {
        guard let keyRange = Range(match.range(at: 1), in: source) else { continue }
        referencedKeys.insert(String(source[keyRange]))
      }
    }

    #expect(referencedKeys == expectedKeys)
  }

  @Test("Primary labels fit the fixed-width window budget")
  func labelLengthBudget() throws {
    let english = try localization("en")
    for (key, value) in english where key.hasPrefix("status.title.") {
      #expect(value.count <= 24, "\(key) exceeds the title budget")
    }
    for (key, value) in english where key.hasPrefix("button.") {
      #expect(value.count <= 32, "\(key) exceeds the button budget")
    }
    for (key, value) in english where key.hasPrefix("readiness.") {
      #expect(value.count <= 20, "\(key) exceeds the readiness-card budget")
    }
  }

  @Test("English and Japanese labels fit their rendered width budgets")
  func renderedWidthBudget() throws {
    for language in ["en", "ja"] {
      let values = try localization(language)
      for (key, value) in values where key.hasPrefix("status.title.") {
        #expect(renderedWidth(value, size: 30, weight: .bold) <= 390, "\(language):\(key)")
      }
      for (key, value) in values where key.hasPrefix("button.") {
        #expect(renderedWidth(value, size: 20, weight: .bold) <= 400, "\(language):\(key)")
      }
      for (key, value) in values where key.hasPrefix("readiness.") {
        #expect(renderedWidth(value, size: 11, weight: .bold) <= 110, "\(language):\(key)")
      }
      let footer = try #require(values["footer.exit_recovery"])
      #expect(renderedWidth(footer, size: 11, weight: .regular) <= 448, "\(language):footer")
    }
  }

  private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private func localization(_ language: String) throws -> [String: String] {
    let url =
      repositoryRoot
      .appendingPathComponent("Resources/\(language).lproj/Localizable.strings")
    let data = try Data(contentsOf: url)
    let object = try PropertyListSerialization.propertyList(from: data, format: nil)
    return try #require(object as? [String: String])
  }

  private func formatSpecifiers(in value: String) -> [String] {
    let pattern = try! NSRegularExpression(pattern: #"%(?:@|d)"#)
    let range = NSRange(value.startIndex..., in: value)
    return pattern.matches(in: value, range: range).compactMap { match in
      Range(match.range, in: value).map { String(value[$0]) }
    }
  }

  private func containsJapaneseText(_ value: String) -> Bool {
    value.unicodeScalars.contains { scalar in
      (0x3040...0x30FF).contains(scalar.value) || (0x3400...0x9FFF).contains(scalar.value)
    }
  }

  private func renderedWidth(_ value: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
    (value as NSString).size(withAttributes: [
      .font: NSFont.systemFont(ofSize: size, weight: weight)
    ])
    .width
  }
}
