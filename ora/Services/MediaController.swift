import Foundation
import SwiftUI
import WebKit

@MainActor
final class MediaController: ObservableObject {
    struct Session: Identifiable, Equatable {
        var id: UUID { tabID }
        var tabID: UUID
        var title: String
        var pageURL: URL
        var favicon: URL?
        var isPlaying: Bool
        var volume: Double
        var canGoNext: Bool
        var canGoPrevious: Bool
        var lastActive: Date
    }

    // Published list of sessions ordered by recency (most recent first)
    @Published private(set) var sessions: [Session] = []
    @Published var isVisible: Bool = false

    // Weak references to tabs by id so we can run JS in the right webview
    private final class WeakTab { weak var value: Tab?
        init(_ value: Tab?) { self.value = value }
    }

    private var tabRefs: [UUID: WeakTab] = [:]
    private var titleSyncTimer: Timer?

    init() {
        startPeriodicTitleSync()
    }

    deinit {
        titleSyncTimer?.invalidate()
    }

    // MARK: - Public accessors

    var primary: Session? { visibleSessions.first }
    var visibleSessions: [Session] { sessions }

    // MARK: - Receive events from JS bridge

    func receive(event: MediaEventPayload, from tab: Tab) {
        tabRefs[tab.id] = WeakTab(tab)
        let id = tab.id

        func ensureSession() -> Int {
            if let idx = sessions.firstIndex(where: { $0.tabID == id }) { return idx }
            let session = Session(
                tabID: id,
                title: tab.title,
                pageURL: tab.url,
                favicon: tab.faviconLocalFile ?? tab.favicon,
                isPlaying: false,
                volume: 1.0,
                canGoNext: false,
                canGoPrevious: false,
                lastActive: Date()
            )
            sessions.insert(session, at: 0)
            return 0
        }

        switch event.type {
        case "state":
            let idx = ensureSession()
            let playing = (event.state == "playing")
            sessions[idx].isPlaying = playing
            // Update tab's isPlayingMedia property
            tabRefs[tab.id]?.value?.isPlayingMedia = playing
            if let newTitle = event.title, !newTitle.isEmpty { sessions[idx].title = newTitle }
            if let vol = event.volume { sessions[idx].volume = clamp(vol) }
            // Update recency when it starts playing
            if playing { sessions[idx].lastActive = Date()
                moveToFront(index: idx)
            }

        case "ready":
            if let idx = sessions.firstIndex(where: { $0.tabID == id }) {
                if let newTitle = event.title, !newTitle.isEmpty { sessions[idx].title = newTitle }
            }

        case "volume":
            if let idx = sessions.firstIndex(where: { $0.tabID == id }), let vol = event.volume {
                sessions[idx].volume = clamp(vol)
            }

        case "caps":
            if let idx = sessions.firstIndex(where: { $0.tabID == id }) {
                sessions[idx].canGoNext = event.hasNext ?? sessions[idx].canGoNext
                sessions[idx].canGoPrevious = event.hasPrevious ?? sessions[idx].canGoPrevious
            }

        case "ended":
            if let idx = sessions.firstIndex(where: { $0.tabID == id }) {
                sessions[idx].isPlaying = false
                // Update tab's isPlayingMedia property
                tabRefs[tab.id]?.value?.isPlayingMedia = false
            }

        case "titleChange":
            if let idx = sessions.firstIndex(where: { $0.tabID == id }),
               let newTitle = event.title, !newTitle.isEmpty
            {
                sessions[idx].title = newTitle
            }

        default:
            break
        }

        isVisible = !sessions.isEmpty
    }

    // MARK: - Controls (per session, default to primary)

    func togglePlayPause(_ tabID: UUID? = nil) {
        guard let id = tabID ?? primary?.tabID else { return }
        eval(id, "window.__oraMedia && window.__oraMedia.toggle && window.__oraMedia.toggle()")
        if let idx = sessions.firstIndex(where: { $0.tabID == id }) {
            sessions[idx].isPlaying.toggle()
        }
    }

    func nextTrack(_ tabID: UUID? = nil) {
        guard let id = tabID ?? primary?.tabID else { return }
        eval(id, "window.__oraMedia && window.__oraMedia.next && window.__oraMedia.next()")
        scheduleTitleSync(for: id)
    }

    func previousTrack(_ tabID: UUID? = nil) {
        guard let id = tabID ?? primary?.tabID else { return }
        eval(id, "window.__oraMedia && window.__oraMedia.previous && window.__oraMedia.previous()")
        scheduleTitleSync(for: id)
    }

    func setVolume(for tabID: UUID? = nil, _ value: Double) {
        guard let id = tabID ?? primary?.tabID else { return }
        let clampedVolume = clamp(value)
        if let idx = sessions.firstIndex(where: { $0.tabID == id }) { sessions[idx].volume = clampedVolume }
        eval(id, "window.__oraMedia && window.__oraMedia.setVolume && window.__oraMedia.setVolume(\(clampedVolume))")
    }

    func volumeDelta(for tabID: UUID? = nil, _ delta: Double) {
        guard let id = tabID ?? primary?.tabID else { return }
        if let idx = sessions.firstIndex(where: { $0.tabID == id }) {
            sessions[idx].volume = clamp(sessions[idx].volume + delta)
        }
        eval(id, "window.__oraMedia && window.__oraMedia.deltaVolume && window.__oraMedia.deltaVolume(\(delta))")
    }

    func closeSession(_ tabID: UUID? = nil) {
        guard let id = tabID ?? primary?.tabID else { return }
        eval(id, "window.__oraMedia && window.__oraMedia.pause && window.__oraMedia.pause()")
        if let idx = sessions.firstIndex(where: { $0.tabID == id }) {
            sessions.remove(at: idx)
        }
        // Update tab's isPlayingMedia property
        tabRefs[id]?.value?.isPlayingMedia = false
        tabRefs[id] = nil
        isVisible = !visibleSessions.isEmpty
    }

    // Helpers
    func volume(of tabID: UUID) -> Double { sessions.first(where: { $0.tabID == tabID })?.volume ?? 1.0 }
    func canGoNext(of tabID: UUID) -> Bool { sessions.first(where: { $0.tabID == tabID })?.canGoNext ?? false }
    func canGoPrevious(of tabID: UUID) -> Bool { sessions.first(where: { $0.tabID == tabID })?.canGoPrevious ?? false }

    // MARK: - Private

    private func moveToFront(index: Int) {
        guard index < sessions.count else { return }
        let session = sessions.remove(at: index)
        sessions.insert(session, at: 0)
    }

    private func eval(_ tabID: UUID, _ javaScript: String) {
        guard let webView = tabRefs[tabID]?.value?.webView else { return }
        webView.evaluateJavaScript(javaScript, completionHandler: nil)
    }

    private func clamp(_ value: Double) -> Double { max(0, min(1, value)) }

    private func startPeriodicTitleSync() {
        titleSyncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncTitlesForPlayingSessions()
            }
        }
    }

    private func syncTitlesForPlayingSessions() {
        let playingSessions = sessions.filter(\.isPlaying)
        for session in playingSessions {
            fetchDocumentTitle(for: session.tabID) { [weak self] newTitle in
                guard let self, let title = newTitle, !title.isEmpty,
                      let idx = self.sessions.firstIndex(where: { $0.tabID == session.tabID }),
                      title != self.sessions[idx].title
                else { return }

                self.sessions[idx].title = title
            }
        }
    }

    // MARK: - Title sync helpers

    func syncTitleForTab(_ tabID: UUID, newTitle: String) {
        if let idx = sessions.firstIndex(where: { $0.tabID == tabID }) {
            sessions[idx].title = newTitle
        }
    }

    private func scheduleTitleSync(for tabID: UUID, attempts: Int = 6, delay: TimeInterval = 0.25) {
        guard attempts > 0 else { return }
        let currentTitle = sessions.first(where: { $0.tabID == tabID })?.title
        fetchDocumentTitle(for: tabID) { [weak self] newTitle in
            guard let self else { return }
            if let title = newTitle, !title.isEmpty, title != currentTitle,
               let idx = self.sessions.firstIndex(where: { $0.tabID == tabID })
            {
                self.sessions[idx].title = title
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.scheduleTitleSync(for: tabID, attempts: attempts - 1, delay: delay)
                }
            }
        }
    }

    private func fetchDocumentTitle(for tabID: UUID, completion: @escaping (String?) -> Void) {
        guard let webView = tabRefs[tabID]?.value?.webView else { completion(nil)
            return
        }
        let js = "(function(){ try { return (window.__oraMedia && window.__oraMedia.title && window.__oraMedia.title()) || document.title || ''; } catch(e) { return document.title || ''; } })()"
        webView.evaluateJavaScript(js) { result, _ in
            completion(result as? String)
        }
    }
}

// Payload from injected JS
struct MediaEventPayload: Codable {
    let type: String
    let state: String?
    let volume: Double?
    let title: String?
    let hasNext: Bool?
    let hasPrevious: Bool?
}
