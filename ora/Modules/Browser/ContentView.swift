import SwiftUI
import WebKit
import AVKit

struct ContentView: View {
    @StateObject private var viewModel = VideoViewModel()
    @State private var manualURL: String = ""

    var body: some View {
        VStack {
            BrowserWebView(webView: viewModel.webView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            TextField("Enter Video URL", text: $manualURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button("Enter PiP") {
                if let url = URL(string: manualURL.isEmpty ? "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4" : manualURL) {
                    viewModel.videoURL = url
                    viewModel.showPiPWindow()
                } else {
                    viewModel.enterPiP()
                }
            }
            .padding()
        }
    }
}

class VideoViewModel: ObservableObject {
    @Published var videoURL: URL?
    let webView: WKWebView

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.isElementFullscreenEnabled = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15"
        if let url = URL(string: "https://www.youtube.com/watch?v=OTCK_At6qwQ") {
            webView.load(URLRequest(url: url))
        }
    }

    func enterPiP() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let js = """
            (function() {
                let video = document.querySelector('video');
                if (video) {
                    let src = video.src || video.getAttribute('data-video-url') || video.getAttribute('src');
                    if (src && src.startsWith('http')) {
                        return src;
                    }
                    let player = document.querySelector('ytd-player');
                    if (player) {
                        let videoId = player.getAttribute('video-id');
                        if (videoId) {
                            return 'https://www.youtube.com/watch?v=' + videoId;
                        }
                    }
                }
                return null;
            })();
            """
            self.webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("JS Error: \(error)")
                    return
                }
                if let urlString = result as? String, let url = URL(string: urlString) {
                    self.videoURL = url
                    self.showPiPWindow()
                } else {
                    print("Failed to extract video URL: \(String(describing: result))")
                }
            }
        }
    }

    func showPiPWindow() {
        guard let videoURL = videoURL else { return }
        let player = AVPlayer(url: videoURL)
        let pipWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        pipWindow.level = .floating
        pipWindow.isMovableByWindowBackground = true
        pipWindow.contentView = NSHostingView(rootView: PiPView(player: player))
        pipWindow.center()
        pipWindow.makeKeyAndOrderFront(nil)
        player.play()
    }
}

struct BrowserWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct PiPView: View {
    let player: AVPlayer

    var body: some View {
        VideoPlayer(player: player)
            .frame(width: 320, height: 180)
            .background(Color.black)
            .cornerRadius(10)
            .shadow(radius: 5)
            .onAppear {
                player.play()
            }
    }
}
