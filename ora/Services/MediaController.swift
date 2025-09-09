import Foundation
import SwiftUI
import WebKit

@MainActor
final class MediaController: ObservableObject {
    struct NowPlaying: Equatable {
        var tabID: UUID
        var title: String
        var pageURL: URL
        var favicon: URL?
    }

    @Published var nowPlaying: NowPlaying?
    @Published var isPlaying: Bool = false
    @Published var volume: Double = 1.0
    @Published var canGoNext: Bool = false
    @Published var canGoPrevious: Bool = false
    @Published var isVisible: Bool = false

    weak var currentTab: Tab?

    func activate(for tab: Tab, title: String? = nil) {
        currentTab = tab
        nowPlaying = .init(
            tabID: tab.id,
            title: (title?.isEmpty == false ? title! : tab.title),
            pageURL: tab.url,
            favicon: tab.faviconLocalFile ?? tab.favicon
        )
        isVisible = true
    }

    func receive(event: MediaEventPayload, from tab: Tab) {
        let isCurrent = currentTab?.id == tab.id

        switch event.type {
        case "state":
            let playing = (event.state == "playing")
            if playing {
                if !isCurrent { activate(for: tab, title: event.title) }
                isPlaying = true
                isVisible = true
            } else {
                if isCurrent {
                    isPlaying = false
                } else {
                    return
                }
            }
            if let t = event.title, !t.isEmpty { nowPlaying?.title = t }
            if let vol = event.volume { volume = clamp(vol) }

        case "ready":
            if isCurrent {
                if let t = event.title, !t.isEmpty { nowPlaying?.title = t }
            }

        case "volume":
            if isCurrent, let vol = event.volume { volume = clamp(vol) }

        case "caps":
            if isCurrent {
                canGoNext = event.hasNext ?? canGoNext
                canGoPrevious = event.hasPrevious ?? canGoPrevious
            }

        case "ended":
            if isCurrent { isPlaying = false }

        default:
            break
        }
    }

    func togglePlayPause() {
        eval("window.__oraMedia && window.__oraMedia.toggle && window.__oraMedia.toggle()")
        isPlaying.toggle()
    }

    func nextTrack() {
        eval("window.__oraMedia && window.__oraMedia.next && window.__oraMedia.next()")
    }

    func previousTrack() {
        eval("window.__oraMedia && window.__oraMedia.previous && window.__oraMedia.previous()")
    }

    func setVolume(_ value: Double) {
        let v = clamp(value)
        volume = v
        eval("window.__oraMedia && window.__oraMedia.setVolume && window.__oraMedia.setVolume(\(v))")
    }

    func volumeDelta(_ delta: Double) {
        let newValue = clamp(volume + delta)
        volume = newValue
        eval("window.__oraMedia && window.__oraMedia.deltaVolume && window.__oraMedia.deltaVolume(\(delta))")
    }

    func close() {
        // Pause and hide, keep last known state
        eval("window.__oraMedia && window.__oraMedia.pause && window.__oraMedia.pause()")
        isPlaying = false
        isVisible = false
    }

    private func eval(_ js: String) {
        guard let webView = currentTab?.webView else { return }
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func clamp(_ v: Double) -> Double { max(0, min(1, v)) }
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
