import Foundation
import SwiftData
import SwiftUI
import WebKit

@MainActor
class DownloadManager: ObservableObject {
    @Published var activeDownloads: [Download] = []
    @Published var recentDownloads: [Download] = []
    @Published var isDownloadsPopoverOpen = false

    let modelContainer: ModelContainer
    let modelContext: ModelContext
    private var activeDownloadTasks: [UUID: WKDownload] = [:]

    init(
        modelContainer: ModelContainer,
        modelContext: ModelContext
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
        loadRecentDownloads()
    }

    private func loadRecentDownloads() {
        let descriptor = FetchDescriptor<Download>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let downloads = try modelContext.fetch(descriptor)
            self.recentDownloads = Array(downloads.prefix(20)) // Show last 20 downloads
            self.activeDownloads = downloads.filter { $0.status == .downloading }
        } catch {
            // Failed to load downloads
        }
    }

    func startDownload(
        from downloadTask: WKDownload,
        originalURL: URL,
        suggestedFilename: String,
        expectedSize: Int64 = 0
    ) -> Download {
        let download = Download(
            originalURL: originalURL,
            fileName: suggestedFilename,
            fileSize: expectedSize
        )

        download.status = .downloading
        download.isActive = true

        // Save to SwiftData
        modelContext.insert(download)
        do {
            try modelContext.save()
        } catch {
            // Failed to save download
        }

        activeDownloadTasks[download.id] = downloadTask
        activeDownloads.append(download)
        refreshRecentDownloads()
        return download
    }

    func updateDownloadProgress(_ download: Download, downloadedBytes: Int64, totalBytes: Int64) {
        download.updateProgress(downloadedBytes: downloadedBytes, totalBytes: totalBytes)

        try? modelContext.save()

        // Trigger UI updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
            download.objectWillChange.send()
        }
    }

    func completeDownload(_ download: Download, destinationURL: URL) {
        download.markCompleted(destinationURL: destinationURL)

        try? modelContext.save()

        activeDownloadTasks.removeValue(forKey: download.id)
        activeDownloads.removeAll { $0.id == download.id }
        refreshRecentDownloads()

        // Show notification or update UI
    }

    func failDownload(_ download: Download, error: String) {
        download.markFailed(error: error)

        try? modelContext.save()

        activeDownloadTasks.removeValue(forKey: download.id)
        activeDownloads.removeAll { $0.id == download.id }
        refreshRecentDownloads()
    }

    func cancelDownload(_ download: Download) {
        if let downloadTask = activeDownloadTasks[download.id] {
            downloadTask.cancel()
        }

        download.markCancelled()

        try? modelContext.save()

        activeDownloadTasks.removeValue(forKey: download.id)
        activeDownloads.removeAll { $0.id == download.id }
        refreshRecentDownloads()
    }

    func clearCompletedDownloads() {
        let completedDownloads = recentDownloads.filter { $0.status == .completed }
        for download in completedDownloads {
            modelContext.delete(download)
        }

        try? modelContext.save()
        refreshRecentDownloads()
    }

    func deleteDownload(_ download: Download) {
        // If it's an active download, cancel it first
        if download.status == .downloading {
            cancelDownload(download)
        }

        modelContext.delete(download)
        try? modelContext.save()
        refreshRecentDownloads()
    }

    func openDownloadInFinder(_ download: Download) {
        guard let destinationURL = download.destinationURL else { return }
        NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: "")
    }

    private func refreshRecentDownloads() {
        loadRecentDownloads()
    }

    // Helper to get default downloads directory
    func getDownloadsDirectory() -> URL {
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    // Helper to create unique filename if file already exists
    func createUniqueFilename(for url: URL) -> URL {
        var finalURL = url
        var counter = 1

        while FileManager.default.fileExists(atPath: finalURL.path) {
            let filename = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let directory = url.deletingLastPathComponent()

            let newFilename = ext.isEmpty ? "\(filename) (\(counter))" : "\(filename) (\(counter)).\(ext)"
            finalURL = directory.appendingPathComponent(newFilename)
            counter += 1
        }

        return finalURL
    }
}
