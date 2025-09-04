import SwiftUI
import Sparkle

class UpdateService: NSObject, ObservableObject {
    @Published var canCheckForUpdates = false
    @Published var updateProgress: Double = 0.0
    @Published var isCheckingForUpdates = false
    @Published var updateAvailable = false

    private var updater: SPUUpdater?
    private var userDriver: SPUStandardUserDriver?

    override init() {
        super.init()
        setupUpdater()
    }

    private func setupUpdater() {
        let hostBundle = Bundle.main
        let applicationBundle = hostBundle
        let userDriver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)
        let updater = SPUUpdater(hostBundle: hostBundle, applicationBundle: applicationBundle, userDriver: userDriver, delegate: self)

        self.updater = updater
        self.userDriver = userDriver
        self.canCheckForUpdates = updater.canCheckForUpdates
    }

    func checkForUpdates() {
        guard let updater = updater, canCheckForUpdates else { return }

        isCheckingForUpdates = true
        updater.checkForUpdates()
    }

    func checkForUpdatesInBackground() {
        guard let updater = updater else { return }
        updater.checkForUpdatesInBackground()
    }
}

extension UpdateService: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        DispatchQueue.main.async {
            self.updateAvailable = true
            self.isCheckingForUpdates = false
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        DispatchQueue.main.async {
            self.updateAvailable = false
            self.isCheckingForUpdates = false
        }
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        DispatchQueue.main.async {
            self.updateProgress = 0.0
        }
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        DispatchQueue.main.async {
            self.updateProgress = 1.0
        }
    }

    func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) {
        // Update extracted, ready for installation
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        // Appcast loaded successfully
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        DispatchQueue.main.async {
            self.isCheckingForUpdates = false
        }
    }
}