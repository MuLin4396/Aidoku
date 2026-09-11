//
//  BuiltInSourceList.swift
//  Aidoku
//

import Foundation

enum BuiltInSourceList {
    /// Canonical URL used for relative `.aix` / icon downloads (jsDelivr is more reachable than github.io).
    static let remoteURL = URL(string: "https://cdn.jsdelivr.net/gh/aidoku-community/sources@gh-pages/index.min.json")!

    static func matches(_ url: URL) -> Bool {
        let value = url.absoluteString.lowercased()
        return value.contains("aidoku-community.github.io/sources")
            || value.contains("cdn.jsdelivr.net/gh/aidoku-community/sources")
    }

    static func sourceList(matching url: URL) -> SourceList? {
        guard matches(url) else { return nil }
        return load()
    }

    static func load() -> SourceList? {
        guard let data = bundledData() else {
            LogManager.logger.error("Missing bundled community source list")
            return nil
        }
        guard let decoded = try? JSONDecoder().decode(CodableSourceList.self, from: data) else {
            LogManager.logger.error("Failed to decode bundled community source list")
            return nil
        }
        return decoded.into(url: remoteURL)
    }

    static func bundledData() -> Data? {
        let bundle = Bundle.main
        let url = bundle.url(forResource: "community-sources", withExtension: "json", subdirectory: "BuiltIn")
            ?? bundle.url(forResource: "community-sources", withExtension: "json")
        return url.flatMap { try? Data(contentsOf: $0) }
    }
}
