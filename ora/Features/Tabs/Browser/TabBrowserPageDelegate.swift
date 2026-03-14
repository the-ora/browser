import AppKit
import SwiftUI

final class TabBrowserPageDelegate: BrowserPageDelegate {
    weak var tab: Tab?
    weak var mediaController: MediaController?
    weak var passwordCoordinator: PasswordAutofillCoordinator?

    private var progressResetWorkItem: DispatchWorkItem?

    func browserPage(
        _ page: BrowserPage,
        decidePolicyFor navigationAction: BrowserNavigationAction
    ) -> BrowserNavigationActionDisposition {
        guard navigationAction.modifierFlags.contains(.command),
              let url = navigationAction.request.url,
              let tab,
              let tabManager = tab.tabManager,
              let historyManager = tab.historyManager,
              let downloadManager = tab.downloadManager
        else {
            return .allow
        }

        MainActor.assumeIsolated {
            _ = tabManager.openTab(
                url: url,
                historyManager: historyManager,
                downloadManager: downloadManager,
                isPrivate: tab.isPrivate
            )
        }
        return .openInNewTab
    }

    func browserPage(_ page: BrowserPage, didRequestOpenInNewTab url: URL) {
        guard let tab,
              let tabManager = tab.tabManager,
              let historyManager = tab.historyManager
        else {
            return
        }

        MainActor.assumeIsolated {
            _ = tabManager.openTab(
                url: url,
                historyManager: historyManager,
                downloadManager: tab.downloadManager,
                isPrivate: tab.isPrivate
            )
        }
    }

    func browserPage(_ page: BrowserPage, didUpdateNavigation event: BrowserNavigationEvent) {
        guard let tab else { return }

        switch event.phase {
        case .started:
            progressResetWorkItem?.cancel()
            tab.clearNavigationError()
            tab.maintainSnapShots()
            passwordCoordinator?.clearAutofillState()
            tab.isLoading = event.isLoading
            tab.loadingProgress = event.progress
            if let url = event.url {
                tab.url = url
            }

        case .committed:
            tab.isLoading = event.isLoading
            tab.loadingProgress = event.progress
            if let title = event.title, !title.isEmpty {
                tab.title = title
                MainActor.assumeIsolated {
                    mediaController?.syncTitleForTab(tab.id, newTitle: title)
                }
            }

        case .finished:
            tab.isLoading = event.isLoading
            tab.loadingProgress = event.progress
            if let title = event.title, !title.isEmpty {
                tab.title = title
                MainActor.assumeIsolated {
                    mediaController?.syncTitleForTab(tab.id, newTitle: title)
                }
            }
            if let url = event.url {
                tab.url = url
                if tab.favicon == nil {
                    tab.setFavicon()
                }
                tab.updateHistory()
                tab.updateHeaderColor()
            }

            let workItem = DispatchWorkItem { [weak tab] in
                tab?.loadingProgress = 0
            }
            progressResetWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
        }
    }

    func browserPage(_ page: BrowserPage, didFailNavigationWith error: Error, failingURL: URL?) {
        tab?.setNavigationError(error, for: failingURL)
    }

    func browserPage(_ page: BrowserPage, didReceiveScriptMessage message: BrowserScriptMessage) {
        guard let tab else { return }

        switch message.name {
        case "listener":
            handleURLUpdateMessage(message.body, for: tab)
        case "linkHover":
            let hovered = (message.body as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            tab.hoveredLinkURL = hovered.isEmpty ? nil : hovered
        case "mediaEvent":
            handleMediaEventMessage(message.body, for: tab)
        case "passwordManager":
            if let body = message.body as? String {
                passwordCoordinator?.handleMessage(body, pageURL: page.currentURL)
            }
        default:
            break
        }
    }

    func browserPage(
        _ page: BrowserPage,
        requestPermission permission: BrowserPermissionKind,
        origin: URL?,
        decisionHandler: @escaping (BrowserPermissionDecision) -> Void
    ) {
        decisionHandler(.grant)
    }

    func browserPage(
        _ page: BrowserPage,
        runOpenPanelWith options: BrowserOpenPanelOptions,
        completion: @escaping ([URL]?) -> Void
    ) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = options.allowsDirectories
        openPanel.allowsMultipleSelection = options.allowsMultipleSelection
        openPanel.begin { result in
            completion(result == .OK ? openPanel.urls : nil)
        }
    }

    func browserPage(_ page: BrowserPage, runJavaScriptAlert message: String) {
        let alert = NSAlert()
        alert.messageText = "Alert"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func browserPage(_ page: BrowserPage, runJavaScriptConfirm message: String, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Confirm"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completion(alert.runModal() == .alertFirstButtonReturn)
    }

    func browserPage(
        _ page: BrowserPage,
        runJavaScriptPrompt prompt: String,
        defaultText: String?,
        completion: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = "Prompt"
        alert.informativeText = prompt
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = defaultText ?? ""
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            completion(textField.stringValue)
        } else {
            completion(nil)
        }
    }

    func browserPage(_ page: BrowserPage, didStartDownload download: BrowserDownloadTask) {
        MainActor.assumeIsolated {
            tab?.downloadManager?.handleDownload(download)

            guard page.isDownloadNavigation, let tab else { return }

            if page.lastCommittedURL != nil {
                tab.goBack()
            } else if let tabManager = tab.tabManager {
                tabManager.closeTab(tab: tab)
            }
        }
    }

    func takeSnapshotAfterLoad(_ page: BrowserPage) {
        guard !page.isLoading, page.contentView.bounds.width > 0 else { return }

        page.takeSnapshot(
            configuration: BrowserSnapshotConfiguration(
                rect: CGRect(x: 0, y: 0, width: page.contentView.bounds.width, height: 24),
                afterScreenUpdates: false
            )
        ) { [weak self] image, error in
            guard let self, let image, error == nil else { return }
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

            let color = self.extractDominantColor(from: cgImage) ?? .black
            DispatchQueue.main.async {
                self.tab?.updateBackgroundColor(Color(nsColor: color))
                self.tab?.colorUpdated = true
            }
        }
    }

    private func handleURLUpdateMessage(_ body: Any?, for tab: Tab) {
        guard let jsonString = body as? String,
              let jsonData = jsonString.data(using: .utf8),
              let update = try? JSONDecoder().decode(URLUpdate.self, from: jsonData)
        else {
            return
        }

        let oldTitle = tab.title
        tab.title = update.title
        tab.url = URL(string: update.href) ?? tab.url
        tab.setFavicon()
        tab.updateHistory()

        if oldTitle != update.title, !update.title.isEmpty {
            MainActor.assumeIsolated {
                mediaController?.syncTitleForTab(tab.id, newTitle: update.title)
            }
        }
    }

    private func handleMediaEventMessage(_ body: Any?, for tab: Tab) {
        guard let payloadBody = body as? String,
              let data = payloadBody.data(using: .utf8),
              let payload = try? JSONDecoder().decode(MediaEventPayload.self, from: data)
        else {
            return
        }

        MainActor.assumeIsolated {
            mediaController?.receive(event: payload, from: tab)
        }
    }

    private func extractDominantColor(from cgImage: CGImage) -> NSColor? {
        guard cgImage.width > 0, cgImage.height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let data = context.data else { return nil }

        let pixels = data.assumingMemoryBound(to: UInt8.self)
        return NSColor(
            red: CGFloat(pixels[0]) / 255.0,
            green: CGFloat(pixels[1]) / 255.0,
            blue: CGFloat(pixels[2]) / 255.0,
            alpha: CGFloat(pixels[3]) / 255.0
        )
    }
}
