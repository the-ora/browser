import Sparkle
import SwiftUI

@Observable @MainActor
final class UpdateService: NSObject {
    var canCheckForUpdates = false
    var updateProgress: Double = 0.0
    var isCheckingForUpdates = false
    var updateAvailable = false
    var lastCheckResult: String?
    var lastCheckDate: Date?

    @ObservationIgnored private var updater: SPUUpdater?
    @ObservationIgnored private var userDriver: SPUStandardUserDriver?

    override init() {
        super.init()
        setupUpdater()
    }

    private func setupUpdater() {
        print("🔧 UpdateService: Setting up updater")

        // Log app information
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        print("📱 UpdateService: App Info - Version: \(currentVersion), Bundle ID: \(bundleId)")

        let hostBundle = Bundle.main
        let applicationBundle = hostBundle
        let userDriver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)
        let updater = SPUUpdater(
            hostBundle: hostBundle,
            applicationBundle: applicationBundle,
            userDriver: userDriver,
            delegate: self
        )

        self.updater = updater
        self.userDriver = userDriver

        // Log Sparkle configuration
        print("🔑 UpdateService: Sparkle Config - Feed URL: \(updater.feedURL?.absoluteString ?? "none")")

        // Start the updater
        do {
            try updater.start()
            print("✅ UpdateService: Updater started successfully")
            print("🔄 UpdateService: Automatic checks enabled: \(updater.automaticallyChecksForUpdates)")
            print("⏰ UpdateService: Update check interval: \(updater.updateCheckInterval) seconds")
        } catch {
            print("❌ UpdateService: Failed to start updater - Error: \(error.localizedDescription)")
            print("❌ UpdateService: Error details: \(error)")
        }

        self.canCheckForUpdates = true // Force enable for development
        print("✅ UpdateService: Updater setup complete - canCheckForUpdates: \(self.canCheckForUpdates)")
    }

    func checkForUpdates() {
        print("🔄 UpdateService: checkForUpdates called")
        guard let updater, canCheckForUpdates else {
            print(
                "❌ UpdateService: Update checking not available - updater: \(updater != nil), canCheck: \(canCheckForUpdates)"
            )
            lastCheckResult = "Update checking is not available"
            lastCheckDate = Date()
            isCheckingForUpdates = false
            return
        }

        print("✅ UpdateService: Starting update check")
        isCheckingForUpdates = true
        lastCheckResult = "Checking for updates..."
        lastCheckDate = Date()

        Task { [weak self] in
            try await Task.sleep(for: .seconds(30))
            if self?.isCheckingForUpdates == true {
                print("⏰ UpdateService: Update check timed out after 30 seconds")
                self?.isCheckingForUpdates = false
                self?.lastCheckResult = "Update check timed out"
                self?.lastCheckDate = Date()
            }
        }

        print("📡 UpdateService: Calling updater.checkForUpdates()")
        print("🌐 UpdateService: Network check - Feed URL: \(updater.feedURL?.absoluteString ?? "none")")

        updater.checkForUpdates()
    }

    func checkForUpdatesInBackground() {
        guard let updater else { return }
        updater.checkForUpdatesInBackground()
    }
}

extension UpdateService: SPUUpdaterDelegate {
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        let feedURL = "https://the-ora.github.io/browser/appcast.xml"
        print("🔗 UpdateService: Providing feed URL: \(feedURL)")
        print("🔗 UpdateService: Feed URL requested by Sparkle updater")
        return feedURL
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        print("✅ UpdateService: Found valid update!")

        let version = item.displayVersionString ?? item.versionString

        print("📦 UpdateService: Update details:")
        print("   - Version: \(version)")
        print("   - File URL: \(item.fileURL?.absoluteString ?? "none")")
        print("   - Info URL: \(item.infoURL?.absoluteString ?? "none")")
        print("   - Release notes: \(item.itemDescription ?? "none")")
        print("   - Minimum OS: \(item.minimumSystemVersion ?? "none")")
        print("   - File size: \(item.contentLength) bytes")

        Task { @MainActor in
            self.updateAvailable = true
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Update available: \(version)"
            self.lastCheckDate = Date()
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        print("ℹ️ UpdateService: No update found")
        print("❌ UpdateService: Error details: \(error.localizedDescription)")
        print("🔍 UpdateService: Error code: \((error as NSError).code)")
        print("🔍 UpdateService: Error domain: \((error as NSError).domain)")

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        print("📱 UpdateService: Current app version: \(currentVersion)")

        // Log more details about the error
        let nsError = error as NSError
        print("🔍 UpdateService: Sparkle error userInfo: \(nsError.userInfo)")

        Task { @MainActor in
            self.updateAvailable = false
            self.isCheckingForUpdates = false
            self.lastCheckResult = "No updates available (current: \(currentVersion))"
            self.lastCheckDate = Date()
        }
    }

    nonisolated func updater(
        _ updater: SPUUpdater,
        willDownloadUpdate item: SUAppcastItem,
        with request: NSMutableURLRequest
    ) {
        print("⬇️ UpdateService: Starting download - URL: \(request.url?.absoluteString ?? "unknown")")
        Task { @MainActor in
            self.updateProgress = 0.0
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        print("✅ UpdateService: Update downloaded successfully")
        Task { @MainActor in
            self.updateProgress = 1.0
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) {
        // Update extracted, ready for installation
    }

    nonisolated func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        print("📄 UpdateService: Appcast loaded successfully")
        print("📊 UpdateService: Appcast details:")
        print("   - Total items: \(appcast.items.count)")

        // Log details of each item
        for (index, item) in appcast.items.enumerated() {
            print("📦 UpdateService: Item \(index + 1):")
            print("   - Version: \(item.displayVersionString ?? item.versionString)")
            print("   - File URL: \(item.fileURL?.absoluteString ?? "none")")
            print("   - Info URL: \(item.infoURL?.absoluteString ?? "none")")
            print("   - File size: \(item.contentLength) bytes")
            print("   - Minimum OS: \(item.minimumSystemVersion ?? "none")")
            print("   - Release date: \(item.dateString ?? "none")")
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, failedToLoadAppcastWithError error: Error) {
        print("❌ UpdateService: Failed to load appcast")
        print("❌ UpdateService: Error: \(error.localizedDescription)")

        let nsError = error as NSError
        print("🔍 UpdateService: Error code: \(nsError.code)")
        print("🔍 UpdateService: Error domain: \(nsError.domain)")
        print("🔍 UpdateService: Error userInfo: \(nsError.userInfo)")

        Task { @MainActor in
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Failed to load appcast: \(error.localizedDescription)"
            self.lastCheckDate = Date()
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        print("❌ UpdateService: Failed to download update")
        print("❌ UpdateService: Error: \(error.localizedDescription)")
        print("❌ UpdateService: Item version: \(item.displayVersionString ?? item.versionString)")
        print("❌ UpdateService: Download URL: \(item.fileURL?.absoluteString ?? "none")")

        let nsError = error as NSError
        print("🔍 UpdateService: Error code: \(nsError.code)")
        print("🔍 UpdateService: Error domain: \(nsError.domain)")
        print("🔍 UpdateService: Error userInfo: \(nsError.userInfo)")

        Task { @MainActor in
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Download failed: \(error.localizedDescription)"
            self.lastCheckDate = Date()
        }
    }
}
