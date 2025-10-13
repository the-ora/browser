import SwiftUI

struct GlobalMediaPlayer: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var media: MediaController
    @EnvironmentObject var tabManager: TabManager

    @State private var isHovered: Bool = false

    // Show up to 4 sessions when hovered, otherwise only the most recent one.
    // Exclude the currently active tab's media session.
    private var sessionsToShow: [MediaController.Session] {
        let activeId = tabManager.activeTab?.id
        let visible = media.visibleSessions.filter { session in
            guard let activeId else { return true }
            return session.tabID != activeId
        }
        if isHovered { return Array(visible.prefix(4)) }
        return Array(visible.prefix(1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show older session first so the most recent appears at the bottom
            ForEach(Array(sessionsToShow.reversed()), id: \.id) { session in
                MediaPlayerCard(
                    session: session,
                    isPrimary: session.tabID == sessionsToShow.first?.tabID
                )
                .environmentObject(media)
                .environmentObject(tabManager)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

private struct MediaPlayerCard: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var media: MediaController
    @EnvironmentObject var tabManager: TabManager

    let session: MediaController.Session
    let isPrimary: Bool

    @State private var showVolume: Bool = false
    @State private var hovered: Bool = false

    private var faviconView: some View {
        if let url = session.favicon {
            return AnyView(
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "play.rectangle.fill")
                        .resizable()
                }
            )
        } else {
            return AnyView(
                Image(systemName: "play.rectangle.fill")
                    .resizable()
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hovered, !session.title.isEmpty {
                HStack(spacing: 8) {
                    Text(session.title)
                        .lineLimit(1)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { media.closeSession(session.tabID) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(PlayerIconButtonStyle(isEnabled: true))
                    .foregroundStyle(Color.white.opacity(0.9))
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
            }

            HStack {
                Button { tabManager.activateTab(id: session.tabID) } label: {
                    faviconView
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(PlayerIconButtonStyle(isEnabled: true))
                .help("Go to playing tab")

                Spacer()

                Button(action: { media.previousTrack(session.tabID) }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(media.canGoPrevious(of: session.tabID) ? 1.0 : 0.35)
                }
                .buttonStyle(PlayerIconButtonStyle(isEnabled: media.canGoPrevious(of: session.tabID)))
                .disabled(!media.canGoPrevious(of: session.tabID))

                Button(action: { media.togglePlayPause(session.tabID) }) {
                    Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(PlayerIconButtonStyle(isEnabled: true))

                Button(action: { media.nextTrack(session.tabID) }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(media.canGoNext(of: session.tabID) ? 1.0 : 0.35)
                }
                .buttonStyle(PlayerIconButtonStyle(isEnabled: media.canGoNext(of: session.tabID)))
                .disabled(!media.canGoNext(of: session.tabID))

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showVolume.toggle() }
                } label: {
                    Image(systemName: media
                        .volume(of: session.tabID) <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill"
                    )
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(PlayerIconButtonStyle(isEnabled: true))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            if showVolume {
                Slider(value: Binding(
                    get: { media.volume(of: session.tabID) },
                    set: { media.setVolume(for: session.tabID, $0) }
                ), in: 0 ... 1)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.black.opacity(0.85))
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .onHover { hovered = $0 }
        .frame(maxWidth: .infinity)
    }
}
