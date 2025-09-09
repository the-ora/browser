import os.log
import Sparkle
import SwiftUI

private let logger = Logger(subsystem: "com.orabrowser.ora", category: "UpdateService")

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
        logger.info("🔧 Setting up updater")

        // Log app information
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        logger.info("📱 App Info - Version: \(currentVersion), Bundle ID: \(bundleId)")

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
        logger.info("🔑 Sparkle Config - Feed URL: \(updater.feedURL?.absoluteString ?? "none")")

        // Start the updater
        do {
            try updater.start()
            logger.info("✅ Updater started successfully")
            logger.info("🔄 Automatic checks enabled: \(updater.automaticallyChecksForUpdates)")
            logger.info("⏰ Update check interval: \(updater.updateCheckInterval) seconds")
        } catch {
            logger.error("❌ Failed to start updater - Error: \(error.localizedDescription)")
            logger.error("❌ Error details: \(error)")
        }

        self.canCheckForUpdates = true // Force enable for development
        logger.info("✅ Updater setup complete - canCheckForUpdates: \(self.canCheckForUpdates)")
    }

    func checkForUpdates() {
        logger.info("🔄 checkForUpdates called")
        guard let updater, canCheckForUpdates else {
            logger
                .error(
                    "❌ Update checking not available - updater: \(self.updater != nil), canCheck: \(self.canCheckForUpdates)"
                )
            lastCheckResult = "Update checking is not available"
            lastCheckDate = Date()
            isCheckingForUpdates = false
            return
        }

        logger.info("✅ Starting update check")
        isCheckingForUpdates = true
        lastCheckResult = "Checking for updates..."
        lastCheckDate = Date()

        Task { [weak self] in
            try await Task.sleep(for: .seconds(30))
            if self?.isCheckingForUpdates == true {
                logger.warning("⏰ Update check timed out after 30 seconds")
                self?.isCheckingForUpdates = false
                self?.lastCheckResult = "Update check timed out"
                self?.lastCheckDate = Date()
            }
        }

        logger.info("📡 Calling updater.checkForUpdates()")
        logger.info("🌐 Network check - Feed URL: \(updater.feedURL?.absoluteString ?? "none")")

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
        logger.info("🔗 Providing feed URL: \(feedURL)")
        logger.info("🔗 Feed URL requested by Sparkle updater")
        return feedURL
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        logger.info("✅ Found valid update!")

        let version = item.displayVersionString

        logger.info("📦 Update details:")
        logger.info("   - Version: \(version)")
        logger.info("   - File URL: \(item.fileURL?.absoluteString ?? "none")")
        logger.info("   - Info URL: \(item.infoURL?.absoluteString ?? "none")")
        logger.info("   - Release notes: \(item.itemDescription ?? "none")")
        logger.info("   - Minimum OS: \(item.minimumSystemVersion ?? "none")")
        logger.info("   - File size: \(item.contentLength) bytes")

        Task { @MainActor in
            self.updateAvailable = true
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Update available: \(version)"
            self.lastCheckDate = Date()
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        logger.info("ℹ️ No update found")
        logger.error("❌ Error details: \(error.localizedDescription)")
        logger.debug("🔍 Error code: \((error as NSError).code)")
        logger.debug("🔍 Error domain: \((error as NSError).domain)")

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        logger.info("📱 Current app version: \(currentVersion)")

        // Log more details about the error
        let nsError = error as NSError
        logger.debug("🔍 Sparkle error userInfo: \(nsError.userInfo)")

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
        logger.info("⬇️ Starting download - URL: \(request.url?.absoluteString ?? "unknown")")
        Task { @MainActor in
            self.updateProgress = 0.0
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        logger.info("✅ Update downloaded successfully")
        Task { @MainActor in
            self.updateProgress = 1.0
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) {
        // Update extracted, ready for installation
    }

    nonisolated func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        logger.info("📄 Appcast loaded successfully")
        logger.info("📊 Appcast details:")
        logger.info("   - Total items: \(appcast.items.count)")

        // Log details of each item
        for (index, item) in appcast.items.enumerated() {
            logger.info("📦 Item \(index + 1):")
            logger.info("   - Version: \(item.displayVersionString)")
            logger.info("   - File URL: \(item.fileURL?.absoluteString ?? "none")")
            logger.info("   - Info URL: \(item.infoURL?.absoluteString ?? "none")")
            logger.info("   - File size: \(item.contentLength) bytes")
            logger.info("   - Minimum OS: \(item.minimumSystemVersion ?? "none")")
            logger.info("   - Release date: \(item.dateString ?? "none")")
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, failedToLoadAppcastWithError error: Error) {
        logger.error("❌ Failed to load appcast")
        logger.error("❌ Error: \(error.localizedDescription)")

        let nsError = error as NSError
        logger.debug("🔍 Error code: \(nsError.code)")
        logger.debug("🔍 Error domain: \(nsError.domain)")
        logger.debug("🔍 Error userInfo: \(nsError.userInfo)")

        Task { @MainActor in
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Failed to load appcast: \(error.localizedDescription)"
            self.lastCheckDate = Date()
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        logger.error("❌ Failed to download update")
        logger.error("❌ Error: \(error.localizedDescription)")
        logger.error("❌ Item version: \(item.displayVersionString)")
        logger.error("❌ Download URL: \(item.fileURL?.absoluteString ?? "none")")

        let nsError = error as NSError
        logger.debug("🔍 Error code: \(nsError.code)")
        logger.debug("🔍 Error domain: \(nsError.domain)")
        logger.debug("🔍 Error userInfo: \(nsError.userInfo)")

        Task { @MainActor in
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Download failed: \(error.localizedDescription)"
            self.lastCheckDate = Date()
        }
    }
}
