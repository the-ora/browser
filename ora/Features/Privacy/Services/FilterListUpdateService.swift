import Foundation

struct FilterListFetchResult {
    let record: FilterListRecord
    let rawText: String?
}

final class FilterListUpdateService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func isValidCustomListURL(_ rawValue: String) -> Bool {
        guard let url = normalizedURL(from: rawValue) else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    func normalizedURL(from rawValue: String) -> URL? {
        guard let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }

    func fetchLatest(for record: FilterListRecord) async throws -> FilterListFetchResult {
        guard let url = normalizedURL(from: record.sourceURL) else {
            throw AdBlockServiceError.invalidCustomListURL
        }

        var request = URLRequest(url: url)
        if let etag = record.etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = record.lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AdBlockServiceError.invalidFilterResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            guard let rawText = String(data: data, encoding: .utf8) else {
                throw AdBlockServiceError.invalidFilterResponse
            }

            var updatedRecord = record
            updatedRecord.lastFetchAt = Date()
            updatedRecord.etag = httpResponse.value(forHTTPHeaderField: "ETag")
            updatedRecord.lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")
            updatedRecord.lastErrorMessage = nil
            return FilterListFetchResult(record: updatedRecord, rawText: rawText)
        case 304:
            var updatedRecord = record
            updatedRecord.lastFetchAt = Date()
            updatedRecord.lastErrorMessage = nil
            return FilterListFetchResult(record: updatedRecord, rawText: nil)
        default:
            throw AdBlockServiceError.downloadFailed(statusCode: httpResponse.statusCode)
        }
    }
}
