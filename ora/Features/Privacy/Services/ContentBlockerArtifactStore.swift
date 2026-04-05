import CryptoKit
import Foundation

final class ContentBlockerArtifactStore {
    struct RevisionManifest: Codable {
        let coverage: FilterListCoverage
    }

    static let shared = ContentBlockerArtifactStore()

    private let fileManager: FileManager
    private let baseURL: URL
    private let identifierPrefix = "com.orabrowser.adblock"

    init(fileManager: FileManager = .default, baseURL: URL? = nil) {
        self.fileManager = fileManager
        self.baseURL = baseURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Ora", isDirectory: true)
            .appendingPathComponent("ContentBlockers", isDirectory: true)

        try? fileManager.createDirectory(at: self.baseURL, withIntermediateDirectories: true, attributes: nil)
    }

    func revisionHash(for rawText: String) -> String {
        let digest = SHA256.hash(data: Data(rawText.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    func rawListText(for listID: String) -> String? {
        try? String(contentsOf: rawListURL(for: listID), encoding: .utf8)
    }

    func storeRawListText(_ rawText: String, for listID: String) throws {
        let url = rawListURL(for: listID)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try rawText.write(to: url, atomically: true, encoding: .utf8)
    }

    func storeCompiledArtifacts(
        jsonShards: [String],
        coverage: FilterListCoverage,
        for listID: String,
        revision: String
    ) throws {
        let revisionURL = compiledRevisionURL(for: listID, revision: revision)
        try? fileManager.removeItem(at: revisionURL)
        try fileManager.createDirectory(at: revisionURL, withIntermediateDirectories: true, attributes: nil)

        for (index, json) in jsonShards.enumerated() {
            try json.write(
                to: revisionURL.appendingPathComponent("shard-\(index).json"),
                atomically: true,
                encoding: .utf8
            )
        }

        let manifestURL = revisionURL.appendingPathComponent("manifest.json")
        let manifestData = try JSONEncoder().encode(RevisionManifest(coverage: coverage))
        try manifestData.write(to: manifestURL, options: .atomic)

        let listCompiledRoot = compiledListURL(for: listID)
        let revisionDirectories = (try? fileManager.contentsOfDirectory(
            at: listCompiledRoot,
            includingPropertiesForKeys: nil
        )) ?? []

        for oldRevisionURL in revisionDirectories where oldRevisionURL.lastPathComponent != revision {
            try? fileManager.removeItem(at: oldRevisionURL)
        }
    }

    func hasCompiledArtifacts(for listID: String, revision: String) -> Bool {
        !ruleListIdentifiers(for: listID, revision: revision).isEmpty
    }

    func coverage(for listID: String, revision: String) -> FilterListCoverage? {
        let manifestURL = compiledRevisionURL(for: listID, revision: revision).appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        return try? JSONDecoder().decode(RevisionManifest.self, from: data).coverage
    }

    func ruleListIdentifiers(for listID: String, revision: String) -> [String] {
        let revisionURL = compiledRevisionURL(for: listID, revision: revision)
        let urls = (try? fileManager.contentsOfDirectory(
            at: revisionURL,
            includingPropertiesForKeys: nil
        )) ?? []

        return urls
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("shard-") }
            .compactMap { url -> (Int, String)? in
                guard let shardIndex = Int(url.deletingPathExtension().lastPathComponent.replacingOccurrences(
                    of: "shard-",
                    with: ""
                )) else {
                    return nil
                }

                return (shardIndex, ruleListIdentifier(for: listID, revision: revision, shardIndex: shardIndex))
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)
    }

    func encodedRuleList(for identifier: String) -> String? {
        guard let descriptor = parse(identifier: identifier) else { return nil }
        let url = compiledRevisionURL(for: descriptor.listID, revision: descriptor.revision)
            .appendingPathComponent("shard-\(descriptor.shardIndex).json")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func removeArtifacts(for listID: String) {
        try? fileManager.removeItem(at: compiledListURL(for: listID))
        try? fileManager.removeItem(at: rawListURL(for: listID))
    }

    private func ruleListIdentifier(for listID: String, revision: String, shardIndex: Int) -> String {
        "\(identifierPrefix).\(listID).\(revision).\(shardIndex)"
    }

    private func parse(identifier: String) -> (listID: String, revision: String, shardIndex: Int)? {
        let prefix = "\(identifierPrefix)."
        guard identifier.hasPrefix(prefix) else { return nil }

        let components = identifier.replacingOccurrences(of: prefix, with: "").split(separator: ".")
        guard components.count >= 3,
              let revision = components.dropLast().last,
              let shardComponent = components.last,
              let shardIndex = Int(shardComponent)
        else {
            return nil
        }

        return (
            listID: components.dropLast(2).joined(separator: "."),
            revision: String(revision),
            shardIndex: shardIndex
        )
    }

    private func rawListURL(for listID: String) -> URL {
        baseURL
            .appendingPathComponent("raw", isDirectory: true)
            .appendingPathComponent("\(listID).txt")
    }

    private func compiledListURL(for listID: String) -> URL {
        baseURL
            .appendingPathComponent("compiled", isDirectory: true)
            .appendingPathComponent(listID, isDirectory: true)
    }

    private func compiledRevisionURL(for listID: String, revision: String) -> URL {
        compiledListURL(for: listID)
            .appendingPathComponent(revision, isDirectory: true)
    }
}
