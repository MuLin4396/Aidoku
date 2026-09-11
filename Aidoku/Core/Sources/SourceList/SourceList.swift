//
//  SourceList.swift
//  Aidoku
//
//  Created by Skitty on 6/11/25.
//

import CryptoKit
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

    /// Original URL, directory `index.min.json`, then GitHub Pages mirrors.
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
            githubPagesMirrors(for: original).forEach(append)
        }
        return result
    }

    static let communityIndexURL = URL(string: "https://aidoku-community.github.io/sources/index.min.json")!

    static func isCommunityList(_ list: SourceList) -> Bool {
        list.name.caseInsensitiveCompare("Aidoku Community Sources") == .orderedSame
    }

    /// Mirrors for `https://org.github.io/repo/path`.
    /// `cdn.jsdelivr.net` is omitted: it is commonly DNS-hijacked in some networks
    /// and fails TLS with an invalid certificate.
    static func githubPagesMirrors(for url: URL) -> [URL] {
        guard let host = url.host?.lowercased(), host.hasSuffix(".github.io") else {
            return []
        }
        let org = String(host.dropLast(".github.io".count))
        let parts = url.path.split(separator: "/").map(String.init)
        guard let repo = parts.first, !org.isEmpty else {
            return []
        }
        let rest = parts.dropFirst().joined(separator: "/")
        let filePath = rest.isEmpty ? "index.min.json" : rest
        let templates = [
            "https://cdn.jsdmirror.com/gh/\(org)/\(repo)@gh-pages/\(filePath)",
            "https://fastly.jsdelivr.net/gh/\(org)/\(repo)@gh-pages/\(filePath)",
            "https://raw.githubusercontent.com/\(org)/\(repo)/gh-pages/\(filePath)"
        ]
        return templates.compactMap(URL.init(string:))
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

enum SourceListCache {
    private static var root: URL {
        let url = FileManager.default.applicationSupportDirectory
            .appendingPathComponent("SourceLists", isDirectory: true)
            .appendingPathComponent("Cache", isDirectory: true)
        url.createDirectory()
        return url
    }

    private static func directory(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(hex, isDirectory: true)
    }

    static func store(data: Data, listURL: URL, resolveBase: URL) {
        let dir = directory(for: listURL)
        dir.createDirectory()
        try? data.write(to: dir.appendingPathComponent("index.json"), options: .atomic)
        try? Data(resolveBase.absoluteString.utf8)
            .write(to: dir.appendingPathComponent("base-url.txt"), options: .atomic)
    }

    static func load(listURL: URL) -> (data: Data, resolveBase: URL)? {
        let dir = directory(for: listURL)
        guard
            let data = try? Data(contentsOf: dir.appendingPathComponent("index.json")),
            !data.isEmpty,
            let baseString = try? String(
                contentsOf: dir.appendingPathComponent("base-url.txt"),
                encoding: .utf8
            ),
            let resolveBase = URL(string: baseString.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return nil
        }
        return (data, resolveBase)
    }
}

extension Error {
    var isTLSTrustFailure: Bool {
        if let urlError = self as? URLError {
            switch urlError.code {
                case .secureConnectionFailed,
                     .serverCertificateUntrusted,
                     .serverCertificateHasUnknownRoot,
                     .serverCertificateNotYetValid,
                     .clientCertificateRejected,
                     .clientCertificateRequired:
                    return true
                default:
                    break
            }
        }
        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain, (-1206...(-1200)).contains(nsError.code) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError, underlying !== nsError {
            return underlying.isTLSTrustFailure
        }
        return false
    }
}
