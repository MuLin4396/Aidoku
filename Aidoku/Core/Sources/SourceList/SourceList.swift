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

    /// Original URL, directory `index.min.json`, then jsDelivr GitHub Pages mirrors.
    static func fetchCandidates(for url: URL) -> [URL] {
        var originals = [url]
        if let indexURL = indexURL(for: url) {
            originals.append(indexURL)
        }

        var result: [URL] = []
        var seen = Set<String>()
        func append(_ url: URL) {
            guard seen.insert(url.absoluteString).inserted else { return }
            result.append(url)
        }

        originals.forEach(append)
        for original in originals {
            if let mirror = jsDelivrMirror(for: original) {
                append(mirror)
            }
        }
        return result
    }

    /// `https://org.github.io/repo/path` → `https://cdn.jsdelivr.net/gh/org/repo@gh-pages/path`
    static func jsDelivrMirror(for url: URL) -> URL? {
        guard let host = url.host?.lowercased(), host.hasSuffix(".github.io") else {
            return nil
        }
        let org = String(host.dropLast(".github.io".count))
        let parts = url.path.split(separator: "/").map(String.init)
        guard let repo = parts.first, !org.isEmpty else {
            return nil
        }
        let rest = parts.dropFirst().joined(separator: "/")
        let filePath = rest.isEmpty ? "index.min.json" : rest
        return URL(string: "https://cdn.jsdelivr.net/gh/\(org)/\(repo)@gh-pages/\(filePath)")
    }
}

enum SourceListAddResult {
    case success
    case alreadyAdded
    case failed(String)

    var succeeded: Bool {
        if case .success = self { return true }
        return false
    }

    var failureMessage: String {
        switch self {
            case .success:
                ""
            case .alreadyAdded:
                NSLocalizedString("SOURCE_LIST_ADD_FAIL_TEXT")
            case let .failed(detail):
                "\(NSLocalizedString("SOURCE_LIST_ADD_FAIL_TEXT"))\n\n\(detail)"
        }
    }
}
