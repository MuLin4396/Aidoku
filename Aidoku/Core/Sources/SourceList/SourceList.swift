//
//  SourceList.swift
//  Aidoku
//
//  Created by Skitty on 6/11/25.
//

import Foundation

struct SourceList: Equatable {
    let url: URL
    let name: String
    var feedbackURL: URL?
    let sources: [ExternalSourceInfo]
    var legacy: Bool = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url
    }
}

struct CodableSourceList: Codable {
    let name: String
    let feedbackURL: String?
    let sources: [ExternalSourceInfo]

    func into(url: URL) -> SourceList {
        .init(
            url: url,
            name: name,
            feedbackURL: feedbackURL.flatMap { URL(string: $0) },
            sources: sources.map {
                $0.with(sourceUrl: url)
            }
        )
    }
}

extension SourceList {
    /// Parses a source list payload. Newer lists are `{ name, sources }`; legacy lists are a raw source array.
    static func parse(data: Data, url: URL) -> SourceList? {
        let decoder = JSONDecoder()
        if let sourceList = try? decoder.decode(CodableSourceList.self, from: data) {
            return sourceList.into(url: url)
        }
        guard var sources = try? decoder.decode([ExternalSourceInfo].self, from: data) else {
            return nil
        }
        for index in sources.indices {
            sources[index].sourceUrl = url
        }
        return SourceList(
            url: url,
            name: NSLocalizedString("LEGACY_SOURCE_LIST"),
            sources: sources,
            legacy: true
        )
    }

    /// Directory URLs such as `https://example.com/sources/` publish `index.min.json`.
    static func indexURL(for url: URL) -> URL? {
        guard url.pathExtension.isEmpty else {
            return nil
        }
        return url.appendingPathComponent("index.min.json")
    }
}
