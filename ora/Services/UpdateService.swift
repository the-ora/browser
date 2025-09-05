import Sparkle
import SwiftUI

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
        print("🔧 UpdateService: Setting up updater")
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

        // Start the updater
        do {
            try updater.start()
            print("✅ UpdateService: Updater started successfully")
        } catch {
            print("❌ UpdateService: Failed to start updater - Error: \(error.localizedDescription)")
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
        updater.checkForUpdates()
    }

    func checkForUpdatesInBackground() {
        guard let updater else { return }
        updater.checkForUpdatesInBackground()
    }
}

extension UpdateService: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        print("🔗 UpdateService: Providing feed URL: https://the-ora.github.io/browser/appcast.xml")
        return "https://the-ora.github.io/browser/appcast.xml"
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        print("✅ UpdateService: Found valid update - Version: \(item.displayVersionString ?? item.versionString)")
        DispatchQueue.main.async {
            self.updateAvailable = true
            self.isCheckingForUpdates = false
            self.lastCheckResult = "Update available: \(item.displayVersionString ?? item.versionString)"
            self.lastCheckDate = Date()
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        print("ℹ️ UpdateService: No update found - Error: \(error.localizedDescription)")
        print(
            "ℹ️ UpdateService: Current app version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")"
        )
        DispatchQueue.main.async {
            self.updateAvailable = false
            self.isCheckingForUpdates = false
            self.lastCheckResult = "No updates available (current: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"))"
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
        print("📄 UpdateService: Appcast loaded successfully - Items: \(appcast.items.count)")
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        print("❌ UpdateService: Failed to download update - Error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isCheckingForUpdates = false
        }
    }
}
