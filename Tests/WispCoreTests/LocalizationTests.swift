import Foundation
import Testing
@testable import WispCore

struct LocalizationTests {
    @Test func resolvesBothLanguages() {
        #expect(L10n.string("Memory", language: "zh-Hans") == "内存")
        #expect(L10n.string("Memory", language: "en") == "Memory")
    }

    @Test func unknownTextFallsBackWithoutChangingNames() {
        #expect(L10n.string("My Service {draft} 3020", language: "zh-Hans") == "My Service {draft} 3020")
        #expect(L10n.string("Memory", language: "de") == "Memory")
    }

    @Test func interpolationPreservesProcessNamesAndPorts() {
        let name = "node /Users/发哥/项目 {1} 100%"
        let pid = 53500
        let text: LocalizedText = "Stop \(name) (\(pid))?"
        #expect(text.key == "Stop {0} ({1})?")
        let translated = L10n.render(text, language: "zh-Hans")
        #expect(translated.contains(name))
        #expect(translated.contains("53500"))
        #expect(!translated.contains("Stop "))
        #expect(L10n.render(text, language: "en") == "Stop \(name) (\(pid))?")
    }

    @Test func missingTemplateStillFormatsValues() {
        let path = "/Users/发哥/My Project/{0}"
        let text: LocalizedText = "Unknown template \(path) then \(42)"
        #expect(L10n.render(text, language: "zh-Hans") == "Unknown template \(path) then 42")
    }

    @Test func storagePathsStayUntranslated() {
        #expect(StorageCatalog.places.first { $0.row == "documents" }?.paths == ["Documents"])
        #expect(StorageCatalog.places.first { $0.row == "downloads" }?.paths == ["Downloads"])
        #expect(StorageCatalog.codeFolders.contains("Developer"))
        #expect(StorageCatalog.codeFolders.contains("Projects"))
        #expect(StorageCatalog.artifactNames.contains("node_modules"))
    }

    @Test func catalogRetainsTechnicalUnits() {
        for unit in ["CPU", "GPU", "GB", "MB", "TCP", "UDP"] {
            #expect(L10n.string(unit, language: "zh-Hans") == unit)
        }
    }
}
