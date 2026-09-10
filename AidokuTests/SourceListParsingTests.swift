//
//  SourceListParsingTests.swift
//  Aidoku
//

import Foundation
import Testing
@testable import Aidoku
import AidokuRunner

@Suite struct SourceListParsingTests {
    @Test func parseNewFormatSourceList() throws {
        let json = """
        {
          "name": "Aidoku Community Sources",
          "sources": [
            {
              "id": "en.test",
              "name": "Test",
              "version": 1,
              "iconURL": "icons/en.test-v1.png",
              "downloadURL": "sources/en.test-v1.aix",
              "languages": ["en"],
              "contentRating": 0,
              "baseURL": "https://example.com"
            }
          ]
        }
        """
        let url = try #require(URL(string: "https://aidoku-community.github.io/sources/index.min.json"))
        let list = try #require(SourceList.parse(data: Data(json.utf8), url: url))

        #expect(list.name == "Aidoku Community Sources")
        #expect(!list.legacy)
        #expect(list.sources.count == 1)
        #expect(list.sources[0].id == "en.test")
        #expect(list.sources[0].fileURL?.absoluteString == "https://aidoku-community.github.io/sources/sources/en.test-v1.aix")
        #expect(list.sources[0].resolvedContentRating == .safe)
    }

    @Test func parseLegacyArraySourceList() throws {
        let json = """
        [
          {
            "id": "en.legacy",
            "name": "Legacy",
            "version": 2,
            "lang": "en",
            "file": "en.legacy-v2.aix",
            "icon": "en.legacy.png",
            "nsfw": 1
          }
        ]
        """
        let url = try #require(URL(string: "https://example.com/repo/index.min.json"))
        let list = try #require(SourceList.parse(data: Data(json.utf8), url: url))

        #expect(list.legacy)
        #expect(list.sources.count == 1)
        #expect(list.sources[0].id == "en.legacy")
        #expect(list.sources[0].fileURL?.absoluteString == "https://example.com/repo/sources/en.legacy-v2.aix")
        #expect(list.sources[0].resolvedContentRating == .containsNsfw)
    }

    @Test func htmlLandingPageIsNotASourceList() {
        let html = Data("<!doctype html><html><body>Aidoku Community Sources</body></html>".utf8)
        let url = URL(string: "https://aidoku-community.github.io/sources/")!
        #expect(SourceList.parse(data: html, url: url) == nil)
    }

    @Test func directoryURLResolvesIndex() {
        let directory = URL(string: "https://aidoku-community.github.io/sources/")!
        #expect(
            SourceList.indexURL(for: directory)?.absoluteString
                == "https://aidoku-community.github.io/sources/index.min.json"
        )

        let directoryWithoutSlash = URL(string: "https://aidoku-community.github.io/sources")!
        #expect(
            SourceList.indexURL(for: directoryWithoutSlash)?.absoluteString
                == "https://aidoku-community.github.io/sources/index.min.json"
        )

        let json = URL(string: "https://aidoku-community.github.io/sources/index.min.json")!
        #expect(SourceList.indexURL(for: json) == nil)
    }

    @Test func jsDelivrMirrorForCommunitySources() {
        let json = URL(string: "https://aidoku-community.github.io/sources/index.min.json")!
        #expect(
            SourceList.jsDelivrMirror(for: json)?.absoluteString
                == "https://cdn.jsdelivr.net/gh/aidoku-community/sources@gh-pages/index.min.json"
        )

        let candidates = SourceList.fetchCandidates(for: json)
        #expect(candidates.contains(json))
        #expect(candidates.contains {
            $0.absoluteString == "https://cdn.jsdelivr.net/gh/aidoku-community/sources@gh-pages/index.min.json"
        })
    }
}
