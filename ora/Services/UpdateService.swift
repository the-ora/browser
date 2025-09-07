import os.log
import Sparkle
import SwiftUI

private let logger = Logger(subsystem: "com.orabrowser.ora", category: "UpdateService")

class UpdateService: NSObject, ObservableObject {
    @Published var canCheckForUpdates = false
    @Published var updateProgress: Double = 0.0
    @Published var isCheckingForUpdates = false
    @Published var updateAvailable = false
    @Published var lastCheckResult: String?
    @Published var lastCheckDate: Date?

    private var updater: SPUUpdater?
    private var userDriver: SPUStandardUserDriver?

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
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
    func feedURLString(for updater: SPUUpdater) -> String? {
        let feedURL = "https://the-ora.github.io/browser/appcast.xml"
        logger.info("🔗 Providing feed URL: \(feedURL)")
        logger.info("🔗 Feed URL requested by Sparkle updater")
        return feedURL
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        logger.info("✅ Found valid update!")
        logger.info("📦 Update details:")
        logger.info("   - Version: \(item.displayVersionString)")
        logger.info("   - File URL: \(item.fileURL?.absoluteString ?? "none")")
        logger.info("   - Info URL: \(item.infoURL?.absoluteString ?? "none")")
        logger.info("   - Release notes: \(item.itemDescription ?? "none")")
        logger.info("   - Minimum OS: \(item.minimumSystemVersion ?? "none")")
        logger.info("   - File size: \(item.contentLength) bytes")

        DispatchQueue.main.async {
            self.updateAvailable = true
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Update available: \(item.displayVersionString)"
            self.lastCheckDate = Date()
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        logger.info("ℹ️ No update found")
        logger.error("❌ Error details: \(error.localizedDescription)")
        logger.debug("🔍 Error code: \((error as NSError).code)")
        logger.debug("🔍 Error domain: \((error as NSError).domain)")

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        logger.info("📱 Current app version: \(currentVersion)")

        // Log more details about the error
        let nsError = error as NSError
        logger.debug("🔍 Sparkle error userInfo: \(nsError.userInfo)")

        DispatchQueue.main.async {
            self.updateAvailable = false
            self.isCheckingForUpdates = false
            self.lastCheckResult = "No updates available (current: \(currentVersion))"
            self.lastCheckDate = Date()
        }
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        logger.info("⬇️ Starting download - URL: \(request.url?.absoluteString ?? "unknown")")
        DispatchQueue.main.async {
            self.updateProgress = 0.0
        }
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        logger.info("✅ Update downloaded successfully")
        DispatchQueue.main.async {
            self.updateProgress = 1.0
        }
    }

    func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) {
        // Update extracted, ready for installation
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
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

    func updater(_ updater: SPUUpdater, failedToLoadAppcastWithError error: Error) {
        logger.error("❌ Failed to load appcast")
        logger.error("❌ Error: \(error.localizedDescription)")

        let nsError = error as NSError
        logger.debug("🔍 Error code: \(nsError.code)")
        logger.debug("🔍 Error domain: \(nsError.domain)")
        logger.debug("🔍 Error userInfo: \(nsError.userInfo)")

        DispatchQueue.main.async {
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Failed to load appcast: \(error.localizedDescription)"
            self.lastCheckDate = Date()
        }
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        logger.error("❌ Failed to download update")
        logger.error("❌ Error: \(error.localizedDescription)")
        logger.error("❌ Item version: \(item.displayVersionString)")
        logger.error("❌ Download URL: \(item.fileURL?.absoluteString ?? "none")")

        let nsError = error as NSError
        logger.debug("🔍 Error code: \(nsError.code)")
        logger.debug("🔍 Error domain: \(nsError.domain)")
        logger.debug("🔍 Error userInfo: \(nsError.userInfo)")

        DispatchQueue.main.async {
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Download failed: \(error.localizedDescription)"
            self.lastCheckDate = Date()
        }
    }
}
