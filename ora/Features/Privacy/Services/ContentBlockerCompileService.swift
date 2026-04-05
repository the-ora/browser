import ContentBlockerConverter
import Foundation

struct CompiledFilterArtifacts {
    let revision: String
    let coverage: FilterListCoverage
    let jsonShards: [String]
}

final class ContentBlockerCompileService {
    private let artifactStore: ContentBlockerArtifactStore

    init(artifactStore: ContentBlockerArtifactStore = .shared) {
        self.artifactStore = artifactStore
    }

    func compile(record: FilterListRecord, rawText: String) throws -> CompiledFilterArtifacts {
        var contiguousRawText = rawText
        contiguousRawText.makeContiguousUTF8()
        let rules = contiguousRawText.components(separatedBy: .newlines)

        guard rules.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            throw AdBlockServiceError.emptyFilterList(record.name)
        }

        let revision = artifactStore.revisionHash(for: contiguousRawText)
        let shardResults = compileShards(from: rules)
        let jsonShards = shardResults
            .map(\.safariRulesJSON)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let totalRuleCount = shardResults.reduce(0) { $0 + $1.sourceRulesCount }
        let convertedRuleCount = max(
            shardResults.reduce(0) { $0 + max($1.sourceSafariCompatibleRulesCount - $1.errorsCount, 0) },
            0
        )
        let skippedRuleCount = max(totalRuleCount - convertedRuleCount, 0)
        let safariRuleCount = shardResults.reduce(0) { $0 + $1.safariRulesCount }
        let coverage = FilterListCoverage(
            totalRuleCount: totalRuleCount,
            convertedRuleCount: convertedRuleCount,
            skippedRuleCount: skippedRuleCount,
            safariRuleCount: safariRuleCount,
            shardCount: jsonShards.count
        )

        guard coverage.shardCount > 0, coverage.safariRuleCount > 0 else {
            throw AdBlockServiceError.emptyFilterList(record.name)
        }

        return CompiledFilterArtifacts(
            revision: revision,
            coverage: coverage,
            jsonShards: jsonShards
        )
    }

    private func compileShards(from rules: [String]) -> [ConversionResult] {
        guard !rules.isEmpty else { return [] }

        let result = ContentBlockerConverter().convertArray(
            rules: rules,
            safariVersion: .autodetect(),
            advancedBlocking: false
        )

        if result.discardedSafariRules > 0, rules.count > 1 {
            let midpoint = rules.count / 2
            let firstHalf = Array(rules[..<midpoint])
            let secondHalf = Array(rules[midpoint...])
            return compileShards(from: firstHalf) + compileShards(from: secondHalf)
        }

        return result.safariRulesCount > 0 ? [result] : []
    }
}
