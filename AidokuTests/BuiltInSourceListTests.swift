//
//  BuiltInSourceListTests.swift
//  Aidoku
//

import Foundation
import Testing
@testable import Aidoku

@Suite struct BuiltInSourceListTests {
    @Test func bundledCatalogDecodes() throws {
        let data = try #require(BuiltInSourceList.bundledData() ?? bundledTestFixture())
        let decoded = try JSONDecoder().decode(CodableSourceList.self, from: data)
        let list = decoded.into(url: BuiltInSourceList.remoteURL)

        #expect(list.name == "Aidoku Community Sources")
        #expect(!list.sources.isEmpty)
        #expect(list.sources.contains { $0.id == "multi.mangadex" })
        #expect(list.sources[0].fileURL?.absoluteString.hasPrefix("https://cdn.jsdelivr.net/") == true)
    }

    @Test func matchesOfficialAndMirrorURLs() {
        #expect(BuiltInSourceList.matches(BuiltInSourceList.remoteURL))
        #expect(
            BuiltInSourceList.matches(
                URL(string: "https://aidoku-community.github.io/sources/index.min.json")!
            )
        )
        #expect(
            !BuiltInSourceList.matches(URL(string: "https://example.com/sources/index.min.json")!)
        )
    }

    @Test func defaultBrowseSettingsIncludeBuiltInList() {
        #expect(AppSettings.browse.sourceLists.defaultValue.contains(BuiltInSourceList.remoteURL))
    }

    /// Test bundle may not include app resources; fall back to the repo fixture.
    private func bundledTestFixture() -> Data? {
        let thisFile = URL(fileURLWithPath: #filePath)
        let fixture = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Aidoku/App/Resources/BuiltIn/community-sources.json")
        return try? Data(contentsOf: fixture)
    }
}
