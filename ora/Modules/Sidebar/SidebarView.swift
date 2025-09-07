import AppKit
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var historyManger: HistoryManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var appState: AppState
    @Query var containers: [TabContainer]
    @Query(filter: nil, sort: [.init(\History.lastAccessedAt, order: .reverse)]) var histories:
        [History]
    private let columns = Array(repeating: GridItem(spacing: 10), count: 3)
    let isFullscreen: Bool
    @State private var showFullURL: Bool = false
    @State private var editingURLString: String = ""
    @FocusState private var isEditing: Bool

    private var selectedContainerIndex: Binding<Int> {
        Binding(
            get: {
                guard let activeContainer = tabManager.activeContainer else { return 0 }
                return containers.firstIndex(where: { $0.id == activeContainer.id }) ?? 0
            },
            set: { newIndex in
                guard newIndex >= 0, newIndex < containers.count else { return }
                tabManager.activateContainer(containers[newIndex])
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // URL display when toolbar is hidden
            if appState.isToolbarHidden, let tab = tabManager.activeTab {
                HStack(spacing: 8) {
                    // Security indicator
                    ZStack {
                        if tab.isLoading {
                            ProgressView()
                                .tint(theme.foreground.opacity(0.7))
                                .scaleEffect(0.5)
                        } else {
                            Image(systemName: tab.url.scheme == "https" ? "lock.fill" : "globe")
                                .font(.system(size: 12))
                                .foregroundColor(tab.url.scheme == "https" ? .green : theme.foreground.opacity(0.7))
                        }
                    }
                    .frame(width: 16, height: 16)

                    // URL input field
                    TextField("", text: $editingURLString)
                        .font(.system(size: 14))
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(theme.foreground)
                        .focused($isEditing)
                        .onSubmit {
                            tab.loadURL(editingURLString)
                            isEditing = false
                        }
                        .onTapGesture {
                            editingURLString = tab.url.absoluteString
                            isEditing = true
                        }
                        .onKeyPress(.escape) {
                            isEditing = false
                            return .handled
                        }
                        .overlay(
                            Group {
                                if !isEditing, editingURLString.isEmpty {
                                    HStack {
                                        Text(getDisplayURL(tab))
                                            .font(.system(size: 14))
                                            .foregroundColor(theme.foreground)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                    }
                                }
                            }
                        )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.mutedBackground)
                )
                .contextMenu {
                    if showFullURL {
                        Button(action: {
                            showFullURL = false
                        }) {
                            Label("Hide Full URL", systemImage: "eye.slash")
                        }
                    } else {
                        Button(action: {
                            showFullURL = true
                        }) {
                            Label("Show Full URL", systemImage: "eye")
                        }
                    }
                }
                .onAppear {
                    editingURLString = getDisplayURL(tab)
                    DispatchQueue.main.async {
                        isEditing = false
                    }
                }
                .onChange(of: tab.url) { _, _ in
                    if !isEditing {
                        editingURLString = getDisplayURL(tab)
                    }
                }
                .onChange(of: showFullURL) { _, _ in
                    if !isEditing, let tab = tabManager.activeTab {
                        editingURLString = getDisplayURL(tab)
                    }
                }
                .onChange(of: tabManager.activeTab?.id) { _, _ in
                    if !isEditing, let tab = tabManager.activeTab {
                        editingURLString = getDisplayURL(tab)
                    }
                }
            }

            NSPageView(
                selection: selectedContainerIndex,
                pageObjects: containers,
                idKeyPath: \.name
            ) { container in
                ContainerView(
                    container: container,
                    selectedContainer: container.name,
                    containers: containers
                )
                .padding(.horizontal, 10)
                .environmentObject(tabManager)
                .environmentObject(historyManger)
                .environmentObject(downloadManager)
                .environmentObject(appState)
            }

            HStack {
                DownloadsWidget()
                Spacer()
                ContainerSwitcher(onContainerSelected: onContainerSelected)
                Spacer()
                NewContainerButton()
            }
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(
            EdgeInsets(
                top: isFullscreen ? 10 : 36,
                leading: 0,
                bottom: 10,
                trailing: 0
            )
        )
    }

    private func onContainerSelected(container: TabContainer) {
        withAnimation(.easeOut(duration: 0.1)) {
            tabManager.activateContainer(container)
        }
    }

    private func getDisplayURL(_ tab: Tab) -> String {
        if showFullURL {
            return tab.url.absoluteString
        } else {
            return tab.url.host ?? tab.url.absoluteString
        }
    }
}
