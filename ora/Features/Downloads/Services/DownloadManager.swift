import Foundation
import SwiftData
import SwiftUI

@MainActor
class DownloadManager: ObservableObject {
    @Published var activeDownloads: [Download] = []
    @Published var recentDownloads: [Download] = []
    @Published var isShowingDownloadsHistory = false

    let modelContainer: ModelContainer
    let modelContext: ModelContext
    private var activeDownloadTasks: [UUID: BrowserDownloadTask] = [:]
    private var taskDownloads: [UUID: Download] = [:]
    private var taskDestinationURLs: [UUID: URL] = [:]
    private var progressTimers: [UUID: Timer] = [:]
    weak var toastManager: ToastManager?

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
            self.recentDownloads = Array(downloads.prefix(50))
            self.activeDownloads = downloads.filter { $0.status == .downloading }
        } catch {
            // Failed to load downloads
        }
    }

    func startDownload(
        from downloadTask: BrowserDownloadTask,
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

        // Ensure SwiftUI picks up the change when called from WKDownload callbacks
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        toastManager?.show("Downloading \(suggestedFilename)", type: .info, icon: .system("arrow.down.circle"))

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

        toastManager?.show("Downloaded \(download.fileName)", icon: .system("checkmark.circle"))
    }

    func failDownload(_ download: Download, error: String) {
        download.markFailed(error: error)

        try? modelContext.save()

        activeDownloadTasks.removeValue(forKey: download.id)
        activeDownloads.removeAll { $0.id == download.id }
        refreshRecentDownloads()

        toastManager?.show("Download failed \(download.fileName)", type: .error)
    }

    func cancelDownload(_ download: Download) {
        let fileName = download.fileName
        if let downloadTask = activeDownloadTasks[download.id] {
            downloadTask.cancel()
            cleanupTask(downloadTask.id)
        }

        download.markCancelled()

        try? modelContext.save()

        activeDownloadTasks.removeValue(forKey: download.id)
        activeDownloads.removeAll { $0.id == download.id }
        refreshRecentDownloads()

        toastManager?.show("Download cancelled \(fileName)", type: .info, icon: .system("xmark.circle"))
    }

    func handleDownload(_ task: BrowserDownloadTask) {
        task.onDestinationRequest = { [weak self] response, suggestedFilename, completion in
            guard let self else {
                completion(nil)
                return
            }

            let downloadsDir = self.getDownloadsDirectory()
            let destinationURL = downloadsDir.appendingPathComponent(suggestedFilename)
            let finalURL = self.createUniqueFilename(for: destinationURL)
            let expectedSize = response.expectedContentLength
            let download = self.startDownload(
                from: task,
                originalURL: task.originalURL,
                suggestedFilename: suggestedFilename,
                expectedSize: expectedSize
            )

            self.taskDownloads[task.id] = download
            self.taskDestinationURLs[task.id] = finalURL
            self.startProgressTimer(for: task, download: download, expectedSize: expectedSize)
            completion(finalURL)
        }

        task.onRedirect = { [weak self] newURL in
            guard let self, let download = self.taskDownloads[task.id] else { return }
            download.originalURL = newURL
            download.originalURLString = newURL.absoluteString
            try? self.modelContext.save()
        }

        task.onFinish = { [weak self] in
            guard let self,
                  let download = self.taskDownloads[task.id],
                  let destinationURL = self.taskDestinationURLs[task.id]
            else {
                return
            }

            self.completeDownload(download, destinationURL: destinationURL)
            self.cleanupTask(task.id)
        }

        task.onFail = { [weak self] error in
            guard let self, let download = self.taskDownloads[task.id] else { return }
            self.failDownload(download, error: error.localizedDescription)
            self.cleanupTask(task.id)
        }
    }

    func clearCompletedDownloads() {
        let completedDownloads = recentDownloads.filter { $0.status == .completed }
        for download in completedDownloads {
            modelContext.delete(download)
        }

        try? modelContext.save()
        refreshRecentDownloads()
    }

    func clearNonActiveDownloads() {
        let nonActive = recentDownloads.filter {
            $0.status == .completed || $0.status == .failed || $0.status == .cancelled
        }
        for download in nonActive {
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

    func openFile(_ download: Download) {
        guard let url = download.destinationURL else { return }
        NSWorkspace.shared.open(url)
    }

    /// Moves the downloaded file to Trash and removes the entry from history
    func moveToTrash(_ download: Download) {
        if let url = download.destinationURL {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        deleteDownload(download)
    }

    /// Re-opens the original URL in the browser to re-trigger the download
    func retryDownload(_ download: Download) {
        guard let url = URL(string: download.originalURLString) else { return }
        deleteDownload(download)
        if let window = NSApp.keyWindow {
            NotificationCenter.default.post(name: .openURL, object: window, userInfo: ["url": url])
        }
    }

    private func refreshRecentDownloads() {
        loadRecentDownloads()
    }

    /// Helper to get default downloads directory
    func getDownloadsDirectory() -> URL {
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    /// Helper to create unique filename if file already exists
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

    private func startProgressTimer(for task: BrowserDownloadTask, download: Download, expectedSize: Int64) {
        let taskID = task.id
        progressTimers[taskID]?.invalidate()
        progressTimers[taskID] = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let completedBytes = task.progress.completedUnitCount
            let totalBytes = task.progress.totalUnitCount > 0 ? task.progress.totalUnitCount : expectedSize
            Task { @MainActor in
                guard let download = self.taskDownloads[taskID] else { return }
                self.updateDownloadProgress(
                    download,
                    downloadedBytes: completedBytes,
                    totalBytes: totalBytes
                )
            }
        }
    }

    private func cleanupTask(_ taskID: UUID) {
        progressTimers[taskID]?.invalidate()
        progressTimers.removeValue(forKey: taskID)
        taskDownloads.removeValue(forKey: taskID)
        taskDestinationURLs.removeValue(forKey: taskID)
    }
}
