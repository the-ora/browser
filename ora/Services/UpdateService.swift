import Sparkle
import SwiftUI

@Observable
class UpdateService: NSObject {
    var canCheckForUpdates = false
    var updateProgress: Double = 0.0
    var isCheckingForUpdates = false
    var updateAvailable = false
    var lastCheckResult: String?
    var lastCheckDate: Date?

    private var updater: SPUUpdater?
    private var userDriver: SPUStandardUserDriver?

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
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
    func feedURLString(for updater: SPUUpdater) -> String? {
        let feedURL = "https://the-ora.github.io/browser/appcast.xml"
        print("🔗 UpdateService: Providing feed URL: \(feedURL)")
        print("🔗 UpdateService: Feed URL requested by Sparkle updater")
        return feedURL
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        print("✅ UpdateService: Found valid update!")
        print("📦 UpdateService: Update details:")
        print("   - Version: \(item.displayVersionString ?? item.versionString)")
        print("   - File URL: \(item.fileURL?.absoluteString ?? "none")")
        print("   - Info URL: \(item.infoURL?.absoluteString ?? "none")")
        print("   - Release notes: \(item.itemDescription ?? "none")")
        print("   - Minimum OS: \(item.minimumSystemVersion ?? "none")")
        print("   - File size: \(item.contentLength) bytes")

        DispatchQueue.main.async {
            self.updateAvailable = true
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Update available: \(item.displayVersionString ?? item.versionString)"
            self.lastCheckDate = Date()
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        print("ℹ️ UpdateService: No update found")
        print("❌ UpdateService: Error details: \(error.localizedDescription)")
        print("🔍 UpdateService: Error code: \((error as NSError).code)")
        print("🔍 UpdateService: Error domain: \((error as NSError).domain)")

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        print("📱 UpdateService: Current app version: \(currentVersion)")

        // Log more details about the error
        let nsError = error as NSError
        print("🔍 UpdateService: Sparkle error userInfo: \(nsError.userInfo)")

        DispatchQueue.main.async {
            self.updateAvailable = false
            self.isCheckingForUpdates = false
            self.lastCheckResult = "No updates available (current: \(currentVersion))"
            self.lastCheckDate = Date()
        }
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        print("⬇️ UpdateService: Starting download - URL: \(request.url?.absoluteString ?? "unknown")")
        DispatchQueue.main.async {
            self.updateProgress = 0.0
        }
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        print("✅ UpdateService: Update downloaded successfully")
        DispatchQueue.main.async {
            self.updateProgress = 1.0
        }
    }

    func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) {
        // Update extracted, ready for installation
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
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

    func updater(_ updater: SPUUpdater, failedToLoadAppcastWithError error: Error) {
        print("❌ UpdateService: Failed to load appcast")
        print("❌ UpdateService: Error: \(error.localizedDescription)")

        let nsError = error as NSError
        print("🔍 UpdateService: Error code: \(nsError.code)")
        print("🔍 UpdateService: Error domain: \(nsError.domain)")
        print("🔍 UpdateService: Error userInfo: \(nsError.userInfo)")

        DispatchQueue.main.async {
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Failed to load appcast: \(error.localizedDescription)"
            self.lastCheckDate = Date()
        }
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        print("❌ UpdateService: Failed to download update")
        print("❌ UpdateService: Error: \(error.localizedDescription)")
        print("❌ UpdateService: Item version: \(item.displayVersionString ?? item.versionString)")
        print("❌ UpdateService: Download URL: \(item.fileURL?.absoluteString ?? "none")")

        let nsError = error as NSError
        print("🔍 UpdateService: Error code: \(nsError.code)")
        print("🔍 UpdateService: Error domain: \(nsError.domain)")
        print("🔍 UpdateService: Error userInfo: \(nsError.userInfo)")

        DispatchQueue.main.async {
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Download failed: \(error.localizedDescription)"
            self.lastCheckDate = Date()
        }
    }
}
